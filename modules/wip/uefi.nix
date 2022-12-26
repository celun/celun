{ config, lib, pkgs, ... }:

let
  inherit (lib)
    concatStringsSep
    mkIf
    mkMerge
    mkOption
    optionalString
    types
  ;
  inherit (pkgs.stdenv.hostPlatform.linux-kernel) target;
  kernel = config.wip.kernel.output;
  inherit (config.wip.stage-1.output) initramfs;
  inherit (config.device) dtbFiles;
  firstDTBFile = "${kernel}/dtbs/${builtins.elemAt dtbFiles 0}";

  # Look-up table to translate from targetPlatform to U-Boot names.
  uefiPlatforms = {
    "i686-linux"    = "ia32";
    "x86_64-linux"  =  "x64";
    "aarch64-linux" = "aa64";
  };

  cfg = config.wip.uefi;

  kernelParamsFile = pkgs.writeText "kernel-cmdline" ''
    ${concatStringsSep " " config.boot.cmdline}
  '';

  efiKernel = pkgs.runCommandNoCC "linux_${cfg.platform}.efi" {
    nativeBuildInputs = [
      pkgs.stdenv.cc.bintools.bintools_bin
    ];
  } ''
    ${pkgs.stdenv.cc.bintools.targetPrefix}objcopy \
      --add-section .cmdline="${kernelParamsFile}"          --change-section-vma  .cmdline=0x30000 \
      --add-section .linux="${kernel}/${target}"            --change-section-vma  .linux=0x2000000 \
      ${optionalString cfg.bundleInitramfs "--add-section .initrd='${initramfs}'                  --change-section-vma .initrd=0x3000000"} \
      ${optionalString cfg.bundleDTB "--add-section .dtb='${firstDTBFile}' --change-section-vma .dtb=0x40000"} \
      "${pkgs.systemd}/lib/systemd/boot/efi/linux${cfg.platform}.efi.stub" \
      "$out"
  '';
in
{
  options = {
    wip.uefi = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enables UEFI default configuration, and build products.
        '';
      };
      bundleInitramfs = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Whether to bundle the initramfs in the kernel EFI stub or not.

          > **Tip**: Bundling is likely desirable as otherwise another
          > bootloader stage will be required to prepare and load the
          > initramfs.
        '';
      };
      bundleDTB = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether to bundle the first dtb file listed in `config.devices.dtbFiles`

          > **Tip**: Bundle only if necessary. It is better to rely on the
          > Platform Firmware provided FDT. Bundling a dtb file makes the
          > build produced less universal.
        '';
      };
      platform = mkOption {
        internal = true;
        type = types.str;
        description = ''
          UEFI platform identifier.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    wip.uefi = {
      platform = uefiPlatforms.${pkgs.targetPlatform.system};
    };
    build.efiKernel = efiKernel;
    build.disk-image = (pkgs.celun.image-builder.evaluateDiskImage {
      config =
        { config, ... }:

        let inherit (config) helpers; in
        {
          partitioningScheme = "gpt";
          partitions = [
            (helpers.makeESP {
              filesystem = {
                extraPadding = helpers.size.MiB 10;
                populateCommands = ''
                  mkdir -p EFI/boot
                  cp ${initramfs} EFI/boot/initramfs
                  cp ${efiKernel} EFI/boot/boot${cfg.platform}.efi
                '';
              };
            })
          ];
        }
      ;
    }).config.output;

    wip.kernel.features = {
      uefi = true;
    };
  };
}
