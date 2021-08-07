{ lib
, stdenv
, runCommandNoCC
, writeShellScript
, initramfs ? null
, linux
, hostPlatform
, buildPlatform
}:

# Paths:
#  - https://github.com/linux-3ds/firm_linux_loader/blob/4098b022833bb794383cbf269d6e39a887fc3354/common/linux_config.h#L8-L11

let
  inherit (stdenv.hostPlatform.linux-kernel) target;
  inherit (stdenv.hostPlatform) qemuArch;
  DTB = stdenv.hostPlatform.linux-kernel.DTB or false;
  isCross = hostPlatform == buildPlatform;

  run = writeShellScript "run" ''
#!/usr/bin/env bash

set -e
set -u
PS4=" $ "

self="''${BASH_SOURCE[0]%/*}"

cmdline=(
    console=ttyS0
    #init=/bin/sh
)

args=(
    # Always assume "bring your own QEMU".
    # This makes it easier to run cross or native from a foreign arch.
    qemu-system-${qemuArch}

	-m 512
	${lib.optionalString isCross "--enable-kvm -cpu host"}
    ${lib.optionalString stdenv.isAarch64 "-machine virt"}

	#-display none
	-kernel $self/${target}
	-initrd $self/initramfs
	-append "''${cmdline[*]}"
    -serial mon:stdio
    #-serial stdio
    "$@"
)

set -x
exec "''${args[@]}"
  '';
in
runCommandNoCC "output" { } ''
  mkdir -p $out
  cp -vt $out \
    ${linux}/${target}

  ${lib.optionalString DTB ''
    # There might not be any DTBs to install; on ARM the DTB files
    # are built only if the proper ARCH_VENDOR config is set.
    if [ -e ${linux}/dtbs ]; then
      cp -r ${linux}/dtbs $out/dtbs
    else
      echo "Warning: no dtbs built on hostPlatform with DTB"
    fi
  ''}

  ${lib.optionalString (initramfs != null)
    "cp -v ${initramfs} $out/initramfs"
  }
  ln -s ${run} $out/run
''
