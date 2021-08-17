{ lib, pkgs, ... }:

{
  imports = [
    ./initramfs.nix
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
    };
  };

  #wip.stage-1.compression = "xz";
  #wip.stage-1.buildInKernel = true;
}
