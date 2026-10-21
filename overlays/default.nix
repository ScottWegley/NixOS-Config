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

    # Workaround for pyopenjtalk-plus 0.4.1-post9 failing its own test suite on
    # Python 3.14: Cython >= 3.2 auto-inserts element-type checks from the
    # list[str] annotation, so run_njd_from_mecab raises "Expected str, got int"
    # instead of the old "must be str", and
    # tests/test_frontend.py::test_run_njd_from_mecab_invalid_input_should_not_
    # break_next_call fails its regex match (1 failed, 1678 passed). Upstream
    # fixed this in pyopenjtalk-plus commit 90b644f, backported by open nixpkgs
    # PR #576063 — not yet merged into the locked rev. This applies the same
    # one-line test fix locally; delete it once flake.lock has that PR.
    pyopenjtalkPlusFix = pythonSet:
      if pythonSet ? pyopenjtalk-plus
      then
        pythonSet
        // {
          pyopenjtalk-plus = pythonSet.pyopenjtalk-plus.overrideAttrs (old: rec {
            patches = (old.patches or []) ++ [../pkgs/pyopenjtalk-plus-python314-test.patch];
          });
        }
      else pythonSet;

    # Every top-level python package set that carries the package. Only the
    # canonical versioned sets (python312Packages … python316Packages) are
    # touched: unversioned names like python3Packages are aliases of a
    # versioned set (e.g. `python3Packages = dontRecurseIntoAttrs
    # python314Packages`), and patching both the alias and its target applies
    # the fix twice to the same package, which fails with "previously applied
    # patch detected". Sets without the package are passed through unchanged.
    pyopenjtalkPlusSets = prev.lib.mapAttrs (_: pyopenjtalkPlusFix) (prev.lib.attrsets.filterAttrs (
        name: _:
          prev.lib.strings.match "^python[0-9]+\.[0-9]+Packages$" name != null
      )
      prev);
  in
    {
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

      # Workaround for calibre 9.16.0 (nixpkgs PR #573023, merged ~Oct 17 2026)
      # failing its own `python setup.py test` install check in the sandbox: two
      # tests error out — test_speech_dispatcher can't import the speechd python
      # client (ModuleNotFoundError), and test_merge_file fails to load its epub
      # fixture ("OPF file does not exist"). Upstream master still ships 9.16.0
      # without excluding them, so this is fresh breakage, not a local issue. We
      # keep doInstallCheck = true (so the version/udev check phases still run)
      # and only replace the test-running installCheckPhase with a no-op. Delete
      # once upstream calibre excludes or fixes these two tests.
      calibre = prev.calibre.overrideAttrs (_old: {
        installCheckPhase = ''
          runHook preInstallCheck
          echo "skipping calibre test suite (see overlays/default.nix workaround)"
          runHook postInstallCheck
        '';
      });

      # example = prev.example.overrideAttrs (oldAttrs: rec { ... });
    }
    // pyopenjtalkPlusSets;

  # When applied, the stable nixpkgs set will be accessible through 'pkgs.stable'
  stable-packages = final: _prev: {
    stable = import inputs.nixpkgs-stable {
      system = final.system;
      config.allowUnfree = true;
    };
  };
}
