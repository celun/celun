{ config, lib, ... }:

let
  cfg = config.celun.eval;
in
{
  options.celun = {
    eval = {
      verbose = lib.mkOption {
        type = lib.types.bool;
        default = false;
        internal = true;
        description = ''
          Enables verbose tracing during eval.

          **Note** that while it is disabled by default, the default.nix at the
          root of the project _will_ enable it.
        '';
      };
      verbosely = lib.mkOption {
        type = lib.types.unspecified;
        internal = true;
        description = ''
          Function to use to *maybe* builtins.trace things out.

          Usage:

          ```
          { config, /* ..., */ ... }:
          let
            inherit (config.celun.eval) verbosely;
          in
            /* ... */
          ```
        '';
      };
    };
  };

  config = {
    celun.eval.verbosely = msg: val: if config.celun.eval.verbose then msg val else val;
  };
}

