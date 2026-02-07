{
  pkgs,
  inputs,
  lib,
  userName,
  userDescription,
  hostName,
  ...
}:

{
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

  nix =
    let
      flakeInputs = lib.filterAttrs (_: lib.isType "flake") inputs;
    in
    {
      settings = {
        # Enable flakes and new 'nix' command
        experimental-features = "nix-command flakes";
        # Opinionated: disable global registry
        flake-registry = "";
      };
      # Opinionated: disable channels
      channel.enable = false;

      # Opinionated: make flake registry and nix path match flake inputs
      registry = lib.mapAttrs (_: flake: { inherit flake; }) flakeInputs;
      nixPath = lib.mapAttrsToList (n: _: "${n}=flake:${n}") flakeInputs;
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
    extraSpecialArgs = { inherit inputs userName; };
    users = {
      ${userName} = import ../home-manager/home.nix;
    };
  };

  hardware.openrazer.enable = true;

  environment.systemPackages = with pkgs; [
    git
    wget
    sbctl
    polychromatic
    openrazer-daemon
    razergenie
    input-remapper
    gh
    mlocate
  ];

  services.input-remapper.enable = true;

  services.lact.enable = true;

  services.locate = {
    enable = true;
    package = pkgs.mlocate;
  };

  system.stateVersion = "25.11";

}
