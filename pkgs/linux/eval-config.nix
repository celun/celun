# This file includes fragments of <nixpkgs/nixos/modules/system/boot/kernel_config.nix>
{ pkgs
, modules ? []
, structuredConfig
}: rec {
  module = import (pkgs.path + "/nixos/modules/system/boot/kernel_config.nix");
  config = (pkgs.lib.evalModules {
    modules = [
      module
      (
        #
        # This module adds kernel config file generation from the structured attributes.
        #
        { config, lib, ... }:

        let
          mkValue = with lib; val:
          let
            isNumber = c: elem c ["0" "1" "2" "3" "4" "5" "6" "7" "8" "9"];
          in
          if (val == "") then "\"\""
            else if val == "y" || val == "m" || val == "n" then val
            else if all isNumber (stringToCharacters val) then val
            else if substring 0 2 val == "0x" then val
            else val # FIXME: fix quoting one day
          ;

          mkConfigLine = key: item:
            let
              val = if item.freeform != null then item.freeform else item.tristate;
            in
            if val == null then "# CONFIG_${key} is not set\n" else
            # TODO: Handle optional here??
            # This could only work if we are given the kernel version to work from.
            if (item.optional)
            then "CONFIG_${key}=${mkValue val}\n"
            else "CONFIG_${key}=${mkValue val}\n"
          ;

          mkConf = cfg: lib.concatStrings (lib.mapAttrsToList mkConfigLine cfg);
          configfile = mkConf config.settings;
        in
        {
          options = {
            configfile = lib.mkOption {
              readOnly = true;
              type = lib.types.str;
              description = ''
                String that can directly be used as a kernel config file contents.
              '';
            };
          };
          config = {
            inherit configfile;
          };
        }
      )
      { settings = structuredConfig; _file = "(structuredConfig argument)"; }
    ] ++ modules;
  }).config.configfile;
}
