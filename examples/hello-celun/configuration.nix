{ lib, pkgs, ... }:

{
  imports = [
    ./initramfs.nix
  ];

  boot.cmdline = [
    "vt.global_cursor_default=0"
    "vt.default_red=0xFF,0xBC,0x4F,0xB4,0x56,0xBC,0x4F,0x00,0xA1,0xCF,0x84,0xCA,0x8D,0xB4,0x84,0x68"
    "vt.default_grn=0xFF,0x55,0xBA,0xBA,0x4D,0x4D,0xB3,0x00,0xA0,0x8F,0xB3,0xCA,0x88,0x93,0xA4,0x68"
    "vt.default_blu=0xFF,0x58,0x5F,0x58,0xC5,0xBD,0xC5,0x00,0xA8,0xBB,0xAB,0x97,0xBD,0xC7,0xC5,0x68"
  ];

  wip.kernel = {
    structuredConfig = with lib.kernel; {
      # No on-screen console, ever
      VT_CONSOLE = no;
      FRAMEBUFFER_CONSOLE = no;
    };
    features = {
      printk = lib.mkDefault true;
      serial = lib.mkDefault true;

      # VT means more than consoles on a VT.
      vt = lib.mkDefault true;
      graphics = lib.mkDefault true;
      logo = lib.mkDefault true;
    };
    logo = ./loading.png;
  };

  # Raspberry Pi specific configuration
  device.config = {
    raspberrypi = {
      configTxt = ''
          disable_splash=1
      '';
    };
  };

  wip.stage-1.compression = lib.mkDefault "xz";
}
