{
  pkgs,
  userName,
  ...
}:

{
  imports = [
    # ./nvim.nix
  ];

  home = {
    username = userName;
    homeDirectory = "/home/${userName}";
  };

  home.packages = with pkgs; [
    firefox
    floorp-bin
    proton-pass
    vesktop
    protonvpn-gui
    (discord.override { withVencord = true; })
    obsidian
    filezilla
  ];

  programs.vscode = {
    enable = true;
  };

  programs.calibre = {
    enable = true;
  };

  systemd.user.services.start-protonvpn = {
    Unit = {
      Description = "Start ProtonVPN on login";
      After = [ "graphical-session.target" ];
      Wants = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.protonvpn-gui}/bin/protonvpn-app";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  programs.home-manager.enable = true;
  programs.git.enable = true;

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "25.11";
}
