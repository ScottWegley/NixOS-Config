# /overlays/default.nix
{inputs, ...}: {
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: _prev: import ../pkgs final;

  # This one contains whatever you want to overlay
  modifications = final: prev: {
    # example = prev.example.overrideAttrs (oldAttrs: rec { ... });
  };

  # When applied, the stable nixpkgs set will be accessible through 'pkgs.stable'
  stable-packages = final: _prev: {
    stable = import inputs.nixpkgs-stable {
      system = final.system;
      config.allowUnfree = true;
    };
  };
}
