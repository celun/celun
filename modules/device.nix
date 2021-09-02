{ lib, ... }:

let
  inherit (lib)
    mkOption
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
    };
  };
}
