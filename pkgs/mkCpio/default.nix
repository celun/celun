{ lib
, runCommandNoCC
/** Any (recent enough) mainline linux */
, linux
, runtimeShell
}:

let
  borrowedMkCpio = linux.overrideAttrs(attrs: {
    outputs = [ "out" ];
    buildPhase = ''
      make -C source/usr gen_init_cpio
    '';
    installPhase = ''
      mkdir -p $out
      mkdir -p $out/usr
      cp -rvt $out/usr source/usr/{gen_init_cpio,gen_initramfs.sh,default_cpio_list}

      ${lib.concatMapStringsSep "\n" (tool: ''
        tool=${tool}
        wrapper=$out/bin/$(basename $tool)
        mkdir -p $out/bin
        cat <<EOF > $wrapper
        #!${runtimeShell}
        cd $out
        exec ./$tool "\$@"
        EOF
        chmod +x $wrapper
      '') [ "usr/gen_initramfs.sh" ]}
    '';
    fixupPhase = "";
  });
in

{ name, list }:
runCommandNoCC name {
  nativeBuildInputs = [
    borrowedMkCpio
  ];
  passthru = {
    inherit list linux;
  };
} ''
  printf ':: Building initramfs\n'
  printf '   Using: %s\n' "${list}"
  gen_initramfs.sh -o "$out" "${list}"
''
