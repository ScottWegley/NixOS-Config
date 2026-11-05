# nixos/core/strata.nix
#
# Strata: local OpenAI/Anthropic-compatible API for Qwen3.8-Flash-Next (125B MoE)
# on a single NVIDIA GPU, served over localhost by strata-nix (Yunor743/strata.nix).
#
# This module is loaded AFTER the upstream `strata-nix.nixosModules.default` so its
# overrides win. It keeps the service *defined* (so we retain the preStart model
# download orchestration, credential handling, and /var/lib/strata state) but drops
# the auto-start symlink: Strata is an on-demand app you start/stop with systemctl,
# not an always-on daemon.
#
# The upstream flake builds the CUDA engine for sm_89 (RTX 40) by default. This box
# has an RTX 5090 (Blackwell, sm_120), so we rebuild the engine for that arch and
# point the serve bundle's passthru.engine at it. The serve scripts are identical;
# only the engine binary changes.

{ inputs, pkgs, lib, config, ... }:
let
  system = "x86_64-linux";

  # Rebuild the inference engine for sm_120 (RTX 50). This is the one piece that
  # differs from the upstream default; everything else reuses strata-nix as-is.
  engine = inputs.strata-nix.packages.${system}.strata-engine.override { cudaArch = "120"; };

  # Swap the sm_89 engine out of the serve bundle's passthru for our sm_120 one.
  # Preserve the other passthru fields (share, py, prefetchFlags) untouched.
  strataServe = inputs.strata-nix.packages.${system}.strata.overrideAttrs (final: prev: {
    passthru = { inherit (prev.passthru) share py prefetchFlags; engine = engine; };
  });

  # Upstream options are defined regardless of `enable`, so we can reference them
  # here even though we disable the upstream's own service generation below.
  cfg = config.services.strata;
in {
  # Disable the upstream module's service generation. It builds systemd.services.strata
  # inside `lib.mkIf cfg.enable` and sets wantedBy = [ "multi-user.target" ] there.
  # NixOS concatenates list values across modules, so a later module CANNOT remove that
  # entry (wantedBy = [] just appends nothing; the upstream's multi-user.target stays).
  # There is also no clean config knob to delete a wants symlink after generation.
  # So we turn off the upstream's contribution and define the unit ourselves below,
  # mirroring upstream's module.nix exactly but WITHOUT wantedBy -> no auto-start.
  services.strata.enable = false;

  # Point the service at a serve bundle whose engine is built for sm_120.
  services.strata.package = strataServe;

  # Left as upstream defaults on purpose:
  #   family = swift, model = IQ2_XS, context = 32768, host = 127.0.0.1, port = 8080,
  #   gpus = [] (engine picks the card with the most VRAM), prefetchOnStart = true.

  systemd.services.strata = {
    description = "Strata: Qwen3.8-Flash-Next (125B MoE) local inference API";
    documentation = [ "https://github.com/Niko1221/Strata" ];
    # No wantedBy -> no auto-start symlink; start/stop on demand with systemctl.
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    path = [ cfg.package ];

    environment = lib.optionalAttrs (cfg.gpus != [ ]) {
      CUDA_DEVICE_ORDER = "PCI_BUS_ID";
      CUDA_VISIBLE_DEVICES = lib.concatStringsSep "," cfg.gpus;
    };

    preStart = lib.mkIf (cfg.prefetchOnStart && !cfg.mockEngine) (toString (
      pkgs.writeShellScript "strata-prestart" (''
        set -euo pipefail
        state="$STATE_DIRECTORY"
        exec ${cfg.package}/bin/strata-prefetch \
          --family ${lib.escapeShellArg cfg.family} \
          --model ${lib.escapeShellArg cfg.model} \
          --context ${toString cfg.context} \
          --data-dir "$state" \
      '' + lib.optionalString (cfg.lowRam != null) ''
          --low-ram ${if cfg.lowRam then "on" else "off"} \
      '' + lib.optionalString (cfg.hfTokenFile != null) ''
          --hf-token-file "/run/credentials/strata.service/hf-token" \
      '' + ''
          --emit-config "$state/config.json" \
          --engine ${lib.escapeShellArg (toString cfg.package.passthru.engine)}/bin/strata \
          --host ${lib.escapeShellArg cfg.host} \
      '' + lib.optionalString (cfg.apiKeyFile != null) ''
          --api-key-file "/run/credentials/strata.service/api-key" \
      '' + lib.optionalString (cfg.gpus != [ ]) ''
          --gpu ${lib.escapeShellArg (lib.concatStringsSep "," cfg.gpus)} \
      '' + lib.optionalString (cfg.sampling != { }) ''
          --sampling-json ${pkgs.writeText "strata-sampling.json" (builtins.toJSON cfg.sampling)} \
      '' + lib.optionalString (cfg.mcpServers != { }) ''
          --mcp-json ${pkgs.writeText "strata-mcp.json" (builtins.toJSON cfg.mcpServers)} \
      '' + lib.concatMapStrings (x: ''--extra-arg ${lib.escapeShellArg x} '') cfg.extraEngineArgs
      )
    ));

    serviceConfig = {
      Type = "simple";
      DynamicUser = true;
      StateDirectory = "strata";
      StateDirectoryMode = "0750";
      # First start: preStart downloads ~70 GB and builds the pack - the default
      # 90 s TimeoutStartSec kills it mid-download (the service is resumable, but
      # converge it in one pass). Applies to the start, incl. ExecStartPre.
      TimeoutStartSec = "0";
      WorkingDirectory = "%S/strata";
      UMask = "0077";
      Restart = "on-failure";
      RestartSec = 10;
      LoadCredential =
        (lib.optional (cfg.apiKeyFile != null) "api-key:${cfg.apiKeyFile}")
        ++ (lib.optional (cfg.hfTokenFile != null) "hf-token:${cfg.hfTokenFile}");
      ExecStart =
        if cfg.mockEngine
        then
          "${cfg.package}/bin/strata-serve --engine mock --port ${toString cfg.port} " +
          "--host ${lib.escapeShellArg cfg.host}"
        else
          "${cfg.package}/bin/strata-serve --engine strata --config %S/strata/config.json " +
          "--port ${toString cfg.port}";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
      LockPersonality = true;
      MemoryDenyWriteExecute = false;
    };
  };
}
