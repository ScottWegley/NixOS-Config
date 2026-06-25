{
  pkgs,
  userName,
  ...
}: let
  coreTools = with pkgs; [
    alejandra
  ];

  browsers = with pkgs; [
    firefox
    floorp-bin
  ];

  communication = with pkgs; [
    proton-pass
    proton-vpn
    discord
    filezilla
  ];

  media = with pkgs; [
    obsidian
    qbittorrent
    vlc
    gparted-full
    vesktop
  ];

  customApps = with pkgs; [
    pokeFinder
  ];

  obsStudioWrapper = pkgs.writeShellScriptBin "obs-studio" ''
    export __NV_DISABLE_EXPLICIT_SYNC=1
    exec ${pkgs.obs-studio}/bin/obs "$@"
  '';
in {
  imports = [
    # ./nvim.nix
  ];

  home = {
    username = userName;
    homeDirectory = "/home/${userName}";
  };

  programs.vscode = {
    enable = true;
  };

  programs.calibre = {
    enable = true;
  };

  programs.obs-studio = {
    enable = true;
  };

  programs.fastfetch = {
    enable = true;
  };

  home.packages = pkgs.lib.concatLists [
    coreTools
    browsers
    communication
    media
    customApps
    [obsStudioWrapper]
  ];

  systemd.user.services.start-protonvpn = {
    Unit = {
      Description = "Start ProtonVPN on login";
      After = ["graphical-session.target"];
      Wants = ["graphical-session.target"];
      PartOf = ["graphical-session.target"];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.proton-vpn}/bin/protonvpn-app";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install = {
      WantedBy = ["graphical-session.target"];
    };
  };

  programs.git.enable = true;

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "25.11";
}
