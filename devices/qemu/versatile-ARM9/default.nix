{ config, lib, pkgs, ... }:

{
  imports = [
    ../shared.nix
  ];

  hardware = {
    cpu = "generic-armv5tel";
  };
  wip.kernel.package = pkgs.linux_4_19;
  wip.kernel.defconfig = "versatile_defconfig";
  wip.kernel.structuredConfig =
    with lib.kernel;
    let
      inherit (config.wip.kernel) features;
    in
    lib.mkMerge [
      {
        # Those are seemingly required to be enabled for versatile_defconfig.
        VT_CONSOLE = yes;
        FRAMEBUFFER_CONSOLE = yes;
      }
      # TODO: disable/enable kernel config according to features.
    ]
  ;

  boot.cmdline = [
    "mem=${toString config.device.qemu.memorySize}M"
  ];
  device.qemu = {
    memorySize = 256;
    qemuOptions = [
      "-machine versatilepb"
      ''-dtb "$self"/dtbs/versatile-pb.dtb''
    ];
  };
}
