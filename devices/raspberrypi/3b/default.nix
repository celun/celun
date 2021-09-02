{ config, lib, pkgs, ... }:

/*

This applies only to the Raspberry Pi 3B, possibly works for the 3A.

Support for the 3B+ is unknown.

This currently assumes the use of the vendor kernel, from the Raspberry Pi
Foundation. This is because it was judged to be highly probable that in
embedded use cases it would need to be used.

*/

let
  inherit (lib)
    head
    mkMerge
    splitString
  ;
  inherit (pkgs.stdenv) isAarch64;
in
{
  device = {
    name = "raspberrypi/3b";
    config.raspberrypi.enable = true;
  };

  hardware = {
    cpu = "generic-aarch64";
  };

  boot.cmdline = lib.mkAfter [
    "earlycon=uart8250,mmio32,0x3f215040"
    "console=serial0,115200"
  ];

  # overrideAttrs doesn't work on kernel derivations ¯\_(ツ)_/¯
  # We're (ab)using the mkDerivation here to satisfy the package type.
  wip.kernel.package = pkgs.stdenv.mkDerivation {
    inherit (pkgs.linux_rpi3) src;
    version = head (splitString "-" pkgs.linux_rpi3.version);
  };
  wip.kernel.defconfig = if isAarch64 then "bcmrpi3_defconfig" else "bcm2709_defconfig";
  wip.kernel.structuredConfig =
    with lib.kernel;
    let
      inherit (config.wip.kernel) features;
    in
    lib.mkMerge [
      {
        IKCONFIG = no;
        LOCALVERSION = freeform ''""'';
      }
      {
        ARCH_BCM2835 = yes;
        MAILBOX = yes;
        BCM2835_MBOX = yes;
        RASPBERRYPI_FIRMWARE = yes;
        GPIO_PL061 = yes;
      }
      {
        I2C_BCM2708 = yes;
        I2C_BCM2835 = yes;
        SPI_BCM2835 = yes;
        SPI_BCM2835AUX = yes;
        PWM_BCM2835 = yes;
      }
      (lib.mkIf features.serial {
        SERIAL_8250 = yes;
        SERIAL_8250_CONSOLE = yes;
        SERIAL_8250_EXTENDED = yes;
        SERIAL_8250_SHARE_IRQ = yes;
        SERIAL_8250_BCM2835AUX = yes;

        SERIAL_AMBA_PL011 = yes;
        SERIAL_AMBA_PL011_CONSOLE = yes;

        SERIAL_DEV_BUS = yes;
      })
    ]
  ;
}
