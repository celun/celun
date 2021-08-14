{ lib, pkgs, ... }:

let
  inherit (pkgs) writeTextDir;
in
{
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

  wip.stage-1.contents = {
    "/etc/issue" = writeTextDir "/etc/issue" ''
                                   dP oo          
                                   88             
      .d8888b. 88d8b.d8b. .d8888b. 88 dP dP.  .dP 
      Y8ooooo. 88'`88'`88 88'  `88 88 88  `8bd8'  
            88 88  88  88 88.  .88 88 88  .d88b.  
      `88888P' dP  dP  dP `88888P' dP dP dP'  `dP 

        +----------------------------------+
        | Tip of the day                   |
        | ==============                   |
        | Login with root and no password. |
        +----------------------------------+

    '';

    "/etc/splash.png" = pkgs.runCommandNoCC "splash" { } ''
      mkdir -p $out/etc
      cp ${../../artwork/splash.png} $out/etc/splash.png
    '';

    _default = pkgs.callPackage ./wip-initramfs.nix { };
  };

  #wip.stage-1.compression = "xz";
  #wip.stage-1.buildInKernel = true;
}
