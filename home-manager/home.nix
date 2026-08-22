{
  pkgs,
  userName,
  ...
}: let
  # Custom packages
  pokeFinder = pkgs.callPackage ../pkgs/pokeFinder.nix {};
  linuxArctisManager = pkgs.callPackage ../pkgs/linuxArctisManager.nix {};
  freeToken = pkgs.callPackage ../pkgs/freeToken.nix {};

  # Tool groups
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

  customApps = [pokeFinder linuxArctisManager freeToken];

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

  programs.vscode.enable = true;
  programs.calibre.enable = true;
  programs.fastfetch.enable = true;
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
  };
  services.ssh-agent.enable = true;

  home.packages = pkgs.lib.concatLists [
    coreTools
    browsers
    communication
    media
    userTools
    customApps
    [obsStudioWrapper]
  ];

  systemd.user.services.arctis-manager = {
    Unit = {
      Description = "Linux Arctis Manager daemon";
      After = ["graphical-session.target"];
      Wants = ["graphical-session.target"];
      PartOf = ["graphical-session.target"];
    };
    Service = {
      Type = "simple";
      ExecStart = "${linuxArctisManager}/bin/lam-daemon";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = ["graphical-session.target"];
  };

  systemd.user.services.lock-after-boot = {
    Unit = {
      Description = "Lock screen once after boot and autologin";
      After = ["graphical-session.target"];
      Wants = ["graphical-session.target"];
      PartOf = ["graphical-session.target"];
      ConditionPathExists = "!%t/lock-after-boot-done";
    };
    Service = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "lock-after-boot" ''
        # ... (keep your existing script) ...
      '';
      RemainAfterExit = "no";
    };
    Install.WantedBy = ["graphical-session.target"];
  };

  programs.git.enable = true;
  systemd.user.startServices = "sd-switch";
  home.stateVersion = "25.11";
}
