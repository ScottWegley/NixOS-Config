{
  config,
  pkgs,
  inputs,
  ...
}:

{
  home.username = "scott";
  home.homeDirectory = "/home/scott";

  # User packages
  home.packages = with pkgs; [
    firefox
    floorp-bin
    proton-pass
    protonvpn-gui
    vesktop
  ];

  programs.vscode = {
    enable = true;
  };

  home.stateVersion = "25.11";
}
