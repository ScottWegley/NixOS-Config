{
  stdenv,
  lib,
  fetchurl,
  makeWrapper,
  makeDesktopItem,
  copyDesktopItems,
  autoPatchelfHook,

  # Runtime libraries for the bundled Chromium build
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  gtk3,
  libGL,
  libx11,
  libxscrnsaver,
  libxcomposite,
  libxcursor,
  libxdamage,
  libxext,
  libxfixes,
  libxi,
  libxrandr,
  libxrender,
  libxtst,
  libdrm,
  libgbm,
  libpulseaudio,
  libxcb,
  libxkbcommon,
  mesa,
  nspr,
  nss,
  pango,
  pipewire,
  systemd,
  vulkan-loader,
  wayland,
  libxshmfence,
  libuuid,
}:

stdenv.mkDerivation rec {
  pname = "helium";
  version = "0.17.2.1";

  src = fetchurl {
    url = "https://github.com/imputnet/helium-linux/releases/download/${version}/helium-${version}-x86_64_linux.tar.xz";
    sha256 = "2a639df54e3d05f413cfbb4622a4d1a68584b31da5a7aaf58ee3cd83c7c3e299";
  };

  nativeBuildInputs = [
    makeWrapper
    copyDesktopItems
    autoPatchelfHook
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    libGL
    libx11
    libxscrnsaver
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxrandr
    libxrender
    libxtst
    libdrm
    libgbm
    libpulseaudio
    libxcb
    libxkbcommon
    mesa
    nspr
    nss
    pango
    pipewire
    systemd
    vulkan-loader
    wayland
    libxshmfence
    libuuid
  ];

  # The Chromium build bundles its own Qt libraries; ignore the rest.
  autoPatchelfIgnoreMissingDeps = [
    "libQt6Core.so.6"
    "libQt6Gui.so.6"
    "libQt6Widgets.so.6"
    "libQt5Core.so.5"
    "libQt5Gui.so.5"
    "libQt5Widgets.so.5"
  ];

  dontWrapQtApps = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/opt/helium
    cp -r * $out/opt/helium/

    # The binary is named 'helium' as of version 0.8.3.1
    makeWrapper $out/opt/helium/helium $out/bin/helium \
      --add-flags "--ozone-platform-hint=auto" \
      --add-flags "--enable-features=WaylandWindowDecorations" \
      --add-flags "--disable-component-update" \
      --add-flags "--simulate-outdated-no-au='Tue, 31 Dec 2099 23:59:59 GMT'" \
      --add-flags "--check-for-update-interval=0" \
      --add-flags "--disable-background-networking"

    # App icon for the desktop entry
    mkdir -p $out/share/icons/hicolor/256x256/apps
    cp $out/opt/helium/product_logo_256.png $out/share/icons/hicolor/256x256/apps/helium.png

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "helium";
      exec = "helium %U";
      icon = "helium";
      desktopName = "Helium";
      genericName = "Web Browser";
      comment = "Private, fast, and honest web browser";
      categories = [ "Network" "WebBrowser" ];
      terminal = false;
      mimeTypes = [
        "text/html"
        "text/xml"
        "application/xhtml+xml"
        "x-scheme-handler/http"
        "x-scheme-handler/https"
      ];
    })
  ];

  meta = with lib; {
    description = "Private, fast, and honest web browser";
    homepage = "https://helium.computer/";
    license = licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = "helium";
  };
}
