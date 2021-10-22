let
  rev = "5bc8b980b9178ef9a4bb622320cf34e59ea2ea10";
  sha256 = "1zw8cigi50q6qac9nvb981p276bp5ap96sbdfgzrjf9m6210g6rk";
in
import (
  builtins.fetchTarball {
    inherit sha256;
    url = "https://github.com/NixOS/nixpkgs/archive/${rev}.tar.gz";
  }
)
