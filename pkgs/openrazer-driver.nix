# Local replacement for nixpkgs' pkgs/os-specific/linux/openrazer/driver.nix,
# replicating the upstream fix from commit 09233318 (PR #576293):
#   "linuxPackages.openrazer: install modules through modules_install"
#
# Why this exists: nixpkgs PR #571181 switched kernel module signing to
# kmodigest and made the module aggregator cat every .ko.cer listed in
# modules.dep. The old openrazer driver copied its .ko files by hand (no
# modules_install), so no .ko.cer certificates were generated and the build
# failed with exit 123. That fix has not yet reached nixos-unstable, so this
# file is wired in via overlays/default.nix until flake.lock moves past
# 09233318 — then delete this file and the overlay entry together.

{
  coreutils,
  fetchFromGitHub,
  kernel,
  kernelModuleMakeFlags,
  stdenv,
  lib,
  udevCheckHook,
  util-linux,
}:

# Copied from nixpkgs' pkgs/development/python-modules/openrazer/common.nix so
# this file stays self-contained (it is called via callPackage with no access
# to the nixpkgs source tree).
let
  common = rec {
    version = "3.12.4";

    src = fetchFromGitHub {
      owner = "openrazer";
      repo = "openrazer";
      tag = "v${version}";
      hash = "sha256-WgDYs0ehnzWlX/wvfur0UhFLbZv7jZ6FMybqDaFDuLg=";
    };

    meta = {
      homepage = "https://openrazer.github.io/";
      changelog = "https://github.com/openrazer/openrazer/releases/tag/${src.tag}";
      license = lib.licenses.gpl2Only;
      maintainers = with lib.maintainers; [ evanjs ];
      platforms = lib.platforms.linux;
    };
  };
in
stdenv.mkDerivation (
  common
  // {
    pname = "openrazer";
    version = "${common.version}-${kernel.version}";

    nativeBuildInputs = [ udevCheckHook ] ++ kernel.moduleBuildDependencies;

    makeFlags = kernelModuleMakeFlags ++ [
      "KERNELDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
      # The upstream Makefile has no Kbuild install target, so run the kernel's
      # modules_install on the build directory. This is what makes kmodigest
      # sign each module and emit its .ko.cer certificate next to the .ko.
      "INSTALL_MOD_PATH=${placeholder "out"}"
      "INSTALL_MOD_DIR=kernel/drivers/hid"
      "INSTALL_MOD_STRIP=1"
      "DEPMOD=true"
    ];

    doInstallCheck = true;

    # Use stdenv's built-in install mechanism (make <makeFlags> <installFlags>
    # modules_install) rather than a custom installPhase: $(PWD) is expanded by
    # the shell as an environment variable, not command substitution.
    installTargets = [ "modules_install" ];

    installFlags = [
      "-C"
      "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
      "M=$(PWD)/driver"
    ];

    postInstall = ''
      RAZER_MOUNT_OUT="$out/bin/razer_mount"
      RAZER_RULES_OUT="$out/etc/udev/rules.d/99-razer.rules"
      install -m 644 -v -D install_files/udev/99-razer.rules $RAZER_RULES_OUT
      install -m 755 -v -D install_files/udev/razer_mount $RAZER_MOUNT_OUT
      substituteInPlace $RAZER_RULES_OUT \
        --replace razer_mount $RAZER_MOUNT_OUT \
        --replace plugdev openrazer
      substituteInPlace $RAZER_MOUNT_OUT \
        --replace /usr/bin/logger ${util-linux}/bin/logger \
        --replace chgrp ${coreutils}/bin/chgrp \
        --replace "PATH='/sbin:/bin:/usr/sbin:/usr/bin'" "" \
        --replace plugdev openrazer
    '';

    enableParallelBuilding = true;

    meta = common.meta // {
      description = "Entirely open source Linux driver that allows you to manage your Razer peripherals on GNU/Linux";
      mainProgram = "razer_mount";
      broken = kernel.kernelOlder "4.19";
    };
  }
)
