{ lib
/** Any (recent enough) mainline linux */
, linux
}:

{ name, list }:

linux.overrideAttrs(attrs: {
  inherit name;
  buildPhase = ''
    make -C source/usr gen_init_cpio
  '';
  installPhase = ''
    (cd source
    usr/gen_initramfs.sh -o "$out" "${list}"
    )
  '';
  fixupPhase = "";
})
