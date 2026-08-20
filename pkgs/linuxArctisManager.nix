{
  lib,
  python3Packages,
  fetchurl,
}:
python3Packages.buildPythonApplication rec {
  pname = "linux-arctis-manager";
  version = "2.5.0-b3";
  format = "wheel";

  src = fetchurl {
    url = "https://github.com/elegos/Linux-Arctis-Manager/releases/download/v2.5.0-beta3/linux_arctis_manager-2.5.0b3-py3-none-any.whl";
    sha256 = "c31541b6d413babbf7b414641495c885a22bb841734738a5f0fa1a9bc561597e";
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
    huggingface-hub
    requests
    vdf
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
