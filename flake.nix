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

    # Strata (Niko1221/Strata): the inference engine + server source. Pinned to a
    # specific commit so builds are reproducible and we control exactly what runs.
    # To update: change the commit below, then `nix flake lock --update-input strata`.
    strata = {
      url = "github:Niko1221/Strata/61b3fb5dd3f1e8ec09cf7e4e05208bc6d3c46406";
      flake = false;
    };

    # llama.cpp/ggml: the exact commit Strata's source pins (see
    # strata/third_party/ggml/VERSION.txt). Must match that pin or evaluation fails.
    llama-pinned = {
      url = "github:ggml-org/llama.cpp/3cf03257f219afbe7334045ff7c6a06ac68c627d";
      flake = false;
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    home-manager,
    lanzaboote,
    strata,
    llama-pinned,
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

    # Strata: build the engine + serve bundle from our own pkgs/ definitions.
    # We no longer depend on the upstream strata.nix flake (Yunor743/strata.nix).
    strataPkgs = let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };

      version =
        let
          projectLine = builtins.head (builtins.filter
            (l: builtins.match "project\\(strata VERSION.*" l != null)
            (nixpkgs.lib.splitString "\n"
              (builtins.readFile (inputs.strata + "/CMakeLists.txt"))));
        in
          builtins.head (builtins.match "project\\(strata VERSION ([0-9.]+).*" projectLine);

      ggmlPin = builtins.head (builtins.match "([0-9a-f]+).*"
        (builtins.readFile (inputs.strata + "/third_party/ggml/VERSION.txt")));

      pinChecked =
        if (inputs.llama-pinned.rev or "") == ggmlPin then true
        else throw ''
          Strata's source pins llama.cpp/ggml at ${ggmlPin}, but this flake locks
          llama-pinned at ${inputs.llama-pinned.rev or "an unknown revision"}.
          Fix: set inputs.llama-pinned.url = "github:ggml-org/llama.cpp/${ggmlPin}" in
          flake.nix, then run: nix flake lock --update-input llama-pinned'';

      strataEngine = pkgs.callPackage ./pkgs/strata-engine.nix {
        inherit version ggmlPin pinChecked;
        src = inputs.strata;
        llamaSrc = inputs.llama-pinned;
      };

      strataServe = pkgs.callPackage ./pkgs/strata-serve.nix {
        inherit version pinChecked;
        strataSrc = inputs.strata;
        llamaSrc = inputs.llama-pinned;
        engine = strataEngine;
      };
    in {
      strata-engine = strataEngine;
      strata-serve = strataServe;
      strata = strataServe;
    };
  in {
    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);

    # Expose the Strata packages so they can be built/tested independently.
    packages = forAllSystems (system: strataPkgs);

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

          # Strata: our own module (on-demand service, sm_120 engine). Pass the
          # serve bundle in; it carries the engine under passthru.engine.
          (import ./nixos/core/strata.nix { strataServe = strataPkgs.strata-serve; })
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
