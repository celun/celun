{ config, lib, pkgs, ... }:

/*

For now the initramfs for the hello-celun example system is entirely bespoke.

At some point a *busybox init stage-1* module will be added, and this will be
changed to use that module.

*/

let
  inherit (lib)
    mkOption
    types
  ;

  inherit (pkgs)
    runCommandNoCC
    writeScript
    writeScriptBin
    writeText
    writeTextFile
    writeTextDir

    mkExtraUtils

    busybox
    ply-image
    glibc
  ;

  writeScriptDir = name: text: writeTextFile {inherit name text; executable = true; destination = "${name}";};

  cfg = config.examples.hello-celun;

  # Alias to `output.extraUtils` for internal usage.
  inherit (cfg.output) extraUtils;
in
{

  options.examples.hello-celun = {
    extraUtils = {
      packages = mkOption {
        # TODO: submodule instead of `attrs` when we extract this
        type = with types; listOf (oneOf [package attrs]);
      };
    };
    output = {
      extraUtils = mkOption {
        type = types.package;
        internal = true;
      };
    };
  };

  config = {
    wip.stage-1.enable = true;
    wip.stage-1.archive.contents = {
      "/etc/issue" = writeTextDir "/etc/issue" ''

                         _
                 ___ ___| |_   _ _ __
                / __/ _ \\ | | | | '_ \\
               | (_|  __/ | |_| | | | |
                \\___\\___|_|\\__,_|_| |_|

          +----------------------------------+
          | Tip of the day                   |
          | ==============                   |
          | Login with root and no password. |
          +----------------------------------+

      '';

      "/etc/splash.png" = runCommandNoCC "splash" { } ''
        mkdir -p $out/etc
        cp ${../../artwork/splash.png} $out/etc/splash.png
      '';

      # https://git.busybox.net/busybox/tree/examples/inittab
      "/etc/inittab" = writeTextDir "/etc/inittab" ''
        # Allow root login on the `console=` param.
        # (Or when missing, a default console may be launched on e.g. serial)
        # No console will be available on other valid consoles.
        console::respawn:${extraUtils}/bin/getty -l ${extraUtils}/bin/login 0 console

        # Launch all setup tasks
        ::sysinit:${extraUtils}/bin/sh -l -c ${extraUtils}/bin/mount-basic-mounts
        ::wait:${extraUtils}/bin/sh -l -c ${extraUtils}/bin/network-setup
        ::wait:${extraUtils}/bin/sh -l -c ${extraUtils}/bin/logging-setup

        # Splash text is shown when the system is ready.
        ::once:${extraUtils}/bin/ply-image --clear=0xffffff /etc/splash.png

        ::restart:/bin/init
        ::ctrlaltdel:/bin/poweroff
      '';

      "/etc/passwd" = writeTextDir "/etc/passwd" ''
        root::0:0:root:/root:${extraUtils}/bin/sh
      '';

      "/etc/profile" = writeScriptDir "/etc/profile" ''
        export LD_LIBRARY_PATH="${extraUtils}/lib"
        export PATH="${extraUtils}/bin"
      '';

      # Place init under /etc/ to make / prettier
      init = writeScriptDir "/init" ''
        #!${extraUtils}/bin/sh

        echo
        echo "::"
        echo ":: Launching busybox linuxrc"
        echo "::"
        echo

        . /etc/profile

        exec linuxrc
      '';

      extraUtils = runCommandNoCC "hello-celun--initramfs-extraUtils" {
        passthru = {
          inherit extraUtils;
        };
      } ''
        mkdir -p $out/${builtins.storeDir}
        cp -prv ${extraUtils} $out/${builtins.storeDir}
      '';

      # POSIX requires /bin/sh
      "/bin/sh" = runCommandNoCC "hello-celun--initramfs-extraUtils-bin-sh" {} ''
        mkdir -p $out/bin
        ln -s ${extraUtils}/bin/sh $out/bin/sh
      '';
    };

    examples.hello-celun.extraUtils.packages = [
      {
        package = busybox;
        extraCommand = ''
          (cd $out/bin/; ln -s busybox linuxrc)
        '';
      }

      {
        package = ply-image;
        extraCommand = ''
          cp -f ${glibc.out}/lib/libpthread.so.0 $out/lib/
        '';
      }

      (writeScriptBin "mount-basic-mounts" ''
        #!/bin/sh

        PS4=" $ "
        set -x
        mkdir -p /proc /sys /dev
        mount -t proc proc /proc
        mount -t sysfs sys /sys
        mount -t devtmpfs devtmpfs /dev
      '')

      (writeScriptBin "network-setup" ''
        #!/bin/sh

        PS4=" $ "
        set -x
        hostname celun-demo
        ip link set lo up
      '')

      (writeScriptBin "logging-setup" ''
        #!/bin/sh

        if [ -e /proc/sys/kernel/printk ]; then
          (
            PS4=" $ "
            set -x
            echo 5 > /proc/sys/kernel/printk
          )
        fi
      '')
    ];

    examples.hello-celun.output = {
      extraUtils = mkExtraUtils {
        name = "celun-hello--extra-utils";
        inherit (cfg.extraUtils) packages;
      };
    };
  };

}
