{pkgs, ...}: {
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  services.gnome.gnome-remote-desktop.enable = true;

  systemd.services.gnome-remote-desktop = {
    wantedBy = ["graphical.target"];
    after = ["network.target" "gdm.service"];
    wants = ["network.target" "gdm.service"];
  };
}
