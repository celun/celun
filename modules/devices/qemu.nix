{ config, lib, pkgs, ... }:

/*

This is the shared implementation of the QEMU systems.

Currently this is used to output a script used to run a non-provided QEMU
instance.

By design it is not providing a QEMU binary from the store in the script, as
this would prevent using the same script on different systems. Furthermore, the
output should be portable, and not rely on the Nix store. The output should be
usable even if Nix is not available.

In turn, this should make using a docker container to build this output usable.

*/

let
  inherit (lib)
    concatMapStringsSep
    concatStringsSep
    escapeShellArg
    optional
    optionals
    optionalString
    mkOption
    types
  ;
  inherit (pkgs)
    runCommandNoCC
    stdenv
    writeScript
  ;
  inherit (stdenv) hostPlatform isAarch64 isx86_32 isx86_64;
  isx86 = isx86_32 || isx86_64;
  inherit (stdenv.hostPlatform) qemuArch;
  target =
    if stdenv.hostPlatform.linux-kernel.target == "uImage"
    then "zImage" # We're not using uImage.
    else stdenv.hostPlatform.linux-kernel.target
  ;
  DTB = stdenv.hostPlatform.linux-kernel.DTB or false;

  kernel = config.wip.kernel.output;
  initramfs = config.build.initramfs or null;

  cfg = config.device.config.qemu;
in
{
  options = {
    device.config.qemu = {
      enable = lib.mkEnableOption "building for QEMU";
      qemuArch = mkOption {
        type = types.str;
        default = qemuArch;
        description = ''
          Suffix for `qemu-system` for the current device.

          The default should be auto-detected and good.
        '';
      };

      availableBootModes = mkOption {
        type = with types; listOf str;
        internal = true;
      };

      bootMode = mkOption {
        default = "direct";
        type = types.enum cfg.availableBootModes;
      };

      qemuOptions = mkOption {
        type = with types; listOf str;
        internal = true;
      };

      qemuAdditionalConfiguration = mkOption {
        type = types.lines;
        internal = true;
      };

      memorySize = mkOption {
        type = types.int;
        default = 512;
        internal = true;
      };

      runScript = mkOption {
        type = types.package;
        internal = true;
      };

      output = mkOption {
        type = types.package;
        internal = true;
      };
    };
  };

  config = lib.mkIf (cfg.enable) {
    build.default = cfg.output;
    wip.uefi.enable = cfg.bootMode == "uefi";
    device.config.qemu = {
      availableBootModes = [
        "direct"
        "drive"
      ];

      qemuOptions = [
        "-m ${toString cfg.memorySize}"
        "-serial mon:stdio"
      ] ++ optionals (cfg.bootMode == "direct") (
        [
        "-kernel $self/${target}"
        ''-append "''${cmdline[*]}"''
        ] ++ (optional (initramfs != null) "-initrd $self/initramfs")
      )++ optionals (cfg.bootMode == "uefi") [
        ''-bios  "$self/OVMF.fd"''
        ''-drive "file=$self/disk-image.img,format=raw,snapshot=on"''
      ] ++ optionals (cfg.bootMode == "drive") [
        ''-drive "file=$self/disk-image.img,format=raw,snapshot=on"''
      ];

      # TODO: add option to disallow virt? disallow `cpu host`?
      qemuAdditionalConfiguration = ''
        if [[ "$(uname -m)" == "${hostPlatform.uname.processor}" ]]; then
          args+=(
            --enable-kvm -cpu host
          )
        fi
      '';

      runScript = writeScript "run" ''
        #!/usr/bin/env bash

        set -e
        set -u
        PS4=" $ "

        self="''${BASH_SOURCE[0]%/*}"

        cmdline=(
          ${concatMapStringsSep "\n  " escapeShellArg config.boot.cmdline}
        )

        args=(
          # Always assume "bring your own QEMU".
          # This makes it easier to run cross or native from a foreign arch.
          # Also allows using the output on foreign systems without Nix.
          qemu-system-${qemuArch}

          ${concatStringsSep "\n  " cfg.qemuOptions}

          "$@"
        )

        ${cfg.qemuAdditionalConfiguration}

        set -x
        exec "''${args[@]}"
      '';

      output = runCommandNoCC "${config.device.nameForDerivation}-build" {
        passthru = {
          inherit kernel;
        };
      } ''
        mkdir -p $out

        ${optionalString DTB ''
          # There might not be any DTBs to install; on ARM the DTB files
          # are built only if the proper ARCH_VENDOR config is set.
          if [ -e ${kernel}/dtbs ]; then
            cp -r ${kernel}/dtbs $out/dtbs
          else
            echo "Warning: no dtbs built on hostPlatform with DTB"
          fi
        ''}

        ${optionalString (cfg.bootMode == "direct") ''
        cp -vt $out \
          ${kernel}/${target}
        ${optionalString (initramfs != null)
          "cp -v ${initramfs} $out/initramfs"
        }
        ''}

        ${optionalString (cfg.bootMode == "uefi") ''
          cp ${pkgs.OVMF.fd}/FV/OVMF.fd $out/OVMF.fd
          cp ${config.build.disk-image} $out/disk-image.img
        ''}

        ${optionalString (cfg.bootMode == "drive") ''
          cp ${config.build.disk-image} $out/disk-image.img
        ''}

        cp -v ${cfg.runScript} $out/run
      '';
    };
  };
}
