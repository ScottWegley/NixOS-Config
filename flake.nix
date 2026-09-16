# flake.nix
{
  description = "My system config";

  inputs = {
    # Default to nixos-unstable
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Latest stable branch of nixpkgs, used for version rollback
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";

    # Home-manager, for configuring apps in the user environment
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Lanzaboote, our bootloader
    lanzaboote = {
      url = "github:nix-community/lanzaboote/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # BizHawk (EmuHawk) emulator — ships its own Nix expression with prebuilt releases
    bizhawk = {
      url = "github:TASEmulators/BizHawk/master";
      flake = false;
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    home-manager,
    lanzaboote,
    bizhawk,
    ...
  }: let
    # System-wide identity settings
    userName = "scott";
    userDescription = "Scott Wegley";
    hostName = "TERRA-NIXOS";

    # Supported systems for flake packages, shell, etc.
    systems = [
      "x86_64-linux"
    ];
    forAllSystems = nixpkgs.lib.genAttrs systems;
  in {
    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);

    nixosConfigurations = {
      TERRA-NIXOS = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit
            inputs
            bizhawk
            userName
            userDescription
            hostName
            ;
        };
        modules = [
          ./nixos/configuration.nix

          lanzaboote.nixosModules.lanzaboote
        ];
      };
    };

    homeConfigurations = {
      "${userName}@${hostName}" = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = "x86_64-linux";
          overlays = [
            (import ./overlays {inherit inputs;}).modifications
            (import ./overlays {inherit inputs;}).stable-packages
          ];
          config = {allowUnfree = true;};
        };
        extraSpecialArgs = {
          inherit
            inputs
            bizhawk
            userName
            userDescription
            hostName
            ;
        };
        modules = [
          ./home-manager/home.nix
        ];
      };
    };
  };
}
