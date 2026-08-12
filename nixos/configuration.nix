{
  pkgs,
  inputs,
  lib,
  userName,
  userDescription,
  hostName,
  ...
}: let
  hardwareTools = with pkgs; [
    openrazer-daemon
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
    hardwareTools
    searchTools
  ];

  environment.sessionVariables = {
    QT_QPA_PLATFORMTHEME = "generic";
    QT_STYLE_OVERRIDE = "fusion";
  };

  services.lact.enable = true;

  services.locate = {
    enable = true;
    package = pkgs.mlocate;
  };

  fileSystems."/mnt/nix-extra" = {
    device = "/dev/disk/by-uuid/976723e9-8d65-4359-8b72-b1cfdc3e0a8e";
    fsType = "ext4";
    options = ["nofail" "x-systemd.automount" "x-systemd.device-timeout=5s"];
  };

  fileSystems."/mnt/windows-data" = {
    device = "/dev/disk/by-uuid/8A54CE4654CE352B";
    fsType = "ntfs";
    options = ["nofail" "x-systemd.automount" "x-systemd.device-timeout=5s"];
  };

  fileSystems."/mnt/windows-extra" = {
    device = "/dev/disk/by-uuid/8E0407BA0407A3F5";
    fsType = "ntfs";
    options = ["nofail" "x-systemd.automount" "x-systemd.device-timeout=5s"];
  };

  users.users.root = {
    hashedPassword = "$6$2fub6/mLuccjczvb$PIU0fYWodOCM5DsyMHQmKAx9DtPDjSOeB5dwodbogJYBt6M8hmIhAaMImeE8GjUQJHlYupVonqAYBBarYtCj00";
  };

  services.udev.packages = with pkgs; [game-devices-udev-rules];
  # Disable the PCIE combo bluetooth adapter in favor of USB bluetooth adapter.
  # Also grant access to SteelSeries Arctis devices for Linux Arctis Manager.
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTR{idVendor}=="8087", ATTR{idProduct}=="0038", ATTR{authorized}="0"

    ACTION=="remove", GOTO="local_end"

    # SteelSeries Arctis Nova Pro Wireless
    SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTRS{idVendor}=="1038", ATTRS{idProduct}=="12e0|12e5|225d", MODE="0666", TAG+="uaccess"

    # SteelSeries Arctis Nova 5 Wireless
    SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTRS{idVendor}=="1038", ATTRS{idProduct}=="2232|2253|2264", MODE="0666", TAG+="uaccess"

    # SteelSeries Arctis Nova 7
    SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTRS{idVendor}=="1038", ATTRS{idProduct}=="22a1|227e|2258|229e|22a9|22a5", MODE="0666", TAG+="uaccess"

    # SteelSeries Arctis Nova Pro
    SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTRS{idVendor}=="1038", ATTRS{idProduct}=="12cd|12cb", MODE="0666", TAG+="uaccess"

    # SteelSeries Arctis Nova 7 (discrete battery)
    SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTRS{idVendor}=="1038", ATTRS{idProduct}=="2202|2206|22a4|223a|227a|22ab", MODE="0666", TAG+="uaccess"

    # SteelSeries Arctis 7+
    SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTRS{idVendor}=="1038", ATTRS{idProduct}=="220e|2212|2216|2236", MODE="0666", TAG+="uaccess"

    LABEL="local_end"
  '';

  security.polkit.enable = true;

  # Enable lingering for the main user so user units can run without an
  # interactive login (keeps the --user systemd instance running).
  system.activationScripts.enable-linger = {
    text = ''
      # enable linger for the main user; ignore errors if already set
      loginctl enable-linger ${toString userName} || true
    '';
  };

  # Provide a GDM custom.conf. Enable automatic login for the main user.
  # Force it so it wins over the module-provided default file.
  environment.etc."gdm/custom.conf".text = lib.mkForce ''
    [daemon]
    AutomaticLoginEnable=true
    AutomaticLogin=${toString userName}
  '';

  # Systemd oneshot service that runs after the display manager to lock
  # the autologin session. It sleeps briefly to allow the session to be
  # fully initialized, then locks all sessions via loginctl.
  systemd.services.lock-after-boot = {
    description = "Lock autologin session after boot";
    wantedBy = ["multi-user.target"];
    after = ["graphical.target" "display-manager.service"];
    serviceConfig = {
      Type = "oneshot";
      ExecStartPre = "/run/current-system/sw/bin/sleep 10";
      ExecStart = "/run/current-system/sw/bin/loginctl lock-sessions";
    };
  };

  system.stateVersion = "25.11";
}
