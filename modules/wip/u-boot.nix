{ config, lib, pkgs, ... }:

let
  inherit (lib)
    concatStringsSep
    escapeShellArg
    mkIf
    mkMerge
    mkOption
    optionalString
    types
  ;
  inherit (pkgs.stdenv.hostPlatform.linux-kernel) target;
  kernel = config.wip.kernel.output;
  inherit (config.wip.stage-1.output) initramfs;
  inherit (config.device) nameForDerivation dtbName;
  inherit (config.wip.u-boot) platform;
  inherit (config.wip) u-boot;
  inherit (config) build;

  # Look-up table to translate from targetPlatform to U-Boot names.
  u-bootPlatforms = {
    "i686-linux"      = "x86";
    "x86_64-linux"    = "x86_64";
    "armv5tel-linux"  = "arm";
    "armv6l-linux"    = "arm";
    "armv7l-linux"    = "arm";
    "aarch64-linux"   = "arm64";
  };

  cfg = config.wip.u-boot;

  # This script serves to work around the issue that `bootargs` is not a valid
  # FIT image input.
  # Assume the boot script is basically doing the same job as this hypothetical
  # image type would do.
  # It **needs** to be loaded elsewhere than `$kernel_addr_r`, but somewhere.
  # Since there is no way to get the default loadaddr (CONFIG_SYS_LOAD_ADDR)
  # in stock U-Boot, we're relying on `$pxefile_addr_r`. Ugh.
  #
  # Usage:
  #
  #   => setenv loadaddr $pxefile_addr_r
  #   => load mmc 1:2 $loadaddr default.itb
  #   => source $loadaddr:default-boot
  #
  # Why not provide bootargs as `/chosen` dtbo overlay? Because it requires
  # a non-default option to be turned on (not an issue), but the real kicker is
  # it requires the end-user to care about the load address for the FDT
  # overlay. This is too much of a pain; manually managing addresses.
  bootScript = pkgs.writeText "u-boot-script" ''
    echo
    echo " :: Auto-booting FIT image..."
    echo
    setenv bootargs ${escapeShellArg (concatStringsSep " " config.boot.cmdline)}
    bootm $loadaddr#default-boot
  '';

  compression = "lzma";

  compress = { file, name }: pkgs.runCommandNoCC "${name}.${compression}" {
    nativeBuildInputs = [
    ];
    inherit file;
  } ''
    lzma --compress --extreme -9 < "$file" > "$out"
  '';

  defaultITS = pkgs.writeText "default.its" ''
    /dts-v1/;

    / {
      description = ${builtins.toJSON nameForDerivation};
      #address-cells = <1>;

      images {
        kernel {
          description = "Kernel";
          data = /incbin/("${compress {
            name = "Image";
            file = "${build.kernel}/Image";
          }}");
          type = "kernel";
          arch = "${platform}";
          os = "linux";
          compression = "${compression}";
          load  = <${u-boot.kernel_addr_r}>;
          entry = <${u-boot.kernel_addr_r}>;
          hash {
            algo = "sha1";
          };
        };
        initrd {
          description = "Initrd";
          data = /incbin/("${build.initramfs}");
          type = "ramdisk";
          arch = "${platform}";
          os = "linux";
          compression = "none"; // already compressed
          hash {
            algo = "sha1";
          };
        };
        fdt {
          description = "DTB";
          data = /incbin/("${compress {
            name = "fdt";
            file = "${build.kernel}/dtbs/${dtbName}";
          }}");
          type = "flat_dt";
          arch = "${platform}";
          compression = "${compression}";
          load = <${u-boot.fdt_addr_r}>;
          hash {
            algo = "sha1";
          };
        };
        default-boot {
          description = "Default boot script";
          data = /incbin/("${bootScript}");
          type = "script";
          // Scripts won't be uncompressed when ran using e.g. `source $loadaddr:default-boot`.
          compression = "none";
          hash {
            algo = "sha1";
          };
        };
      };

      configurations {
        default = "<none>";
        default-boot {
          description = "Default Boot Elements";
          kernel = "kernel";
          fdt = "fdt";
          ramdisk = "initrd";
          hash {
            algo = "sha1";
          };
        };
      };

    };
  '';

  fitImage = pkgs.runCommandNoCC "${nameForDerivation}.fit" {
    nativeBuildInputs = [
      pkgs.buildPackages.dtc
      pkgs.buildPackages.ubootTools
    ];
  } ''
    mkimage -f ${defaultITS} $out
  '';

  mkAddrOption = name: mkOption {
    type = types.str;
    description = ''
      Platform-specific value for ${name}
    '';
  };

in
{
  options = {
    wip.u-boot = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enables U-Boot default configuration, and build products.
        '';
      };
      platform = mkOption {
        internal = true;
        type = types.str;
        description = ''
          UEFI platform identifier.
        '';
      };
      fdt_addr_r     = mkAddrOption "fdt_addr_r";
      kernel_addr_r  = mkAddrOption "kernel_addr_r";
      pxefile_addr_r = mkAddrOption "pxefile_addr_r";
      ramdisk_addr_r = mkAddrOption "ramdisk_addr_r";
    };
  };

  config = mkIf cfg.enable {
    wip.u-boot = {
      platform = u-bootPlatforms.${pkgs.targetPlatform.system};
    };
    build.fitImage = fitImage;
  };
}