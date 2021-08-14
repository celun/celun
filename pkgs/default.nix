final: super:

let
  inherit (final) callPackage;
in
{
  mkCpio = callPackage ./mkCpio {
    linux = final.linux_5_10;
  };

  mkExtraUtils = callPackage  ./mkExtraUtils { };

  ply-image = callPackage ./ply-image { };

  smolix = final.lib.makeScope final.pkgs.newScope (self:
    let
      inherit (self) callPackage;
    in
    {
      configurableLinux = callPackage ./configurable-linux {
        kernelPatches = with final.kernelPatches; [
          bridge_stp_helper
          request_key_helper
        ];
      };
      minimal-initramfs = callPackage ./minimal-initramfs { };
      output = callPackage ./output { };
    }
  );
}
