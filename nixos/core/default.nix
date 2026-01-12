{
  config,
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    ./locale.nix
    ./audio.nix
    ./graphics.nix
  ];
}
