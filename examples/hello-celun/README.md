`hello-celun`
=============

This demo system does nothing useful, except show a working example.

* * *

This system has been tested on the following devices:

 - `qemu/pc-x86_64`
 - `qemu/virt-aarch64`


* * *

## Running this example

At the root of the `celun` checkout, build the system with:

```
 $ nix-build --argstr device "qemu/pc-x86_64" ./examples/hello-celun -A build.wip
```

Once built, run using the following command. This assumes `qemu-system-x86_64`
is in the environment.

```
 $ result/run
```
