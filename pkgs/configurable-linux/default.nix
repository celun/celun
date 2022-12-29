{ pkgs
, stdenv
, lib

, linuxConfig
, linuxManualConfig
, runCommandNoCC

, zlib
, lz4
, lzop
, ...
}:

{ name ? "linux-${version}"
, version ? src.version
, src
, patches
, postInstall ? ""
, structuredConfig
, kernelPatches ? []
, defconfig
, logoPPM ? null
, isModular
}:

# Note:
# buildLinux cannot be used as `<pkgs/os-specific/linux/kernel/generic.nix>`
# assumed way too much about the kernel that is going to be built :<

let
  postInstall' = postInstall;
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

  allPatches = (map (p: p.patch) kernelPatches) ++ patches;

  validatorSnippet = pkgs.writeShellScript "${name}-validator-snippet" ''
    ${evaluatedStructuredConfig.config.validatorSnippet}
  '';

  target =
    if stdenv.hostPlatform.linux-kernel.target == "uImage"
    then "zImage" # We're not using uImage.
    else stdenv.hostPlatform.linux-kernel.target
  ;
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
  kernelPatches = [];
  # TODO: normalize the config so that config works with allowImportFromDerivation
  inherit configfile;
  config = {
    # FIXME: use the normalized config so CONFIG_MODULES is used from actual config.
    CONFIG_MODULES = if isModular then "y" else "n";
  };
}
).overrideAttrs({ postPatch ? "", postInstall ? "" , nativeBuildInputs ? [], ... }: {
  inherit target;

  postConfigure = ''
    (cd $buildRoot
    ${validatorSnippet}
    )
  '';

  # Ensure we don't inherit stray patches from the NixOS build harness...
  # Because of the way we handle the kernel, they may be duplicated.
  patches = allPatches;

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

  installTargets = [ "install" ]
   ++ lib.optional (target == "zImage") "zinstall" ;
  extraMakeFlags = [ target ];

  postInstall = postInstall + ''
    (
      cd $buildRoot
      cp .config $out/config
    )

    (
      cd $buildRoot
      echo 'Built-ins:'
      echo '   text    data     bss     dec     hex filename'
      echo '================================================'
      echo 
      size "$buildRoot"/*/built-in.o "$buildRoot"/*/built-in.a | sort -n -r -k 4
    ) > $out/built-ins.txt
    ${lib.optionalString (target == "vmlinuz" || target == "vmlinux") ''
      (
      cd $out
      # See arch/mips/Makefile, installed file includes version number.
      # Attempting to move both since installing the compressed version
      # installs the uncompressed version.
      if [ -e vmlinux-* ]; then
        mv -v vmlinux-* vmlinux
      fi
      if [ -e vmlinuz-* ]; then
        mv -v vmlinuz-* vmlinuz
      fi
      )
    ''}
    ${postInstall'}
  '';

  # FIXME: add lz4 / lzop only if compression requires it
  nativeBuildInputs = nativeBuildInputs ++ [
    zlib
    lz4
    lzop
  ];
})
