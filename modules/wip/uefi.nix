{ config, lib, pkgs, ... }:

let
  inherit (lib)
    mkIf
    mkMerge
    mkOption
    optionalString
    types
  ;
  inherit (pkgs.stdenv.hostPlatform.linux-kernel) target;
  kernel = config.wip.kernel.output;
  inherit (config.wip.stage-1.output) initramfs;

  # Look-up table to translate from targetPlatform to U-Boot names.
  uefiPlatforms = {
    "i686-linux"    = "ia32";
    "x86_64-linux"  =  "x64";
    "aarch64-linux" = "aa64";
  };

  cfg = config.wip.uefi;

  # TODO
  kernelParamsFile = pkgs.writeText "kernel-cmdline" ''
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
      "${pkgs.libudev}/lib/systemd/boot/efi/linux${cfg.platform}.efi.stub" \
      "$out"
  '';
in
{
  options = {
    wip.uefi = {
      enabled = mkOption {
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
      platform = mkOption {
        internal = true;
        type = types.str;
        description = ''
          UEFI platform identifier.
        '';
      };
    };
  };

  config = mkIf cfg.enabled {
    wip.uefi = {
      platform = uefiPlatforms.${pkgs.targetPlatform.system};
    };
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
