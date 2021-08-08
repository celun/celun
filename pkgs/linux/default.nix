{ pkgs
, stdenv
, lib
, hostPlatform

, base
, linuxConfig
, linuxManualConfig
, runCommandNoCC

, fetchFromGitHub
/** Embed the given initramfs (cpio or files list) in the build */
, initramfs ? null
, ...
}:

# Note:
# buildLinux cannot be used as `<pkgs/os-specific/linux/kernel/generic.nix>`
# assumed way too much about the kernel that is going to be built :<

let
  inherit (base) src;

  target =
    #"qemu-virt" # ARM machine type
    "qemu-pc" # x86_64 machine type
  ;

  features = {
    printk = true;
    serial = true;
    vt = false;
    graphics = true;
    initramfs = (initramfs != null) || true;
    logo = false;

    # You probably want to enable this on x86 and x86_64
    acpi = target == "qemu-pc";
  };

  structuredConfig = import ./eval-config.nix {
    inherit pkgs;
    structuredConfig = with lib.kernel;
      lib.mkMerge [
        (lib.mkIf features.printk {
          # Without printk, kernel is mostly silent
          PRINTK = yes;
          # Not required, but helpful
          PRINTK_TIME = yes;

          # Outputs printk messages to TTY (when TTY is built in)
          TTY_PRINTK = option yes;
        })

        (lib.mkIf (features.printk && (stdenv.isx86_32 || stdenv.isx86_64)) {
          # This is not recommended (oddly enough enabled in NixOS)
          # https://cateee.net/lkddb/web-lkddb/EARLY_PRINTK.html
          EARLY_PRINTK = yes;
        })

        # Apparently arm64 doesn't have EARLY_PRINTK?
        (lib.mkIf (features.printk && (stdenv.isAarch32)) {
          EARLY_PRINTK = yes;
          # Required for EARLY_PRINTK
          DEBUG_LL = yes;
        })

        (lib.mkIf features.vt {
          TTY = yes;
          VT = yes;
        })

        (lib.mkIf features.graphics {
          FB = yes;
        })

        (lib.mkIf features.serial {
          VT = lib.mkDefault no;
          # Serial output requires TTY
          TTY = yes;

          # x86
          SERIAL_8250 = yes;
          SERIAL_8250_CONSOLE = yes;
        })

        (lib.mkIf (features.serial && (stdenv.isAarch32 || stdenv.isAarch64)) {
          # ARM
          SERIAL_AMBA_PL011 = yes;
          SERIAL_AMBA_PL011_CONSOLE = yes;
        })

        (lib.mkIf features.initramfs {
          # Support for initramfs
          BLK_DEV_INITRD = yes;
        })

        (lib.mkIf (initramfs != null) {
          INITRAMFS_SOURCE = freeform initramfs;
        })

        (lib.mkIf features.logo {
          FB = yes;
          LOGO = yes;

          # Seemingly required for LOGO
          TTY = yes;
          VT = yes;
          # Also seemingly required
          # (Additionally an fbdev will be required in some form)
          FRAMEBUFFER_CONSOLE = yes;
        })

        {
          # Required for proper modern /dev/
          DEVTMPFS = yes;
          DEVTMPFS_MOUNT = yes;
        }

        {
          BINFMT_ELF = yes;
          BINFMT_SCRIPT = yes;
        }

        # Make optional?
        {

          PROC_FS = yes;
          PROC_SYSCTL = yes;
          PROC_PAGE_MONITOR = yes;
          PROC_CHILDREN = yes;
          KERNFS = yes;
          SYSFS = yes;
          MEMFD_CREATE = yes;
          CONFIGFS_FS = yes;
        }

        # TMPFS
        {
          SHMEM = yes;
          TMPFS = yes;
          TMPFS_POSIX_ACL = yes;
          TMPFS_XATTR = yes;
        }

        (lib.mkIf features.acpi {
          # ACPI and PCI Required for power off (Verified on QEMU)
          ACPI = yes;
          PCI = yes;
        })

        # TODO: add compression dependent on initramfs compression scheme
        {
          RD_GZIP = no;
          RD_BZIP2 = no;
          RD_LZMA = no;
          RD_XZ = no;
          RD_LZO = no;
          RD_LZ4 = no;
          RD_ZSTD = no;

          KERNEL_GZIP = no;
          KERNEL_BZIP2 = no;
          KERNEL_LZMA = no;
          KERNEL_XZ = no;
          KERNEL_LZO = no;
          KERNEL_LZ4 = no;
          KERNEL_ZSTD = no;
        }

        #
        # Machine-specific configs
        # ------------------------
        #

        (lib.mkIf (target == "qemu-pc") (lib.mkMerge [
          (lib.mkIf (features.logo || features.vt || features.graphics) {
            DRM = yes;
            DRM_FBDEV_EMULATION = yes;
            DRM_BOCHS = yes;
          })
        ]))

        # For qemu virt
        (lib.mkIf (target == "qemu-virt") (lib.mkMerge [
          (lib.mkIf (features.logo || features.vt) {
            DRM = yes;
            DRM_FBDEV_EMULATION = yes;
            DRM_VIRTIO_GPU = yes;

            # virtio gpu requires PCI
            PCI = yes;
            VIRTIO_MENU = yes;
            VIRTIO_PCI = yes;
            PCI_HOST_GENERIC = yes;
          })
        ]))
    ];
  };

  defconfig = linuxConfig {
    inherit src;
    makeTarget = "tinyconfig";
  };

  # TODO:
  #  - apply structured config
  #    -> remove duplicate entries keeping last
  #  - re-"normalize" config against kernel config
  #  - validate structuredConfig non-optional options are present warn on optional missing
  configfile = runCommandNoCC "linux-merged-config" {} ''
    cat >> $out <<EOF
    #
    # From defconfig
    #
    EOF
    cat ${defconfig} >> $out
    cat >> $out <<EOF

    #
    # From structed attributes
    #
    ${structuredConfig.config.configfile}
    EOF
  '';
in

(
linuxManualConfig rec {
  # Required args
  inherit stdenv lib;
  inherit (base) version;
  inherit src;
  extraMakeFlags = [
    "KBUILD_BUILD_VERSION=1-smolix"
  ];
  kernelPatches = [
  ];
  inherit configfile;
}
).overrideAttrs({ postPatch ? "", postInstall ? "" , ... }: {

  postConfigure = ''
    (cd $buildRoot
    ${structuredConfig.config.validatorSnippet}
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
})
