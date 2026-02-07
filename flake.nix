{

  description = "My system config";

  inputs = {
    # Default to nixos-unstable
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Latest stable branch of nixpkgs, used for version rollback
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";

    # Home-manager, for configuring apps in the user environment
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Lanzaboote, our new bootloader
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.0.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      lanzaboote,
      ...
    }:
    let
      # System-wide identity settings
      userName = "scott";
      userDescription = "Scott Wegley";
      hostName = "TERRA-NIXOS";

      # Supported systems for your flake packages, shell, etc.
      systems = [
        "aarch64-linux"
        "i686-linux"
        "x86_64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        import ./pkgs pkgs
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);

      overlays = import ./overlays { inherit inputs; };

      nixosConfigurations = {
        TERRA-NIXOS = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit
              inputs
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
    };
}
