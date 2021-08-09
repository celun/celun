{ config, lib, ... }:

{
  hardware = {
    cpu = "generic-x86_64";
  };
  wip.kernel.features = with lib.kernel; {
    # ACPI and PCI Required for many features
    acpi = true;
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
        DRM_BOCHS = yes;
      })
    ]
  ;
}
