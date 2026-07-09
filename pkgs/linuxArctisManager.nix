{
  lib,
  python3Packages,
  fetchurl,
}:
python3Packages.buildPythonApplication rec {
  pname = "linux-arctis-manager";
  version = "2.4.1";
  format = "wheel";

  src = fetchurl {
    url = "https://github.com/elegos/Linux-Arctis-Manager/releases/download/v${version}/linux_arctis_manager-${version}-py3-none-any.whl";
    hash = "sha256-DsuYzuygAJlaqaVN577LzF0sK17fG4bBKk2ZtIREtcs=";
  };

  nativeBuildInputs = [
    python3Packages.wheel
  ];

  propagatedBuildInputs = with python3Packages; [
    dbus-next
    pulsectl
    pyside6
    pyudev
    pyusb
    ruamel-yaml
  ];

  pythonRelaxDeps = ["pyside6"];

  meta = with lib; {
    description = "Open-source replacement for SteelSeries GG to manage Arctis headsets on Linux.  Use lam-gui --no-enforce-systemd.";
    homepage = "https://github.com/elegos/Linux-Arctis-Manager";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [];
    platforms = platforms.linux;
  };
}
