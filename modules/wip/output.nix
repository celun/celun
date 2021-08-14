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
    output = {
      wip = pkgs.smolix.output.override({
        initramfs = config.wip.stage-1.output.initramfs;
        kernel = pkgs.smolix.configurableLinux {
          inherit (config.wip.kernel) defconfig structuredConfig;
          inherit (config.wip.kernel.package) src version;
        };
      });
    };
  };
}
