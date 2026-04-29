{pkgs, ...}: {
  # Enable xrdp
  services.xrdp.enable = true;
  services.xrdp.defaultWindowManager = "${pkgs.gnome-session}/bin/gnome-session";
  services.xrdp.openFirewall = true;

  # GNOME remote desktop backend
  services.gnome.gnome-remote-desktop.enable = true;

  # Disable autologin to avoid session conflicts
  services.displayManager.autoLogin.enable = false;

  # Disable sleep/hibernate so remote sessions aren't interrupted
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;
}
