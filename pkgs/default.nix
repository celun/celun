final: super:

let
  inherit (final) callPackage;
in
{
  mkCpio = callPackage ./mkCpio {
    linux = final.linux_5_10;
  };

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
        #initramfs = ''"${self.minimal-initramfs-cpio}"'';
        #initramfs = ''"${self.minimal-initramfs-cpio-xz}"'';
      };
      minimal-initramfs = callPackage ./minimal-initramfs { };
      minimal-initramfs-cpio = final.buildPackages.mkCpio {
        name = self.minimal-initramfs.name + ".cpio.gz";
        list = ''"${self.minimal-initramfs}/files.list"'';
      };
      minimal-initramfs-cpio-xz = final.runCommandNoCC "initramfs.cpio.xz" {
        nativeBuildInputx = [
          final.buildPackages.xz
        ];
      } ''
        cat ${self.minimal-initramfs-cpio} | xz -9 -e --check=crc32 > $out
      '';
      output = callPackage ./output {
        initramfs = self.minimal-initramfs-cpio;
      };
    }
  );
}
