{ config, lib, pkgs, ... }:

let
  inherit (pkgs) stdenv;
  inherit (lib)
    mkDefault
    mkIf
    mkMerge
    mkOption
    types
  ;
  cfg = config.wip.kernel;
  mkFeature = name: structuredConfig: {
    options.wip.kernel.features.${name} = mkOption {
      type = types.bool;
      default = false;
      description = ''
          Enables the `${name}` kernel features set.
      '';
    };
    config.wip.kernel = mkIf cfg.features.${name} {
      inherit structuredConfig;
    };
  };
in
{
  # These imports define the most basic options required for the feature to work.
  imports = with lib.kernel; [
    (mkFeature "printk" (mkMerge [
      {
        # Without printk, kernel is mostly silent
        PRINTK = yes;
        # Not required, but helpful
        PRINTK_TIME = yes;

        # Outputs printk messages to TTY (when TTY is built in)
        TTY_PRINTK = option yes;
      }
      # Apparently arm64 doesn't have EARLY_PRINTK?
      (mkIf (stdenv.isx86_32 || stdenv.isx86_64) {
        # This is not recommended (oddly enough enabled in NixOS)
        # https://cateee.net/lkddb/web-lkddb/EARLY_PRINTK.html
        EARLY_PRINTK = yes;
      })
      (mkIf (stdenv.isAarch32) {
        EARLY_PRINTK = yes;
        # Required for EARLY_PRINTK
        DEBUG_LL = yes;
      })
    ]))

    (mkFeature "serial" (mkMerge [
      {
        VT = mkDefault no;
        # Serial output requires TTY
        TTY = yes;

        # Most likely present on x86 AFAIUI
        # Possibly present on ARM too
        SERIAL_8250 = yes;
        SERIAL_8250_CONSOLE = yes;
      }
      (mkIf (stdenv.isAarch32 || stdenv.isAarch64) {
        # ARM
        SERIAL_AMBA_PL011 = yes;
        SERIAL_AMBA_PL011_CONSOLE = yes;
      })
    ]))

    (mkFeature "vt" {
      VT = yes;
      # VT requires TTY
      TTY = yes;
    })

    (mkFeature "graphics" {
      FB = yes;
      # Assuming `graphics` will often be used without VTs and TTY
      FRAMEBUFFER_CONSOLE = lib.mkDefault (option no);
      TTY = lib.mkDefault (option no);
    })

    (mkFeature "initramfs" {
      # Support for initramfs
      BLK_DEV_INITRD = yes;
    })

    (mkFeature "logo" {
      FB = yes;
      LOGO = yes;

      # Seemingly required for LOGO
      TTY = yes;
      VT = yes;
      # Also seemingly required
      # (Additionally an fbdev will be required in some form)
      FRAMEBUFFER_CONSOLE = yes;
    })

    (mkFeature "acpi" {
      ACPI = yes;
      PCI = lib.mkDefault yes;
    })
  ];
  options.wip = {
    kernel = {
      structuredConfig = mkOption {
        # TODO: actual type that merges on level of the structured config.
        type = with types; attrsOf attrs;
        default = {};
        description = ''
          Structured kernel configuration options for the smolix build.
        '';
      };
    };
  };
  config.wip = {
    # Sets up likely desired features
    kernel.features = {
      initramfs = mkDefault true;
    };
    kernel.structuredConfig =
      let
        yes = lib.mkDefault lib.kernel.yes;
        no = lib.mkDefault lib.kernel.no;
      in
      mkMerge [
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


        # TODO: add compression dependent on initramfs compression scheme
        {
          # If looking to minimize total size, provide an uncompressed cpio
          # instead of compressing it and bundle it into the kernel image.
          # (This assumes the kernel is self-decompressing or some other
          #  compression scheme is handled by a previous boot stage)
          # e.g. 1847520 vs. 1756544
          RD_GZIP = no;
          RD_BZIP2 = no;
          RD_LZMA = no;
          RD_XZ = no;
          RD_LZO = no;
          RD_LZ4 = no;
          RD_ZSTD = no;
        }

        (lib.mkIf (stdenv.isx86_32 || stdenv.isx86_64) {
          # choice: Kernel compression mode
          # (Only one of these options can be turned on)
                              #  Comressed sizes
                              #  x86_64  |  i868
                              # =========|========
          KERNEL_GZIP  = no;  # 1270320  | 1143200
          KERNEL_BZIP2 = no;  # 1163008  | 1083248
          KERNEL_LZMA  = no;  # 1070640  |  982960
          KERNEL_XZ    = yes; # 1027440  |  941648
          KERNEL_LZO   = no;  # 1385904  | 1226448
          KERNEL_LZ4   = no;  # 1449728  | 1299712
          KERNEL_ZSTD  = no;  # 1167104  | (DNC)

          # Verdict: "for size" winner is xz.
          # Decompression speed not tested; supposedly zstd would win.
        })
      ]
    ;
  };
}
