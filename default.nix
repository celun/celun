{ pkgs ? import ./pkgs.nix {
  overlays = [(import ./pkgs)];
} }:
  pkgs.shenanigans
