{ pkgs, lib }:

{
  evaluateFilesystemImage = { config ? {}, modules ? [] }: import ./filesystem-image/eval-config.nix {
    inherit pkgs config modules;
  };
}
