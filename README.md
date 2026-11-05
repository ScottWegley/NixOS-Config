# NixOS Config Information

## Purpose

This document is intended to serve as a refresher to myself about the intricacies of my NixOS configuration.

## Common Commands

### Update Flake Inputs
```
sudo nix flake update --flake <path_to_folder_with_flake.nix>
```
This updates `flake.lock` to the latest versions of all inputs (nixpkgs, home-manager, lanzaboote, etc.).

### Rebuild System
```
sudo nixos-rebuild switch --flake <path_to_folder_with_flake.nix>
```
Builds and activates the configuration from the current `flake.lock`.  The `--upgrade` flag is a **channels** feature and has no effect here since channels are disabled.  The correct workflow is: run `nix flake update` first, then `nixos-rebuild switch`.

### Garbage collection
```
sudo nix-collect-garbage -d
```
Deletes all unreachable Nix store paths and frees space after old generations are removed.

To keep only the last 5 system generations before collecting garbage:
```
sudo nix-env --delete-generations +5 --profile /nix/var/nix/profiles/system
sudo nix-collect-garbage -d
```

## Non-Standard Configs & Workarounds

Local deviations from stock nixpkgs. **Keep this section current** — every workaround has a removal condition, and after each `nix flake update` you should check whether any of them can be deleted before rebuilding.

### VS Code copilot-sdk runtimes lack execute permission
- **Issue:** [microsoft/vscode#343101](https://github.com/microsoft/vscode/issues/343101) / [NixOS/nixpkgs#573021](https://github.com/NixOS/nixpkgs/issues/573021). nixpkgs installs VS Code's bundled `copilot-sdk-linux-x64` runtimes as mode `0444`, so the Copilot Agent Host can't launch them ("Cannot call write after a stream was destroyed").
- **Workaround:** A boot-time one-shot systemd service, `copilot-runtime-fix` (defined in [nixos/configuration.nix](./nixos/configuration.nix)), copies each `/nix/store/*copilot-sdk-linux-x64*.../copilot-runtime` to a temp file, makes it executable, and bind-mounts that over the original.
- **Removal condition:** Delete the service once nixpkgs ships VS Code with executable runtimes (or an overlay fixes it). Re-run after a rebuild via `sudo systemctl restart copilot-runtime-fix`.

### Strata local inference API (RTX 5090)
- **What:** [Strata](https://github.com/Niko1221/Strata), the engine that runs Qwen3.8-Flash-Next (125B MoE, ~6B active) on a single NVIDIA GPU and serves it over an OpenAI-/Anthropic-compatible API on localhost (`http://127.0.0.1:8080`). Integrated via the [strata-nix](https://github.com/Yunor743/strata.nix) flake input (not used as-is — only its `nixosModules.default` and packages).
- **Local deviation:** The upstream flake builds the CUDA engine for `sm_89` (RTX 40) by default. This box has an RTX 5090 (Blackwell, `sm_120`), so [nixos/core/strata.nix](./nixos/core/strata.nix) rebuilds the engine with `cudaArch = "120"` and points the serve bundle's `passthru.engine` at it. The serve scripts are identical; only the engine binary changes.
- **On-demand, not always-on:** Strata is defined as a unit but *not* enabled at boot — there is no `wantedBy` symlink, so it does not start automatically. Start/stop it like an app:
  - `sudo systemctl start strata` (first start downloads ~70 GB of model shards into `/var/lib/strata`, builds the pack + MTP draft layer, writes `config.json`, then starts `strata-serve`)
  - `sudo systemctl stop strata`
  - `systemctl status strata`
  Loading pushes 35–55 GB into RAM and takes 1–3 min. The engine build itself is a one-time ~20–40 min compile (cached after).
- **API:** `http://127.0.0.1:8080/v1/chat/completions` (OpenAI) and `/v1/messages` (Anthropic); web chat at `http://127.0.0.1:8080/`.
- **Options:** See the [strata.nix README](https://github.com/Yunor743/strata.nix#options-services-strata) for `services.strata.*` (family, model, context, host/port, gpus, lowRam, sampling, mcpServers, extraEngineArgs). Defaults here: `family = swift`, `model = IQ2_XS`, `context = 32768`, loopback only.
- **Removal condition:** None — this is a permanent local service. To disable, set `services.strata.enable = false` in [nixos/core/strata.nix](./nixos/core/strata.nix).

## Structure

### `flake.nix`
The top-level entry point for the entire configuration.  Defines:
- **Inputs**: `nixpkgs` (unstable), `nixpkgs-stable` (for version rollback), `home-manager`, and `lanzaboote` (secure boot).
- **Identity variables**: `userName`, `userDescription`, and `hostName` are defined here in one place and passed to all modules via `specialArgs`/`extraSpecialArgs` so they never need to be hardcoded elsewhere.
- **Outputs**: The formatter (alejandra), the NixOS system configuration for `TERRA-NIXOS`, and the Home Manager configuration for `scott@TERRA-NIXOS`.

### `flake.lock`
Auto-generated lock file that pins the exact versions of all flake inputs.  This ensures builds are reproducible.  Updated by `nix flake update`.

### `nixos/configuration.nix`
The main NixOS module.  Responsible for:
- Importing `hardware-configuration.nix`, `core/`, `sysapps/`, and the Home Manager NixOS module.
- Applying overlays and enabling unfree packages.
- Configuring nix settings (flakes, registry, disabling channels).
- Defining the user account (using identity variables from `flake.nix`).
- Configuring Home Manager integration (`useGlobalPkgs`, `useUserPackages`).
- Declaring system-wide packages and services (OpenRazer, LACT, mlocate, plus misc tools: mgba, python3, uv, melonds).

### `nixos/hardware-configuration.nix`
Auto-generated by `nixos-generate-config`.  Defines hardware-specific settings like kernel modules, filesystem mounts, and CPU microcode.  **Do not edit by hand** — it may be overwritten by future invocations of `nixos-generate-config`.

### `nixos/core/`
Modularized core system configuration, united by `default.nix` which imports:
| File | Purpose |
|---|---|
| `audio.nix` | PipeWire audio (with PulseAudio compatibility and ALSA 32-bit support) |
| `bootloader.nix` | Lanzaboote secure boot, EFI settings, and Windows dual-boot entry |
| `desktop.nix` | GNOME desktop environment, GDM display manager, and CUPS printing |
| `graphics.nix` | Nvidia GPU drivers (open kernel module), X11, and keyboard layout |
| `locale.nix` | Timezone (America/Phoenix) and locale settings (en_US.UTF-8) |
| `networking.nix` | Hostname, firewall rules, and NetworkManager |
| `rdp.nix` | Enables GNOME Remote Desktop (RDP) and wires it into the graphical target. The supporting system changes (user linger, GDM autologin) live in `nixos/configuration.nix`. |
| `strata.nix` | Strata local inference API (Qwen3.8-Flash-Next 125B MoE) on the RTX 5090; engine rebuilt for sm_120 |

### `sysapps/`
System-level application configurations that enable NixOS modules (as opposed to user-level apps in Home Manager).  Currently contains:
- `steam.nix` — Steam with remote play firewall, protontricks, and extest.

### `home-manager/home.nix`
User-level configuration managed by Home Manager (running as a NixOS module).  Uses `useGlobalPkgs` so it shares the system's nixpkgs instance and overlays.  Manages:
- **User packages** (grouped in `let` bindings): core tools (alejandra, git, wget, gh, sbctl), browsers (Floorp), communication (Proton Pass, ProtonVPN, Discord, FileZilla), media (Obsidian, qBittorrent, VLC, GParted, Vesktop), utilities (Polychromatic, RazerGenie, QDirStat, Kdenlive, LocalSend, Eden, Dolphin Emu, LM Studio, etc.), custom apps (Linux Arctis Manager), and an OBS Studio wrapper.
- **Programs**: VS Code, Calibre, Fastfetch, Git, SSH client (with `ssh-agent` service).
- **User services**: Linux Arctis Manager daemon (`arctis-manager`) and a one-shot screen lock after boot/autologin (`lock-after-boot`).

### `overlays/default.nix`
Defines three overlays; `modifications` and `stable-packages` are applied in both `nixos/configuration.nix` and the flake's Home Manager pkgs:
- `additions` — Exposes custom packages from the `pkgs/` directory.
- `modifications` — Overrides existing nixpkgs packages (currently empty; see [Non-Standard Configs & Workarounds](#non-standard-configs--workarounds) for history).
- `stable-packages` — Makes `nixpkgs-stable` available as `pkgs.stable` for version rollback.

### `pkgs/default.nix`
Custom package definitions.  Currently defines three apps:
- `linuxArctisManager` — Open-source replacement for SteelSeries GG to manage Arctis headsets on Linux.
- `pkhex` — PKHeX wrapper; the vendored `PKHeX.exe` must be git-tracked or it won't exist in the flake's store copy (see `.gitignore`).
- `helium` — Helium hotspots app.

Both are consumed directly from `home-manager/home.nix` via `pkgs.callPackage`.

## Acknowledgement
The current configuration borrows from [the nix-starter-configs](https://github.com/Misterio77/nix-starter-configs/tree/main) repo by [Misterio77](https://github.com/Misterio77).  Their repository made it much easier to start configuring my setup.