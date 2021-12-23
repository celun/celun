{ config, lib, pkgs, ... }:

let
  inherit (lib) mkIf mkMerge mkOption types;
  cfg = config.hardware.cpus;
in
{
  options.hardware.cpus = {
    allwinner-a64.enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable when system is an Allwinner A64.";
      internal = true;
    };
  };

  config = mkMerge [
    (lib.mkIf cfg.allwinner-a64.enable {
      celun.system.system = "aarch64-linux";
      wip.u-boot = {
        enable = true;
        fdt_addr_r     = "0x4FA00000";
        kernel_addr_r  = "0x40080000";
        pxefile_addr_r = "0x4FD00000";
        ramdisk_addr_r = "0x4FF00000";
      };

      wip.kernel.structuredConfig =
        with lib.kernel;
        let
          inherit (config.wip.kernel) features;
        in
        lib.mkMerge [
          (lib.mkIf features.serial {
            # Needed or serial drops off...
            # Note that this is stripped from savedefconfig...
            # ... and using tinyconfig does not play nice.
            # XXX # SERIAL_8250_DW = yes;
            # XXX # SERIAL_OF_PLATFORM = yes;
          })
        ]
      ;
    })
  ];
}
