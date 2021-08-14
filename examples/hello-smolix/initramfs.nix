{ config, lib, pkgs, ... }:

/*

For now the initramfs for the hello-smolix example system is entirely bespoke.

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

  cfg = config.examples.hello-smolix;

  # Alias to `output.extraUtils` for internal usage.
  inherit (cfg.output) extraUtils;
in
{

  options.examples.hello-smolix = {
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
    wip.stage-1.contents = {
      "/etc/issue" = writeTextDir "/etc/issue" ''
                                     dP oo          
                                     88             
        .d8888b. 88d8b.d8b. .d8888b. 88 dP dP.  .dP 
        Y8ooooo. 88'`88'`88 88'  `88 88 88  `8bd8'  
              88 88  88  88 88.  .88 88 88  .d88b.  
        `88888P' dP  dP  dP `88888P' dP dP dP'  `dP 

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
        ::wait:${extraUtils}/bin/sh -l -c ${extraUtils}/bin/fade-to-white
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
      init = writeScriptDir "/etc/init" ''
        #!${extraUtils}/bin/sh

        echo
        echo "::"
        echo ":: Launching busybox linuxrc"
        echo "::"
        echo

        . /etc/profile

        exec linuxrc
      '';

      extraUtils = runCommandNoCC "hello-smolix--initramfs-extraUtils" {
        passthru = {
          inherit extraUtils;
        };
      } ''
        mkdir -p $out/${builtins.storeDir}
        cp -prv ${extraUtils} $out/${builtins.storeDir}
      '';

      # POSIX requires /bin/sh
      "/bin/sh" = runCommandNoCC "hello-smolix--initramfs-extraUtils-bin-sh" {} ''
        mkdir -p $out/bin
        ln -s ${extraUtils}/bin/sh $out/bin/sh
      '';
    };

    examples.hello-smolix.extraUtils.packages = [
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

      (writeScriptBin "fade-to-white" ''
        #!/bin/sh

        for i in  1 2 3 4 5 6 7 8 9 a b c d e f; do
          ply-image --clear=0x$i$i$i$i$i$i &
          # The background and wait helps on slower platforms.
          sleep 0.01
          wait
        done
      '')

      (writeScriptBin "network-setup" ''
        #!/bin/sh

        PS4=" $ "
        set -x
        hostname smolix-demo
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

    examples.hello-smolix.output = {
      extraUtils = mkExtraUtils {
        name = "smolix-hello--extra-utils";
        inherit (cfg.extraUtils) packages;
      };
    };
  };

}
