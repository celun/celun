let
  rev = "84f5a2e5e5ac352e8400c361e4e648026b636423";
  sha256 = "1k4d0yp319d35ld3nbn92a4fmv6pcbfxb8pd652y4qk2ckmbnwsz";
in
import (
  builtins.fetchTarball {
    inherit sha256;
    url = "https://github.com/NixOS/nixpkgs/archive/${rev}.tar.gz";
  }
)
