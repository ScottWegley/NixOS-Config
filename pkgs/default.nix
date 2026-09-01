# /pkgs/default.nix
{pkgs}: {
  pokeFinder = pkgs.callPackage ./pokeFinder.nix {};
  linuxArctisManager = pkgs.callPackage ./linuxArctisManager.nix {};
}
