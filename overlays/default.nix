# /overlays/default.nix
{inputs, ...}: {
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: _prev: import ../pkgs final;

  # This one contains whatever you want to overlay
  modifications = final: prev: let
    # Workaround for nixpkgs#571181 ("linux: generate deterministic module
    # signatures and certificates"): the kernel module aggregator now cats every
    # .ko.cer listed in modules.dep, but openrazer's driver copied its .ko files
    # by hand (no modules_install), so no .ko.cer certificates were generated and
    # the build failed with exit 123. Upstream fixed this in commit 09233318
    # (PR #576293, merged to master Oct 20 2026), which has not yet reached
    # nixos-unstable. This replicates that fix locally; delete it once your
    # flake.lock is past 09233318 (i.e. after nixos-unstable merges master).
    openrazerFix = kernelPackages:
      kernelPackages.extend (_self: super: {
        openrazer = super.callPackage ../pkgs/openrazer-driver.nix {};
      });
  in {
    # Apply the fix to every top-level kernel package set that carries an
    # openrazer driver. boot.kernelPackages defaults to pkgs.linuxPackages, but
    # this config uses pkgs.linuxPackages_latest — so cover them all. (All of
    # these attrs exist in current nixpkgs; if a future update renames one,
    # drop it here.)
    linuxPackages = openrazerFix prev.linuxPackages;
    linuxPackages_latest = openrazerFix prev.linuxPackages_latest;
    linuxPackages_testing = openrazerFix prev.linuxPackages_testing;
    linuxPackages_zen = openrazerFix prev.linuxPackages_zen;
    linuxPackages_xanmod = openrazerFix prev.linuxPackages_xanmod;
    linuxPackages_xanmod_stable = openrazerFix prev.linuxPackages_xanmod_stable;
    linuxPackages_xanmod_latest = openrazerFix prev.linuxPackages_xanmod_latest;

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
