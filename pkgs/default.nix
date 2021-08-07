final: super:

let
  inherit (final) callPackage;
  # TODO make a scoped package set for its own self
  self = final.shenanigans;
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
    minimal-initramfs = callPackage ./minimal-initramfs { };
    minimal-initramfs-cpio = final.buildPackages.mkCpio {
      name = self.minimal-initramfs.name + ".cpio.gz";
      list = ''"${self.minimal-initramfs}/files.list"'';
    };
  };
}
