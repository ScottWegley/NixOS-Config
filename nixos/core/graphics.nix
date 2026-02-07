{ ... }:

{
  # Nvidia Configuration
  hardware.graphics.enable = true;
  hardware.nvidia.open = true;
  hardware.nvidia.modesetting.enable = true;

  # Enable the X11 windowing system.
  services.xserver.enable = true;
  services.xserver.videoDrivers = [ "nvidia" ];

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

}
