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
    concatStringsSep
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
  inherit (stdenv.hostPlatform.linux-kernel) target;
  DTB = stdenv.hostPlatform.linux-kernel.DTB or false;

  inherit (config.wip.stage-1.output) initramfs;
  # FIXME kernel option, which by default uses configurableLinux
  # inherit (config.wip.system???) kernel;
  kernel = pkgs.celun.configurableLinux {
    inherit (config.wip.kernel) defconfig structuredConfig;
    inherit (config.wip.kernel.package) src version;
  };

  cfg = config.device.qemu;
in
{
  options = {
    device.qemu = {
      qemuArch = mkOption {
        type = types.str;
        default = qemuArch;
        description = ''
          Suffix for `qemu-system` for the current device.

          The default should be auto-detected and good.
        '';
      };

      qemuOptions = mkOption {
        type = with types; listOf str;
        internal = true;
      };

      kernelCmdline = mkOption {
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

  config = {
    build.default = cfg.output;
    device.qemu = {
      qemuOptions = [
        "-m ${toString cfg.memorySize}"
        "-kernel $self/${target}"
        "-initrd $self/initramfs"
        ''-append "''${cmdline[*]}"''
        "-serial mon:stdio"
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
          ${concatStringsSep "\n" cfg.kernelCmdline}
        )

        args=(
            # Always assume "bring your own QEMU".
            # This makes it easier to run cross or native from a foreign arch.
            # Also allows using the output on foreign systems without Nix.
            qemu-system-${qemuArch}

            ${concatStringsSep "\n" cfg.qemuOptions}

            "$@"
        )

        ${cfg.qemuAdditionalConfiguration}

        set -x
        exec "''${args[@]}"
      '';

      output = runCommandNoCC "output" {
        passthru = {
          inherit kernel;
        };
      } ''
        mkdir -p $out
        cp -vt $out \
          ${kernel}/${target}

        ${optionalString DTB ''
          # There might not be any DTBs to install; on ARM the DTB files
          # are built only if the proper ARCH_VENDOR config is set.
          if [ -e ${kernel}/dtbs ]; then
            cp -r ${kernel}/dtbs $out/dtbs
          else
            echo "Warning: no dtbs built on hostPlatform with DTB"
          fi
        ''}

        ${optionalString (initramfs != null)
          "cp -v ${initramfs} $out/initramfs"
        }
        cp -v ${cfg.runScript} $out/run
      '';
    };
  };
}
