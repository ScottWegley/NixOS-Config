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
      ExecStart = "${pkgs.linuxArctisManager}/bin/lam-daemon";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install = {
      WantedBy = ["graphical-session.target"];
    };
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
        # Log everything for debugging
        exec > /tmp/lock-after-boot.log 2>&1
        set -x
        echo "=== Service started at $(date) ==="
        if ${pkgs.dbus}/bin/dbus-send --session --dest=org.gnome.ScreenSaver \
             --type=method_call /org/gnome/ScreenSaver org.gnome.ScreenSaver.Lock; then
          echo "Locked via ScreenSaver"
        elif ${pkgs.dbus}/bin/dbus-send --session --dest=org.gnome.Shell \
             --type=method_call /org/gnome/Shell org.gnome.Shell.Eval \
             string:'Main.shellDBusService.LockScreen()'; then
          echo "Locked via Shell"
        else
          ${pkgs.systemd}/bin/loginctl lock-session "$XDG_SESSION_ID"
          echo "Locked via loginctl"
        fi

        marker="$XDG_RUNTIME_DIR/lock-after-boot-done"
        touch "$marker"
        echo "Marker created at $(date)"
      '';
      RemainAfterExit = "no";
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
