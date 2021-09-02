{ config, lib, ... }:

let
  inherit (lib)
    concatStringsSep
    mkOption
    splitString
    types
  ;
in
{
  options = {
    device = {
      name = mkOption {
        type = types.str;
        internal = true;
        description = ''
          Name of the device being built.
        '';
      };
      nameForDerivation = mkOption {
        internal = true;
        description = ''
          Name of the device, usable in a derivation name.
        '';
      };
    };
  };
  config = {
    device.nameForDerivation = concatStringsSep "_" (splitString "/" config.device.name);
  };
}
