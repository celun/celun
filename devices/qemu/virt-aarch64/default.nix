{ config, lib, ... }:

{
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
}
