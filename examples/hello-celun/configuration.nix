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
      printk = true;
      serial = true;

      # VT means more than consoles on a VT.
      vt = true;
      graphics = true;
    };
  };

  #wip.stage-1.compression = "xz";
  #wip.stage-1.buildInKernel = true;
}
