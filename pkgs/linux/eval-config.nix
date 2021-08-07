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
            if val == null then "# CONFIG_${key} is not set" else
            # TODO: Handle optional here??
            # This could only work if we are given the kernel version to work from.
            if (item.optional)
            then "CONFIG_${key}=${mkValue val}"
            else "CONFIG_${key}=${mkValue val}"
          ;

          mkConf = cfg: lib.concatStringsSep "\n" (lib.mapAttrsToList mkConfigLine cfg);
          configfile = mkConf config.settings;

          validatorSnippet = ''
            (
            echo
            echo ":: Validating kernel configuration"
            echo
            error=0
            warn=0
            #set -x

            ${lib.concatMapStringsSep "\n" ({key, item}:
            let
              line = mkConfigLine key item;
              val = if item.freeform != null then item.freeform else item.tristate;
              lineNotSet = "# CONFIG_${key} is not set";
              linePattern = "^CONFIG_${key}=";
              presencePattern = "CONFIG_${key}[ =]";
            in
            ''
              if [[ "${line}" == *" is not set" ]]; then
                # An absent unset value is *totally fine*.
                if (
                  # Present
                  (grep '${presencePattern}') &&
                  # And not unset
                  ! (grep '^${lineNotSet}$' .config)
                ) > /dev/null; then
                  ${if item.optional then ''
                    ((++warn))
                    echo -n "Warning: "
                  '' else ''
                    ((++error))
                    echo -n "ERROR: "
                  ''}
                  value=$(grep 'CONFIG_${key}[= ]' .config || :)
                  echo "CONFIG_${key} should be left «is not set»... set to: «$value»."
                fi
              elif [[ "${line}" == *=n ]]; then
                # An absent `=n` value is *totally fine*.
                if (
                  # Present
                  (grep '${presencePattern}') &&
                  # And neither unset or set to the value
                  ! (grep '^${line}$' .config || grep '^${lineNotSet}$ .config')
                ) > /dev/null; then
                  ${if item.optional then ''
                    ((++warn))
                    echo -n "Warning: "
                  '' else ''
                    ((++error))
                    echo -n "ERROR: "
                  ''}
                  value=$(grep 'CONFIG_${key}[= ]' .config || :)
                  echo "CONFIG_${key} not set to «${line}»... set to: «$value»."
                fi
              else
                if ! grep '^${line}$' .config > /dev/null; then
                  ${if item.optional then ''
                    ((++warn))
                    echo -n "Warning: "
                  '' else ''
                    ((++error))
                    echo -n "ERROR: "
                  ''}
                  value=$(grep 'CONFIG_${key}[= ]' .config || :)
                  if [[ -z "$value" ]]; then
                    echo "CONFIG_${key} is expected to be set to «${line}», but is not present in config file."
                    else
                    echo "CONFIG_${key} not set to «${line}»... set to: «$value»."
                  fi
                fi
              fi

            '') (lib.mapAttrsToList (key: item: { inherit key item; }) config.settings)}

            echo
            echo "Finished validating..."
            echo "   Errors: $error"
            echo "   Warnings: $warn"
            echo
            if ((error)); then
              echo "=> Kernel configuration validation failed..."
              echo "... aborting."
              false
            fi

            if ((warn)); then
              echo "=> Kernel configuration passed with warnings..."
              echo "... continuing."
            fi
            )
          '';
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
            validatorSnippet = lib.mkOption {
              readOnly = true;
              type = lib.types.str;
              description = ''
                String that can directly be used as a kernel config file contents.
              '';
            };
          };
          config = {
            inherit configfile validatorSnippet;
          };
        }
      )
      { settings = structuredConfig; _file = "(structuredConfig argument)"; }
    ] ++ modules;
  }).config;
}
