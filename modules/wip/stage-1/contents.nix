{ config, lib, pkgs, ... }:

let
  inherit (lib)
    concatStringsSep
    mapAttrsToList
    mkIf
    mkMerge
    mkOption
    types
  ;

  cfg = config.wip.stage-1;

  list = pkgs.runCommandNoCC "smolix-initramfs.list" { } ''
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
    '') cfg.contents)}

    sed -i -e 's;/\./;/;g' $out

    # Add more files to the initramfs
    cat >> $out <<EOF

    dir /proc 755 0 0
    dir /sys 755 0 0
    dir /mnt 755 0 0
    dir /root 755 0 0

    dir /dev 755 0 0
    nod /dev/console 644 0 0 c 5 1
    nod /dev/loop0   644 0 0 b 7 0
    EOF
  '';
in
{
  options.wip.stage-1 = {
    contents = mkOption {
      # Attrset so values can be overriden.
      type = with types; (lazyAttrsOf package);
    };
  };

  config = {
    wip.stage-1.cpio = lib.mkDefault (pkgs.buildPackages.mkCpio {
      name = list.name + ".cpio";
      inherit list;
    });

    wip.stage-1.contents = {
      _default = pkgs.smolix.minimal-initramfs;
    };
  };
}
