{ pkgs
, stdenv
, lib
, hostPlatform

, linuxConfig
, linuxManualConfig
, runCommandNoCC

, lz4
, lzop

, fetchFromGitHub
/** Embed the given initramfs (cpio or files list) in the build */
, initramfs ? null
, ...
}:

{ name ? "linux-${version}"
, version ? src.version
, src
, structuredConfig
, kernelPatches ? []
, defconfig
}:

# Note:
# buildLinux cannot be used as `<pkgs/os-specific/linux/kernel/generic.nix>`
# assumed way too much about the kernel that is going to be built :<

let
  evaluatedStructuredConfig = import ./eval-config.nix {
    inherit pkgs structuredConfig;
  };

  defconfigFile = linuxConfig {
    inherit src;
    inherit version;
    makeTarget = defconfig;
  };

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
  inherit kernelPatches;
  inherit configfile;
}
).overrideAttrs({ postPatch ? "", postInstall ? "" , nativeBuildInputs ? [], ... }: {

  postConfigure = ''
    (cd $buildRoot
    ${evaluatedStructuredConfig.config.validatorSnippet}
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
  '';

  postInstall = postInstall + ''
    cp .config $out/config
  '';

  # FIXME: add lz4 / lzop only if compression requires it
  nativeBuildInputs = nativeBuildInputs ++ [
    lz4
    lzop
  ];
})
