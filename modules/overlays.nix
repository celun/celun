# Simply imports our overlay in Nixpkgs
{
  nixpkgs.overlays = [
    (import ../pkgs)
  ];
}
