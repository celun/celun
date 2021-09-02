{ config, lib, pkgs, ... }:

/*

This applies to the full Raspberry Pi 1 and Raspberry Pi 0 family.

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
in
{
  imports = [
    ../shared.nix
  ];

  hardware = {
    cpu = "generic-armv6l";
  };

  boot.cmdline = lib.mkAfter [
    "earlycon=earlycon=pl011,0xfe201000"
    "console=serial0,115200"
  ];

  # overrideAttrs doesn't work on kernel derivations ¯\_(ツ)_/¯
  # We're (ab)using the mkDerivation here to satisfy the package type.
  wip.kernel.package = pkgs.stdenv.mkDerivation {
    inherit (pkgs.linux_rpi1) src;
    version = head (splitString "-" pkgs.linux_rpi1.version);
  };
  wip.kernel.defconfig = pkgs.buildPackages.runCommandNoCC "defconfig" {
    inherit (config.wip.kernel.package) src;
  } ''
    sed -e '/=m$/d' \
      $src/arch/arm/configs/bcmrpi_defconfig > $out
  '';
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
        I2C_BCM2708 = yes;
        I2C_BCM2835 = yes;
        SPI_BCM2835 = yes;
        SPI_BCM2835AUX = yes;

        PWM = yes;
        PWM_BCM2835 = yes;
      }
      (lib.mkIf features.serial {
        SERIAL_AMBA_PL011 = yes;
        SERIAL_AMBA_PL011_CONSOLE = yes;

        SERIAL_DEV_BUS = yes;
      })
    ]
  ;
}
