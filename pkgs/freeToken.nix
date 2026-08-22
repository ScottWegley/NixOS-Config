{
  lib,
  appimageTools,
  fetchurl,
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

    extraInstallCommands = ''
          # Install the desktop file (no substitution needed – Exec already matches pname)
          mkdir -p $out/share/applications
          cat > $out/share/applications/${pname}.desktop <<EOF
      ${desktopFileContent}
      EOF

          # Copy the icon from the extracted AppImage (if present)
          # appimageTools usually extracts to $out/share/icons, but we ensure it
          if [ -d "$out/share/icons" ]; then
            mkdir -p $out/share/icons/hicolor/256x256/apps
            cp -r $out/share/icons/* $out/share/icons/hicolor/256x256/apps/ 2>/dev/null || true
          fi
    '';

    meta = with lib; {
      description = "Edge-native MoE serving engine for running large language models locally";
      homepage = "https://flashml.ai";
      license = licenses.asl20; # Apache‑2.0 (adjust if different)
      platforms = platforms.linux;
      sourceProvenance = [sourceTypes.binaryNativeCode];
    };
  }
