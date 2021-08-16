{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption types;
in
{
  config = {
    build = {
      wip = pkgs.celun.output.override({
        initramfs = config.wip.stage-1.output.initramfs;
        kernel = pkgs.celun.configurableLinux {
          inherit (config.wip.kernel) defconfig structuredConfig;
          inherit (config.wip.kernel.package) src version;
        };
      });
    };
  };
}
