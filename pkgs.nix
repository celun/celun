let
  rev = "04f574a1c0fde90b51bf68198e2297ca4e7cccf4";
  sha256 = "1frf2yspkgy72c5pznjgk8hbla7yyrn78azsf3ypkyb84vml5jnw";
in
import (
  builtins.fetchTarball {
    inherit sha256;
    url = "https://github.com/NixOS/nixpkgs/archive/${rev}.tar.gz";
  }
)
