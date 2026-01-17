{
  stdenv,
  unzip,
  makeWrapper,
}:

stdenv.mkDerivation {
  pname = "local-gpss";
  version = "0.1.0";

  # Place your zip at ./pkgs/sources/local-gpss.zip
  src = ./sources/local-gpss.zip;

  nativeBuildInputs = [
    unzip
    makeWrapper
  ];
  dontConfigure = true;
  dontBuild = true;

  unpackPhase = ''
    mkdir src-unpacked
    cd src-unpacked
    unzip -qq "$src"
  '';

  installPhase = ''
    # Install all files to share directory
    mkdir -p "$out/share/local-gpss"
    cp -r ./* "$out/share/local-gpss/"

    # Expose the binary on PATH with working directory set to share folder
    mkdir -p "$out/bin"
    makeWrapper "$out/share/local-gpss/local-gpss" "$out/bin/local-gpss" \
      --run "cd '$out/share/local-gpss'"
  '';
}
