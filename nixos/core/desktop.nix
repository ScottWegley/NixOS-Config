{ ... }:

{
  # GNOME Desktop Environment
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  # Printing
  services.printing.enable = true;
}
