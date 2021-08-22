final: super:

let
  inherit (final) callPackage;
in
{
  make_ext4fs = callPackage ./make_ext4fs { };

  mkCpio = callPackage ./mkCpio {
    linux = final.linux_5_10;
  };

  mkExtraUtils = callPackage  ./mkExtraUtils { };

  ply-image = callPackage ./ply-image { };

  celun = final.lib.makeScope final.pkgs.newScope (self:
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

      image-builder = callPackage ./image-builder { };
    }
  );
}
