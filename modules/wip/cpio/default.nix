{ config, lib, pkgs, ... }:

/*

Format used internally:

 - https://github.com/torvalds/linux/blob/dfa377c35d70c31139b1274ec49f87d380996c42/usr/gen_init_cpio.c#L452-L492

*/

let
  inherit (lib)
    concatStringsSep
    concatStrings
    mapAttrsToList
    mkOption
    types
  ;

  listEntrySubmodule = {
    options = {
      type = mkOption {
        type = types.enum [ "file" "dir" "nod" "slink" "pipe" "sock" ];
      };
      # name is the key of the entry
      location = mkOption {
        type = types.str;
      };
      target = mkOption {
        type = types.str;
      };
      mode = mkOption {
        type = types.strMatching "[0-7]{3,4}";
      };
      uid = mkOption {
        type = types.strMatching "[0-9]+";
        default = "0";
      };
      gid = mkOption {
        type = types.strMatching "[0-9]+";
        default = "0";
      };
      devType = mkOption {
        type = types.enum [ "b" "c" ];
      };
      maj = mkOption {
        type = types.strMatching "[0-9]+";
      };
      min = mkOption {
        type = types.strMatching "[0-9]+";
      };
      hardLinks = mkOption {
        type = with types; listOf str;
      };
    };
  };

  cpioSubmodule  =
    { config, ... }:
    let
      additionalEntriesFragment = pkgs.writeText "cpio-additional-entries.list" ''

        # Additional entries

        ${concatStrings (mapAttrsToList (name: entry: ''
          ${entry.type} ${name} ${with entry; {
            file  = "${location} ${mode} ${uid} ${gid} ${concatStringsSep " " hardLinks}";
            dir = "${mode} ${uid} ${gid}";
            nod = "${mode} ${uid} ${gid} ${devType} ${maj} ${min}";
            slink = "${target} ${mode} ${uid} ${gid}";
            pipe  = "${mode} ${uid} ${gid}";
            sock  = "${mode} ${uid} ${gid}";
          }.${entry.type}}
        '') config.additionalListEntries)}
      '';
    in
    {
      options = {
        contents = mkOption {
          # Attrset so values can be overriden.
          type = with types; (lazyAttrsOf package);
          description = ''
            The content of these derivations will be added to the initramfs.

            > **NOTE**: The key of the attrset is used solely to allow overriding.
          '';
        };

        additionalListEntries = mkOption {
          type = with types; lazyAttrsOf (submodule listEntrySubmodule);
          default = {};
          internal = true;
          description = ''
            The key is the path.
          '';
          # TODO
          # example = {
          #   "/proc" = {
          #     type = "dir";
          #     mode = "755";
          #   };
          #   "/sys" = {
          #     type = "dir";
          #     mode = "755";
          #   };
          #   "/mnt" = {
          #     type = "dir";
          #     mode = "755";
          #   };
          #   "/root" = {
          #     type = "dir";
          #     mode = "755";
          #   };
          #   "/dev" = {
          #     type = "dir";
          #     mode = "755";
          #   };
          #   "/dev/console" = {
          #     type = "nod";
          #     mode = "644";
          #     devType = "c";
          #     maj = "5";
          #     min = "1";
          #   };
          #   "/dev/loop0" = {
          #     type = "nod";
          #     mode = "644";
          #     devType = "b";
          #     maj = "7";
          #     min = "0";
          #   };
          # };
        };

        list = mkOption {
          type = types.package;
          description = ''
            Textual representation of the contents of the archive.
          '';
        };

        output = mkOption {
          type = types.package;
          description = ''
            CPIO archive.
          '';
        };
      };

      config = {
        output = pkgs.buildPackages.mkCpio {
          name = config.list.name + ".cpio";
          inherit (config) list;
        };

        list = pkgs.runCommandNoCC "cpio.list" { } ''
          ${concatStringsSep "\n" (mapAttrsToList (name: input: ''
            printf -- '-> Adding "%s" to initramfs\n' "${name}"
            (
              PS4=" $ "
              set -x
              cd ${input}
              printf '#\n# %s\n#\n' "${name}"
              find -type d -printf 'dir   /%h/%f 755 0 0 \n'
              find -type f -printf 'file  /%h/%f '"${input}/"'%h/%f %m  0 0 \n'
              find -type l -printf 'slink /%h/%f %l %m  0 0 \n'
            ) >> $out
          '') config.contents)}

          # Remove leading /. caused by the find invocations in PWD
          sed -i -e 's;/\./;/;g' $out

          # Add the additional files to the initramfs list
          cat ${additionalEntriesFragment} >> $out
        '';
      };
    }
  ;

  mkCpioOption = attrs: mkOption (attrs // {
    type = types.submodule cpioSubmodule;
  });
in
{
  options.wip.cpio = {
    lib = {
      mkOption = mkOption {
        type = types.unspecified;
        default = mkCpioOption;
        description = ''
        '';
      };
    };
  };
}
