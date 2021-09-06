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
        DEBUG_KERNEL = yes;
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

    (mkFeature "uefi" {
      EFI = yes;
      EFI_STUB = yes;
      EFI_BOOTLOADER_CONTROL = lib.mkDefault yes;
      EFI_ESRT = lib.mkDefault yes;
      EFI_CAPSULE_LOADER = lib.mkDefault yes;
      EFI_EARLYCON = lib.mkDefault yes;
      EFI_VARS_PSTORE = lib.mkDefault no;
    })
  ];
  options.wip = {
    kernel = {
      structuredConfig = mkOption {
        # TODO: actual type that merges on level of the structured config.
        type = with types; attrsOf attrs;
        default = {};
        description = ''
          Structured kernel configuration options for the celun build.
        '';
      };
      defconfig = mkOption {
        type = with types; oneOf [ str package ];
        default = "tinyconfig";
        description = ''
          Name of the defconfig from the kernel package to use.
        '';
      };
      package = mkOption {
        type = types.package;
        default = pkgs.linux_5_13;
        description = ''
          Base linux package to use.

          The `src` and `version` attributes end up used.
        '';
      };
      logo = mkOption {
        type = with types; nullOr (oneOf [package path]);
        default = null;
        description = ''
          Image used to replace the Linux logo.
        '';
      };
      logoPPM = mkOption {
        type = with types; nullOr package;
        default = null;
        internal = true;
        description = ''
          Converted output for the Linux logo.
        '';
      };
      output = mkOption {
        type = types.package;
        internal = true;
        description = ''
          Built kernel output.
        '';
      };
    };
  };
  config = {
    build.kernel = lib.mkDefault config.wip.kernel.output;
    wip = {
      kernel.logoPPM = lib.mkIf (cfg.logo != null) (pkgs.runCommandNoCC "logo_linux_clut224.ppm" {
        nativeBuildInputs = with pkgs.buildPackages; [
          imagemagick
          netpbm
          # Needed for netpbm; packaging issue it seems.
          perl
        ];
      } ''
        (
        PS4=" $ "
        set -x
        convert ${cfg.logo} converted.ppm
        ppmquant 224 converted.ppm > quantized.ppm
        pnmnoraw quantized.ppm > $out
        )
      '');
      kernel.output = pkgs.celun.configurableLinux {
        inherit (config.wip.kernel) defconfig structuredConfig logoPPM;
        inherit (config.wip.kernel.package) src version;
      };

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
  };
}
