{
  lib,
  appimageTools,
  fetchurl,
  makeWrapper,
}: let
  pname = "freetoken-desktop";
  version = "0.1.2";

  src = fetchurl {
    url = "https://github.com/FlashML-org/FreeToken-Web/releases/download/beta/freetoken-desktop-x86_64.AppImage";
    hash = "sha256-h4ySA5IlVhWvjZuuda0ICRGGM1qQ/3OtzG2afA5ZEkU=";
  };

  desktopFileContent = ''
    [Desktop Entry]
    Categories=
    Comment=FreeToken Desktop — local LLM runtime control panel
    Exec=freetoken-desktop
    StartupWMClass=freetoken-desktop
    Icon=freetoken-desktop
    Name=FreeToken Desktop
    Terminal=false
    Type=Application
  '';
in
  appimageTools.wrapType2 {
    inherit pname version src;

    nativeBuildInputs = [makeWrapper];

    extraInstallCommands = ''
      # Install desktop file
      mkdir -p $out/share/applications
      cat > $out/share/applications/${pname}.desktop <<EOF
      ${desktopFileContent}
      EOF

      # Copy icon if present
      if [ -d "$out/share/icons" ]; then
        mkdir -p $out/share/icons/hicolor/256x256/apps
        cp -r $out/share/icons/* $out/share/icons/hicolor/256x256/apps/ 2>/dev/null || true
      fi

      # Move the original wrapper and create a new one that sets environment variables
      mv $out/bin/${pname} $out/bin/${pname}.real
      cat > $out/bin/${pname} <<'EOF'
      #!/usr/bin/env bash
      export FREETOKEN_FT_BIN="$HOME/.local/bin/ft"
      export PATH="$HOME/.local/bin:$PATH"
      exec "$(dirname "$0")/freetoken-desktop.real" "$@"
      EOF
      chmod +x $out/bin/${pname}
    '';

    meta = with lib; {
      description = "Edge-native MoE serving engine for running large language models locally";
      homepage = "https://flashml.ai";
      license = licenses.asl20;
      platforms = platforms.linux;
      sourceProvenance = [sourceTypes.binaryNativeCode];
    };
  }
