{ config, lib, ... }:

let
  inherit (lib)
    mkOption
    types
  ;
in
{
  imports = [
  ];

  options = {
    availableFilesystems = mkOption {
      type = with types; listOf str;
      internal = true;
    };
    filesystem = mkOption {
      type = types.enum config.availableFilesystems;
      description = ''
        Filesystem used in this filesystem image.
      '';
    };
  };
}
