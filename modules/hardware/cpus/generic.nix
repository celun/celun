{ config, lib, pkgs, ... }:

# Prefer describing the hardware as precisely as possible, rather than relying
# on generic hardware in devices.

let
  inherit (lib) mkIf mkMerge mkOption types;
  cfg = config.hardware.cpus;
in
{
  options.hardware.cpus = {
    generic-i686.enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable when system is a generic i686";
      internal = true;
    };
    generic-x86_64.enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable when system is a generic x86_64";
      internal = true;
    };
    generic-aarch64.enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable when system is a generic AArch64";
      internal = true;
    };
    generic-armv5tel.enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable when system is a generic armv5tel";
      internal = true;
    };
    generic-armv6l.enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable when system is a generic armv6l";
      internal = true;
    };
    generic-armv7l.enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable when system is a generic armv7l";
      internal = true;
    };
  };

  config = {
    celun.system.system = mkMerge [
      (lib.mkIf cfg.generic-i686.enable "i686-linux")
      (lib.mkIf cfg.generic-x86_64.enable "x86_64-linux")
      (lib.mkIf cfg.generic-armv5tel.enable "armv5tel-linux")
      (lib.mkIf cfg.generic-armv6l.enable "armv6l-linux")
      (lib.mkIf cfg.generic-armv7l.enable "armv7l-linux")
      (lib.mkIf cfg.generic-aarch64.enable "aarch64-linux")
    ];
  };
}
