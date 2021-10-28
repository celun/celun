{ config, lib, pkgs, ... }:

let
  inherit (lib) mkIf mkMerge mkOption types;
  cfg = config.hardware.cpus;
in
{
  options.hardware.cpus = {
    rockchip-rk3399.enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable when system is a Rockchip RK3399.";
      internal = true;
    };
  };

  config = mkMerge [
    (lib.mkIf cfg.rockchip-rk3399.enable {
      celun.system.system = "aarch64-linux";
      wip.u-boot = {
        enable = true;
        fdt_addr_r     = "0x01f00000";
        kernel_addr_r  = "0x02080000";
        pxefile_addr_r = "0x00600000";
        ramdisk_addr_r = "0x06000000";
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
            SERIAL_8250_DW = yes;
            SERIAL_OF_PLATFORM = yes;
          })
        ]
      ;
    })
  ];
}

