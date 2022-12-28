{ config, lib, ... }:

{
  device = {
    name = "qemu/mips-32";
    config.qemu.enable = true;
  };

  hardware = {
    cpu = "generic-mips32";
  };
  wip.kernel.defconfig = "malta_defconfig";

  device.config.qemu = {
    qemuOptions = [
      "-machine malta"
    ];
  };
}
