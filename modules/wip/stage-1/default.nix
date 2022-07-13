{ config, lib, pkgs, ... }:

let
  inherit (lib)
    mkIf
    mkMerge
    mkOption
    mkRenamedOptionModule
    types
  ;

  cfg = config.wip.stage-1;

  compressed = {
    none = cfg.cpio;
    gzip = pkgs.runCommandNoCC "${cfg.cpio.name}.gz" {
      inherit (cfg) cpio;
    } ''
      cat $cpio | gzip -8 > $out
    '';
    xz = pkgs.runCommandNoCC "${cfg.cpio.name}.xz" {
      nativeBuildInputs = [
        pkgs.buildPackages.xz
      ];
      inherit (cfg) cpio;
    } ''
      cat $cpio | xz -9 -e --check=crc32 > $out
    '';
  };
in
{
  imports = [
    (mkRenamedOptionModule [ "wip" "stage-1" "contents" ] [ "wip" "stage-1" "archive" "contents" ])
    (mkRenamedOptionModule [ "wip" "stage-1" "additionalListEntries" ] [ "wip" "stage-1" "archive" "additionalListEntries" ])
  ];
  options.wip.stage-1 = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to enable the WIP stage-1 initramfs module or not.
      '';
    };

    cpio = mkOption {
      type = types.package;
      internal = true;
      description = ''
        While the modules system usage is preferrable, users can override the
        cpio archive in use for the initramfs here.
      '';
    };

    output = {
      initramfs = mkOption {
        type = types.package;
        internal = true;
      };
    };

    compression = mkOption {
      default = "none";
      type = types.enum (builtins.attrNames compressed);
      description = ''
        Compression scheme used for the stage-1 image.

        > **Tip:** When bundling the initramfs in the kernel, leave compression
        > set to none, and rely on the kernel's own compression if available.
      '';
    };

    buildInKernel = mkOption {
      default = false;
      type = types.bool;
      description = ''
        Build the initramfs in the kernel image.

        > **Tip:** Leave this set to false for development purposes, unless you
        > like compiling a full kernel every builds.
      '';
    };

    archive = config.wip.cpio.lib.mkOption {
      description = ''
        Contents of the initramfs archive.
      '';
    };
  };

  config = mkIf cfg.enable {
    # Select the initramfs in use
    wip.stage-1.output.initramfs = compressed.${cfg.compression};

    wip.stage-1.cpio = cfg.archive.output;

    # Alias the initramfs image for end-users
    # XXX: drop this option
    build.initramfs = cfg.output.initramfs;

    # Ensure the configurable kernel can use the initramfs.
    wip.kernel = {
      structuredConfig = with lib.kernel; mkMerge [
        (mkIf cfg.buildInKernel {
          INITRAMFS_SOURCE = freeform ''"${cfg.output.initramfs}"'';
        })
        (mkIf (cfg.compression != "none") {
          "RD_${lib.toUpper cfg.compression}" = yes;
        })
      ];
    };
  };
}
