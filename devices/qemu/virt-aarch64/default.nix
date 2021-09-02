{ config, lib, ... }:

{
  device = {
    name = "qemu/virt-aarch64";
    config.qemu.enable = true;
  };

  hardware = {
    cpu = "generic-aarch64";
  };
  wip.kernel.structuredConfig =
    with lib.kernel;
    let
      inherit (config.wip.kernel) features;
    in
    lib.mkMerge [
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
    ]
  ;

  device.config.qemu = {
    qemuOptions = [
      "-machine virt"
      "-cpu cortex-a53"
      "-device virtio-keyboard"
      "-device virtio-tablet"
      # Custom resolution could be added with:
      #,xres=1366,yres=768
      "-device virtio-gpu"
    ];
  };
}
