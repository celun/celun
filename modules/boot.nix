{ config, lib, ... }:

let
  inherit (lib)
    mkOption
    types
  ;
in
{
  options = {
    boot = {
      cmdline = mkOption {
        type = with types; listOf str;
        default = [];
        description = ''
          Kernel command-line for the system.
        '';
      };
    };
  };
}
