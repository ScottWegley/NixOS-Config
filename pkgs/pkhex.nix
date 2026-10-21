{
  stdenvNoCC,
  lib,
}:
stdenvNoCC.mkDerivation rec {
  pname = "pkhex";
  version = "26.10.18";

  # The executable is vendored in ./pkhex/ (provided by the user; not
  # distributed via GitHub releases).
  src = ./pkhex;

  installPhase = ''
        mkdir -p $out/opt/pkhex $out/bin
        cp PKHeX.exe $out/opt/pkhex/

        cat > $out/bin/pkhex <<EOF
    #!/usr/bin/env bash
    # The Nix store is read-only, but PKHeX writes its config next to the exe.
    # Copy the app into a writable directory on first run (or when the version changes).
    appDir="\$HOME/.local/share/pkhex"
    if [ ! -f "\$appDir/version" ] || [ "\$(cat "\$appDir/version")" != "${version}" ]; then
      mkdir -p "\$appDir"
      cp $out/opt/pkhex/PKHeX.exe "\$appDir/"
      echo "${version}" > "\$appDir/version"
    fi
    cd "\$appDir" || exit 1
    exec wine ./PKHeX.exe "\$@"
    EOF
        chmod +x $out/bin/pkhex

        # App menu entry for GNOME
        mkdir -p $out/share/applications
        cat > $out/share/applications/pkhex.desktop <<EOF
    [Desktop Entry]
    Type=Application
    Name=PKHeX
    Comment=Pokémon save editor (Wine)
    Exec=pkhex
    Categories=Utility;Game;
    Terminal=false
    EOF
  '';

  meta = with lib; {
    description = "PKHeX, a Pokémon save editor — Windows build run via Wine";
    homepage = "https://github.com/kwsch/PKHeX";
    license = licenses.unfreeRedistributable; # prebuilt binary provided by the user
    platforms = platforms.linux;
  };
}
