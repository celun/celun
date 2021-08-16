{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption types;
in
{
  options = {
    build = mkOption {
      type = with types; lazyAttrsOf unspecified;
      description = ''
        All end-user facing outputs the current configuration produces.

        It is recommended that `default` is used as an alias to the most likely
        output desired by the end-user. E.g. a disk image, or a script to run
        the emulated system.

        Internally used outputs *MUST* implement a `*.output` option, and
        modules should depend on these fully qualified options instead. Note
        that such an output *may* also be added to the `build` configuration
        option, e.g. for a partition image.
      '';
    };
  };
}
