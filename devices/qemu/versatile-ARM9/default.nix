{ config, lib, pkgs, ... }:

{
  device = {
    name = "qemu/versatile-ARM9";
    config.qemu.enable = true;
  };

  hardware = {
    cpu = "generic-armv5tel";
  };
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
      (lib.mkIf (features.block) {
        # For storage
        PCI = yes;
        PCI_VERSATILE = yes;
        SCSI = yes;
        SCSI_SYM53C8XX_2 = yes;
        BLK_DEV_SD = yes;
      })
      # TODO: disable/enable kernel config according to features.
    ]
  ;

  boot.cmdline = [
    "mem=${toString config.device.config.qemu.memorySize}M"
  ];
  device.config.qemu = {
    memorySize = 256;
    qemuOptions = [
      "-machine versatilepb"
      ''-dtb "$self"/dtbs/versatile-pb.dtb''
    ];
  };
}
