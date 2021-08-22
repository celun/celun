{ lib, ... }:

let
  inherit (lib)
    concatMapStringsSep
    mkOption
    splitString
    types
  ;
in
{
  options.helpers = mkOption {
    # Unspecified on purpose
    type = types.attrs;
    internal = true;
  };

  config.helpers = rec {
    /**
     * Provides user-friendly aliases for defining sizes.
     */
    size = rec {
      TiB = x: 1024 * (GiB x);
      GiB = x: 1024 * (MiB x);
      MiB = x: 1024 * (KiB x);
      KiB = x: 1024 *      x;
    };

    /**
     * Drops the decimal portion of a floating point number.
     */
    chopDecimal = f: first (splitString "." (toString f));

    /**
     * Like `last`, but for the first element of a list.
     */
    first = list: lib.lists.last (lib.lists.reverseList list);

  };
}
