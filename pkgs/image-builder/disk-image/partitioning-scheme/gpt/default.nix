{ config, lib, pkgs, ... }:

let
  enabled = config.partitioningScheme == "gpt";
  inherit (lib)
    mkIf
    mkMerge
    mkOption
    types
  ;
in
{
  options.gpt = {
    diskID = mkOption {
      type = types.nullOr config.helpers.types.uuid;
      default = null;
      description = ''
        Identifier for the disk.
      '';
    };

    partitionEntriesCount = mkOption {
      type = types.int;
      default = 128;
      description = ''
        Number of partitions in the partition table.

        The default value is likely appropriate.
      '';
    };
  };

  config = mkMerge [
    { availablePartitioningSchemes = [ "gpt" ]; }
    (mkIf enabled {
      output = pkgs.callPackage ./builder.nix {
        inherit config;
      };
    })
  ];
}
