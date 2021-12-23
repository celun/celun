{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption types;
  cfg = config.hardware;
in
{
  imports = [
    ./generic.nix

    ./allwinner.nix
    ./rockchip.nix
  ];

  options.hardware = {
    cpu = mkOption {
      # This is used to describe a specific CPU on a device, while giving it a name.
      type = types.str;
      description = ''
        Give the CPU name for the device.
      '';
    };
  };

  config = {
    hardware.cpus."${cfg.cpu}".enable = true;
  };
}
