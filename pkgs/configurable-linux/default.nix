{ pkgs
, stdenv
, lib

, linuxConfig
, linuxManualConfig
, runCommandNoCC

, lz4
, lzop
, ...
}:

{ name ? "linux-${version}"
, version ? src.version
, src
, patches
, structuredConfig
, kernelPatches ? []
, defconfig
, logoPPM ? null
}:

# Note:
# buildLinux cannot be used as `<pkgs/os-specific/linux/kernel/generic.nix>`
# assumed way too much about the kernel that is going to be built :<

let
  evaluatedStructuredConfig = import ./eval-config.nix {
    inherit (pkgs) path;
    inherit lib structuredConfig version;
  };

  defconfigFile =
    if (lib.isDerivation defconfig) || (builtins.isPath defconfig)
    then defconfig
    else linuxConfig {
      inherit src;
      inherit version;
      makeTarget = defconfig;
    }
  ;

  # TODO:
  #  - apply structured config
  #    -> remove duplicate entries keeping last
  #  - re-"normalize" config against kernel config
  configfile = runCommandNoCC "linux-merged-config" {} ''
    cat >> $out <<EOF
    #
    # From ${defconfig}
    #
    EOF
    cat ${defconfigFile} >> $out
    cat >> $out <<EOF

    #
    # From structed attributes
    #
    ${evaluatedStructuredConfig.config.configfile}
    EOF
  '';

  allPatches = kernelPatches ++ (builtins.map (patch: { inherit patch; }) patches);

  validatorSnippet = pkgs.writeShellScript "${name}-validator-snippet" ''
    ${evaluatedStructuredConfig.config.validatorSnippet}
  '';
in

(
linuxManualConfig rec {
  # Required args
  inherit stdenv lib;
  inherit src;
  inherit version;
  extraMakeFlags = [
    "KBUILD_BUILD_VERSION=1-celun"
  ];
  kernelPatches = allPatches;
  inherit configfile;
}
).overrideAttrs({ postPatch ? "", postInstall ? "" , nativeBuildInputs ? [], ... }: {

  postConfigure = ''
    (cd $buildRoot
    ${validatorSnippet}
    )
  '';

  postPatch = postPatch +
  /* Logo patch from Mobile NixOS */
  ''
    # Makes the "logo" option show only one logo and not dependent on cores.
    # This should be "safer" than a patch on a greater range of kernel versions.
    # Also defaults to centering when possible.

    echo ":: Patching for centered linux logo"
    if [ -e drivers/video/fbdev/core/fbmem.c ]; then
      # Force showing only one logo
      sed -i -e 's/num_online_cpus()/1/g' \
        drivers/video/fbdev/core/fbmem.c

      # Force centering logo
      sed -i -e '/^bool fb_center_logo/ s/;/ = true;/' \
        drivers/video/fbdev/core/fbmem.c
    fi

    if [ -e drivers/video/fbmem.c ]; then
      # Force showing only one logo
      sed -i -e 's/num_online_cpus()/1/g' \
        drivers/video/fbmem.c
    fi

    ${lib.optionalString (logoPPM != null) ''
      echo ":: Replacing the logo"
      cp ${logoPPM} drivers/video/logo/logo_linux_clut224.ppm
    ''}
  '';

  postInstall = postInstall + ''
    cp .config $out/config

    (
      echo 'Built-ins:'
      echo '   text    data     bss     dec     hex filename'
      echo '================================================'
      echo 
      size "$buildRoot"/*/built-in.o "$buildRoot"/*/built-in.a | sort -n -r -k 4
    ) > $out/built-ins.txt
  '';

  # FIXME: add lz4 / lzop only if compression requires it
  nativeBuildInputs = nativeBuildInputs ++ [
    lz4
    lzop
  ];
})
