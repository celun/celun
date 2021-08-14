{ lib
, runCommandNoCC
, writeScript
, writeText
, mkExtraUtils
, nukeReferences

# Additional software
, busybox
, ply-image
, glibc
}:

let
  # https://git.busybox.net/busybox/tree/examples/inittab
  inittab = writeText "inittab" ''
    console::respawn:${extraUtils}/bin/getty -l ${extraUtils}/bin/login 0 console

    #::sysinit:${extraUtils}/bin/ply-image --clear=0x0000ff # lime
    #::wait:${extraUtils}/bin/ply-image --clear=0xff0000    # red
    #::once:${extraUtils}/bin/ply-image --clear=0x009900    # green means go

    ::restart:/bin/init
    ::ctrlaltdel:/bin/poweroff
  '';

  passwd = writeText "passwd" ''
    root::0:0:root:/root:${extraUtils}/bin/sh
  '';

  profile = writeText "profile" ''
    export LD_LIBRARY_PATH="${extraUtils}/lib"
    export PATH="${extraUtils}/bin"
  '';

  init = writeScript "init" ''
    #!${extraUtils}/bin/sh

    echo
    echo "::"
    echo ":: Setting up system"
    echo "::"
    echo

    . /etc/profile

    (
      PS4=" $ "
      set -x
      mkdir -p /proc /sys /dev
      mount -t proc proc /proc
      mount -t sysfs sys /sys
      mount -t devtmpfs devtmpfs /dev
    )

    (
    for i in  1 2 3 4 5 6 7 8 9 a b c d e f; do
      ply-image --clear=0x$i$i$i$i$i$i &
      # The background and wait helps on slower platforms.
      sleep 0.01
      wait
    done
    ply-image --clear=0xffffff /etc/splash.png
    ) &

    (
      PS4=" $ "
      set -x
      hostname smolix-demo
      ip link set lo up
    )

    if [ -e /proc/sys/kernel/printk ]; then
      (
        PS4=" $ "
        set -x
        echo 5 > /proc/sys/kernel/printk
      )
    fi

    echo
    echo "::"
    echo ":: Launching busybox linuxrc"
    echo "::"
    echo

    wait

    exec linuxrc
  '';

  extraUtils = mkExtraUtils {
    name = "smolix-hello--extra-utils";
    packages = [
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
    ]
    ;
  };
in

runCommandNoCC "smolix-hello--initramfs" {
  nativeBuildInputs = [
    nukeReferences
  ];
  passthru = {
    inherit extraUtils;
  };
} ''
  mkdir -p $out

  mkdir -p $out/${builtins.storeDir}
  cp -prv ${extraUtils} $out/${builtins.storeDir}

  mkdir -p $out/etc

  # Copy init under /etc/ to make / prettier
  cp -vr ${init} $out/etc/init

  cp ${inittab} $out/etc/inittab
  cp ${passwd} $out/etc/passwd
  cp ${profile} $out/etc/profile

  # POSIX requires /bin/sh
  mkdir -p $out/bin
  ln -s ${extraUtils}/bin/sh $out/bin/sh
''
