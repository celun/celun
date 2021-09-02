{ config, lib, pkgs, ... }:

{
  imports = [
    ../shared.nix
  ];

  hardware = {
    cpu = "generic-armv6l";
  };
  # Broken at between 4.19 and 5.4...
  # `Attempted to kill init! exitcode=0x0000000b`
  # wip.kernel.package = pkgs.linux_5_4;
  # See also: https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=977126
  wip.kernel.package = pkgs.linux_4_19;
  wip.kernel.defconfig = "bcm2835_defconfig";
  wip.kernel.structuredConfig =
    with lib.kernel;
    let
      inherit (config.wip.kernel) features;
    in
    lib.mkMerge [
      (lib.mkIf (features.logo || features.vt || features.graphics) {
        DRM = yes;
        DRM_FBDEV_EMULATION = yes;
        DRM_VC4 = yes;
      })
    ]
  ;

  boot.cmdline = [
    "earlycon=pl011,0x20201000"
    "console=ttyAMA0"
  ];
  device.qemu = {
    memorySize = 512;
    qemuOptions = [
      "-machine raspi1ap"
      "-dtb $self/dtbs/bcm2835-rpi-b-plus.dtb"
    ];
  };
}
