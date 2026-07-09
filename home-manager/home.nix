{
  pkgs,
  userName,
  ...
}: let
  coreTools = with pkgs; [
    alejandra
    git
    wget
    gh
    sbctl
  ];

  browsers = with pkgs; [
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

  userTools = with pkgs; [
    polychromatic
    razergenie
    qdirstat
    gsettings-desktop-schemas
    kdePackages.kdenlive
    localsend
    eden
    dolphin-emu
    unrar
  ];

  customApps = with pkgs; [
    pokeFinder
    linuxArctisManager
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

  programs.fastfetch = {
    enable = true;
  };

  home.packages = pkgs.lib.concatLists [
    coreTools
    browsers
    communication
    media
    userTools
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

  systemd.user.services.arctis-manager = {
    Unit = {
      Description = "Linux Arctis Manager daemon";
      After = ["graphical-session.target"];
      Wants = ["graphical-session.target"];
      PartOf = ["graphical-session.target"];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.linuxArctisManager}/bin/lam-daemon";
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
