{ config, lib, pkgs, ... }:

let
  inherit (config.celun.eval) verbosely;

  cfg = config.celun.system;
  inherit (config.nixpkgs) localSystem;

  # The platform selected by the configuration
  selectedPlatform = lib.systems.elaborate cfg.system;
in
{
  options.celun = {
    system = {
      automaticCross = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Enables automatic configuration of cross-compilation.

          **Note** that while it is disabled by default, the default.nix at the
          root of the project _will_ enable it.
        '';
      };
      system = lib.mkOption {
        # Known supported target types
        type = lib.types.enum [
          "i686-linux"
          "x86_64-linux"
          "armv5tel-linux"
          "armv6l-linux"
          "armv7l-linux"
          "aarch64-linux"
        ];
        description = ''
          Defines the kind of target architecture system the device is.

          By default, this will also setup cross-compilation where possible.
        '';
      };
    };
  };

  config = {
    assertions = [
      {
        assertion = pkgs.targetPlatform.system == cfg.system;
        message = ''
          pkgs.targetPlatform.system expected to be `${cfg.system}`, is `${pkgs.targetPlatform.system}`.
            TIP: enable `celun.system.automaticCross`, which will impurely automatically enable cross-compilation.
        '';
      }
    ];

    nixpkgs.crossSystem = lib.mkIf cfg.automaticCross (
      lib.mkIf (
        let result = selectedPlatform.system != localSystem.system; in
          verbosely (builtins.trace "Building with crossSystem?: ${selectedPlatform.system} != ${localSystem.system} → ${if result then "we are" else "we're not"}.")
          result
      ) (verbosely (builtins.trace "    crossSystem: config: ${selectedPlatform.config}") selectedPlatform)
    );
  };
}
