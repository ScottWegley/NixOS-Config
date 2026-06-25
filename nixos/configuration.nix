{
  pkgs,
  inputs,
  lib,
  userName,
  userDescription,
  hostName,
  ...
}: let
  coreTools = with pkgs; [
    git
    wget
    gh
    sbctl
  ];

  hardwareTools = with pkgs; [
    polychromatic
    openrazer-daemon
    razergenie
    input-remapper
  ];

  desktopApps = with pkgs; [
    qdirstat
    gsettings-desktop-schemas
    kdePackages.kdenlive
    localsend
    eden
    unrar
  ];

  searchTools = with pkgs; [
    mlocate
  ];
in {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    # Include all of our core modules
    ./core/default.nix
    # Include system apps configuration
    ../sysapps/default.nix
    inputs.home-manager.nixosModules.home-manager
  ];

  nixpkgs = {
    overlays = [
      inputs.self.overlays.additions
      inputs.self.overlays.modifications
      inputs.self.overlays.stable-packages
    ];
    config = {
      allowUnfree = true;
    };
  };

  nix = let
    flakeInputs = lib.filterAttrs (_: lib.isType "flake") inputs;
  in {
    settings = {
      # Enable flakes and new 'nix' command
      experimental-features = ["nix-command" "flakes"];
      # Opinionated: disable global registry
      flake-registry = "";
    };
    # Opinionated: disable channels
    channel.enable = false;

    # Opinionated: make flake registry and nix path match flake inputs
    registry = lib.mapAttrs (_: flake: {inherit flake;}) flakeInputs;
    nixPath = lib.mapAttrsToList (n: _: "${n}=flake:${n}") flakeInputs;

    # Automatic garbage collection: keep only the last 5 generations
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than +5";
    };
  };

  boot.kernelPackages = pkgs.linuxPackages_latest;

  users.users.${userName} = {
    isNormalUser = true;
    description = userDescription;
    extraGroups = [
      "networkmanager"
      "wheel"
      "openrazer"
      "mlocate"
    ];
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {inherit inputs userName;};
    users = {
      ${userName} = import ../home-manager/home.nix;
    };
  };

  hardware.openrazer.enable = true;
  environment.systemPackages = lib.concatLists [
    coreTools
    hardwareTools
    desktopApps
    searchTools
  ];

  environment.sessionVariables = {
    QT_QPA_PLATFORMTHEME = "generic";
    QT_STYLE_OVERRIDE = "fusion";
  };

  services.input-remapper.enable = true;

  services.lact.enable = true;

  services.locate = {
    enable = true;
    package = pkgs.mlocate;
  };

  services.udev.packages = with pkgs; [game-devices-udev-rules];
  # Disable the PCIE combo bluetooth adapter in favor of USB bluetooth adapter.
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTR{idVendor}=="8087", ATTR{idProduct}=="0038", ATTR{authorized}="0"
  '';

  security.polkit.enable = true;

  # Previously symlinked monitors.xml from Nix store; removed in favor of
  # a Wayland-native ApplyMonitorsConfig approach (managed by home-manager).
  # No tmpfiles rules here now; the user's ~/.config/monitors.xml is writable.
  systemd.tmpfiles.rules = [];

  system.stateVersion = "25.11";
}
