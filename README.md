# NixOS Config Infromatation

## Purpose

This document is intended to serve as a refresher to myself about the intricasies of my NixOS configuration.  This is my first NixOS installation, so there are bound to be plenty of mistakes present, but my goal is to fully switch over to NixOS from Windows 10/11.  I have a minor to moderate amount of experience with Linux (not a sys admin but not afraid of the terminal) so I have high hopes that I will be able to fully transition within a few months.  

In an ideal world, I would just fully switch over and figure it out, but I don't have enough free time to get my Nix system to have functional equivalence to my current Windows systems.  My strategy for now is just to dual-boot and work on setting up NixOS a little bit every week.

## Top Level Notes

### Update Flake
`sudo nix flake update --flake <path_to_folder_with_flake.nix>`
### Rebuild Nix
`sudo nixos-rebuild switch --flake <path_to_folder_with_flake.nix>`
Need to look into if including `--upgrade` flag in above command means you don't need to Update the Flake.  Current understanding indicates run Update and then Rebuild without the upgrade flag.

## Structure

Currently, the top level file for our configuration is `flake.nix`.  It contains `inputs` that are available to every other file in our configuration via their inclusion in the `flake.nix` `outputs`.
`flake.lock` is just a lock file for our flake that freezes the various versions used in our config to ensure it can always be reproduced.
The `nixos` folder contains `configuration.nix` and one of its imports `hardware-configuration.nix`.  These files both contain OS wide settings, Additionally, `configuration.nix` imports `default.nix` from the `nixos` subfolder `core`.  `default.nix` unites the modularized configurations for the core elements of my system, such as the audio service (`audio.nix`), my graphics and window manager configurations (`graphics.nix`), my locale information (`locale.nix`), etc.

# Acknowledgement
The current configuration heavily relies on and directly copies from [the nix-starter-configs](https://github.com/Misterio77/nix-starter-configs/tree/main) repo by [Misterio77](https://github.com/Misterio77).  Their repository made it so much easier to get started configuring my setup.