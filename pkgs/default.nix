final: super:

let
  inherit (final) callPackage;
in
{
  mkCpio = callPackage ./mkCpio {
    linux = final.linux_5_10;
  };

  # Our "project"
  shenanigans = {
    linux = callPackage ./linux {
      base = final.linux_5_13;
      kernelPatches = with final.kernelPatches; [
        bridge_stp_helper
        request_key_helper
      ];
    };
  };
}
