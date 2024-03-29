{ config, lib, pkgs, ... }:

let
  inherit (lib)
    head
    splitString
  ;
in
{
  device = {
    name = "qemu/raspi1ap-armv6l";
    config.qemu.enable = true;
  };

  hardware = {
    cpu = "generic-armv6l";
  };
  # Broken at between 4.19 and 5.4...
  # `Attempted to kill init! exitcode=0x0000000b`
  # wip.kernel.package = pkgs.linux_5_4;
  # See also: https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=977126
  # NOTE: Using this weird `mkDerivation` here is a workaround to coax the
  # `manual-config` builder to build :/
  wip.kernel.package = pkgs.stdenv.mkDerivation {
    inherit (pkgs.linux_4_19) src;
    version = head (splitString "-" pkgs.linux_4_19.version);
  };
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
  device.config.qemu = {
    memorySize = 512;
    qemuOptions = [
      "-machine raspi1ap"
      "-dtb $self/dtbs/bcm2835-rpi-b-plus.dtb"
    ];
  };
}
