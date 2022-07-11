{ config, lib, pkgs, ... }:

{
  device = {
    name = "qemu/versatile-ARM9";
    config.qemu.enable = true;
  };

  hardware = {
    cpu = "generic-armv7l";
  };
  wip.kernel.defconfig = "multi_v7_defconfig";
  wip.kernel.structuredConfig =
    with lib.kernel;
    let
      inherit (config.wip.kernel) features;
    in
    lib.mkMerge [
      ### TODO: disable/enable kernel config according to features.
      (lib.mkIf (features.logo || features.vt || features.graphics) {
        DRM = yes;
        DRM_FBDEV_EMULATION = yes;
        DRM_VIRTIO_GPU = yes;

        # virtio gpu requires PCI
        PCI = yes;
        VIRTIO_MENU = yes;
        VIRTIO_PCI = yes;
        PCI_HOST_GENERIC = yes;
        VIRTIO_INPUT = yes;
      })
      {
        # No LPAE support in the virtual system.
        ARM_LPAE = no;
      }
    ]
  ;

  boot.cmdline = [
    "mem=${toString config.device.config.qemu.memorySize}M"
  ];
  device.config.qemu = {
    memorySize = lib.mkDefault 128;
    qemuOptions = [
      # highmem=off is needed when LPAE is not enabled in the kernel
      # As we're targeting "embedded" style targets, it makes sense
      # to default to highmem off
      # ref: https://bugs.launchpad.net/qemu/+bug/1790975/comments/3
      # (See `ARM_LPAE = no`)
      "-machine virt,highmem=off"
      "-cpu cortex-a7"
      "-device virtio-keyboard"
      "-device virtio-tablet"
      # Custom resolution could be added with:
      #,xres=1366,yres=768
      "-device virtio-gpu-pci"
    ];
  };
}
