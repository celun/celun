{ runCommandNoCC
, writeScript
, writeText
, nukeReferences
, pkgsStatic }:

#
# This is a cheaty initramfs.
# Let's use pkgsStatic so we don't have to actually really care about the
# nix store dependencies.
#

let
  issue = writeText "etc-issue" ''
    ${""/*       12345678901234567890123456789012345678901234567890 */}
    ${""/* 01 */}                                                  ${""/**/}
    ${""/* 02 */}              ::::.    ':::::     ::::'           ${""/**/}
    ${""/* 03 */}              ':::::    ':::::.  ::::'            ${""/**/}
    ${""/* 04 */}                :::::     '::::.:::::             ${""/**/}
    ${""/* 05 */}          .......:::::..... ::::::::              ${""/**/}
    ${""/* 06 */}         ::::::::::::::::::. ::::::    ::::.      ${""/**/}
    ${""/* 07 */}        ::::::::::::::::::::: :::::.  .::::'      ${""/**/}
    ${""/* 08 */}               .....           ::::' :::::'       ${""/**/}
    ${""/* 09 */}              :::::            '::' :::::'        ${""/**/}
    ${""/* 10 */}     ........:::::               ' :::::::::::.   ${""/**/}
    ${""/* 11 */}    :::::::::::::                 :::::::::::::   ${""/**/}
    ${""/* 12 */}     ::::::::::: ..              :::::            ${""/**/}
    ${""/* 13 */}         .::::: .:::            :::::             ${""/**/}
    ${""/* 14 */}        .:::::  :::::          ${"'''''"}              ${""/**/}
    ${""/* 15 */}        :::::   ':::::.  :::::::::::::::::::'     ${""/**/}
    ${""/* 16 */}         :::     ::::::. ':::::::::::::::::'      ${""/**/}
    ${""/* 17 */}                .:::::::: '::::::::::             ${""/**/}
    ${""/* 18 */}               .::::${"''"}::::.     '::::.            ${""/**/}
    ${""/* 19 */}              .::::'   ::::.     '::::.           ${""/**/}
    ${""/* 20 */}             .::::      ::::      '::::.          ${""/**/}
    ${""/* 21 */}                                                  ${""/**/}
    ${""/* 22 */}           (This is not actually NixOS)           ${""/**/}
    ${""/* 23 */}                                                  ${""/**/}
    ${""/* 24 */}                                                  ${""/**/}
    ${""/* 25 */}       +----------------------------------+       ${""/**/}
    ${""/* 26 */}       | Tip of the day                   |       ${""/**/}
    ${""/* 27 */}       | ==============                   |       ${""/**/}
    ${""/* 28 */}       | Login with root and no password. |       ${""/**/}
    ${""/* 29 */}       +----------------------------------+       ${""/**/}
    ${""/* 30 */}                                                  ${""/**/}
  '';

  # https://git.busybox.net/busybox/tree/examples/inittab
  inittab = writeText "inittab" ''
    console::respawn:/bin/getty 0 console

    ::sysinit:/bin/ply-image --clear=0x0000ff
    ::wait:/bin/ply-image --clear=0xff0000
    ::once:/bin/ply-image --clear=0x009900

    ::restart:/bin/init
    ::ctrlaltdel:/bin/poweroff
  '';

  passwd = writeText "passwd" ''
    root::0:0:root:/root:/bin/sh
  '';

  init = writeScript "init" ''
    #!/bin/sh

    echo
    echo "::"
    echo ":: Setting up system"
    echo "::"
    echo

    export PATH="/bin/"
    (
      PS4=" $ "
      set -x
      mount -t proc proc /proc
      mount -t sysfs sys /sys
      mount -t devtmpfs devtmpfs /dev
    )

    if [ -e /sys/class/graphics/fb0 ]; then
      cat /sys/class/graphics/fb0/modes > /sys/class/graphics/fb0/mode
      ply-image --clear=0xff00ff
    fi

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

    exec /linuxrc
  '';

  # Let's use a statically built busybox!
  inherit (pkgsStatic) busybox ply-image;
in

runCommandNoCC "minimal-initramfs" {
  nativeBuildInputs = [
    nukeReferences
  ];
} ''
  mkdir -p $out

  cp -vr ${busybox}/* $out
  chmod -R +w $out
  rm $out/bin/init
  rm $out/default.script
  cp -vrt $out/bin/ ${ply-image}/bin/*

  cp -vr ${init} $out/init

  mkdir -p $out/etc

  cp ${inittab} $out/etc/inittab
  cp ${issue} $out/etc/issue
  cp ${passwd} $out/etc/passwd

  echo ":: Nuking references"
  chmod -R +w $out
  nuke-refs $out/* $out/*/*
  (
  cd $out
  find -type d -printf 'dir   /%h/%f 755 0 0 \n'
  find -type f -printf 'file  /%h/%f '"$out/"'%h/%f %m  0 0 \n'
  find -type l -printf 'slink /%h/%f %l %m  0 0 \n'
  ) > ./files.list
  mv files.list $out/
  sed -i -e 's;/\./;/;g' $out/files.list

  # Add more files to the initramfs
  cat >> $out/files.list <<EOF

  dir /proc 755 0 0
  dir /sys 755 0 0
  dir /mnt 755 0 0
  dir /root 755 0 0

  dir /dev 755 0 0
  nod /dev/console 644 0 0 c 5 1
  nod /dev/loop0   644 0 0 b 7 0
  EOF
''
