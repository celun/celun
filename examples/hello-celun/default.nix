{ device ? null }@args:

import ../../lib/eval-with-configuration.nix (args // {
  inherit device;
  verbose = true;
  configuration = {
    imports = [
      ./configuration.nix
      (
        { lib, ... }:
        {
          celun.system.automaticCross = lib.mkDefault true;
        }
      )
    ];
  };
  additionalHelpInstructions = ''
    Assuming this is ran at the root of the celun checkout, use the following
    command to build this system:

     $ nix-build --argstr device "qemu/pc-x86_64" ./examples/hello-celun -A config.wip.output

    Then, with `qemu-system-x86_64` available in the environment, run the VM
    using:

     $ result/run
  '';
})
