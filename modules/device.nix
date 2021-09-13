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
      dtbName = mkOption {
        type = types.str;
        internal = true;
        description = ''
          Name of the mainline dtb file. For arm64 (AArch64), prefix with the
          SoC vendor folder name.
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
