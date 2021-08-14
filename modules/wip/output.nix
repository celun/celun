{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption types;
in
{
  options.wip = {
    # All outputs the current configuration of smolix produces.
    output = mkOption {
      type = with types; lazyAttrsOf unspecified;
    };
  };

  config.wip = {
    output = pkgs.smolix.output.override({
      kernel = pkgs.smolix.configurableLinux {
        inherit (config.wip.kernel) defconfig structuredConfig;
        inherit (config.wip.kernel.package) src version;
      };
    });
  };
}
