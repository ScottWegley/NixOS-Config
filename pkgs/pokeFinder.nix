{
  stdenv,
  fetchurl,
  autoPatchelfHook,
  qt6,
}:
stdenv.mkDerivation rec {
  pname = "pokeFinder";
  version = "4.3.2";

  src = fetchurl {
    url = "https://github.com/Admiral-Fish/PokeFinder/releases/download/v${version}/PokeFinder-linux.tar.gz";
    sha256 = "3OvyvvUcBO6fcvs+mAYGeItkJicCZ6aUxcpRr6DKNA0=";
  };

  sourceRoot = ".";

  nativeBuildInputs = [autoPatchelfHook qt6.wrapQtAppsHook];
  buildInputs = [qt6.qtbase qt6.qttools];

  installPhase = ''
    mkdir -p $out/bin
    mkdir -p $out/share/applications
    mkdir -p $out/share/pixmaps

    cp PokeFinder $out/bin/

    # Create desktop entry for application menu
    cat > $out/share/applications/pokeFinder.desktop << EOF
    [Desktop Entry]
    Type=Application
    Name=PokeFinder
    Comment=Pokémon RNG Finder
    Exec=$out/bin/PokeFinder
    Icon=pokeFinder
    Categories=Utility;
    Terminal=false
    EOF

    # Create a placeholder icon
    cat > $out/share/pixmaps/pokeFinder.svg << EOF
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
      <circle cx="32" cy="32" r="30" fill="#FF0000"/>
      <circle cx="32" cy="32" r="24" fill="white"/>
      <circle cx="32" cy="32" r="6" fill="#000000"/>
    </svg>
    EOF
  '';
}
