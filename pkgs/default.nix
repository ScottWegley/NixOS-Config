# /pkgs/default.nix
{pkgs}: {
  linuxArctisManager = pkgs.callPackage ./linuxArctisManager.nix {};
  pkhex = pkgs.callPackage ./pkhex.nix {};
  helium = pkgs.callPackage ./helium.nix {};
}
