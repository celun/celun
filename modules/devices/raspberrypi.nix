{ config, lib, pkgs, ... }:

/*

This is the shared implementation of common Raspberry Pi specific details.

*/

let
  inherit (lib)
    concatStringsSep
    optionalString
    mkOption
    types
  ;
  inherit (pkgs)
    stdenv
  ;
  inherit (stdenv) hostPlatform isAarch64;
  inherit (stdenv.hostPlatform.linux-kernel) target;
  kernel = config.wip.kernel.output;
  inherit (config.wip.stage-1.output) initramfs;

  cfg = config.device.config.raspberrypi;

  configTxt = pkgs.writeText "config.txt" ''
    [all]
    kernel=kernel.img
    initramfs initramfs.img followkernel

    disable_overscan=1
    enable_uart=1
    uart_2ndstage=1
    avoid_warnings=1

    ${optionalString isAarch64 ''
    [all]
    arm_64bit=1

    [pi4]
    enable_gic=1
    armstub=armstub8-gic.bin
    ''}

    [all]
    ${cfg.configTxt}
  '';

  cmdlineTxt = pkgs.writeText "cmdline.txt" ''
    ${concatStringsSep " " config.boot.cmdline}
  '';
in
{
  options = {
    device.config.raspberrypi = {
      enable = lib.mkEnableOption "building for Raspberry Pis";
      output = mkOption {
        type = types.package;
        internal = true;
      };
      configTxt = mkOption {
        type = types.lines;
        default = "";
        description = ''
          Additional lines to append to `config.txt`.
        '';
      };
    };
  };

  config = lib.mkIf (cfg.enable) {
    build.default = cfg.output;
    build.disk-image = cfg.output;
    device.config.raspberrypi = {
      output = (pkgs.celun.image-builder.evaluateDiskImage {
        config =
          { config, ... }:

          let inherit (config) helpers; in
          {
            partitioningScheme = "gpt";
            gpt.hybridMBR = [ "1" "EE" ];

            # See the `partitionType` comment.
            additionalCommands = ''
              # Change the partition type to 0x0c; sgdisk will not do the right thing here.
              echo '000001c2: 0c' | ${pkgs.buildPackages.xxd}/bin/xxd -r - $img
            '';
            partitions = [
              {
                name = "raspberrypi-boot";
                partitionLabel = "$CELUN-BOOT";

                # The hybridMBR scheme divides gdisk internal codes by 0x100.
                # gdisk internal type "0x0C00", divided by 0x100 gives 0x0C.
                # The Raspberry Pi requires the partition to be 0x0C.
                # https://sourceforge.net/p/gptfdisk/code/ci/1ae2f1769fec6311810a0981669d33b9b20a45e6/tree/parttypes.cc#l89
                partitionType = "EBD0A0A2-B9E5-4433-87C0-68B6B72699C7";
                # But this doesn't actually work, it ends up with `0x07` because
                # this particular partition type UUID is re-used across different
                # types internal to sgdisk.
                # See `additionalCommands` for the workaround.

                filesystem = {
                  filesystem = "fat32";
                  label = "$CELUN-BOOT";
                  extraPadding = helpers.size.MiB 10;
                  populateCommands = ''
                    (
                      target="$PWD"
                      cd ${pkgs.raspberrypifw}/share/raspberrypi/boot
                      cp -v *.dtb "$target/"
                      cp -v bootcode.bin fixup*.dat start*.elf "$target/"
                    )

                    cp ${configTxt} config.txt
                    cp ${cmdlineTxt} cmdline.txt
                    cp ${initramfs} initramfs.img
                    cp ${kernel}/${target} kernel.img

                    if (( $(cat cmdline.txt | wc -l) != 1 )); then
                      echo
                      echo "ERROR: cmdline.txt contains more than one line."
                      echo "ABORTING"
                      echo "See: content of '${cmdlineTxt}'..."
                      echo
                      exit 1
                    fi

                    # There might not be any DTBs to install; on ARM the DTB files
                    # are built only if the proper ARCH_VENDOR config is set.
                    if [ -e ${kernel}/dtbs ]; then
                      (
                      shopt -s globstar
                      cp -fvr ${kernel}/dtbs/**/*.dtb ./
                      )
                    else
                      echo "Warning: no dtbs built on hostPlatform with DTB"
                    fi
                  '';
                };
              }
            ];
          }
        ;
      }).config.output;
    };
  };
}
