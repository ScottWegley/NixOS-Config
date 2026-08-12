{hostName, ...}: {
  networking.hostName = hostName;

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      8080 # http https
      80
      443
      3389 # rdp
    ];
  };

  networking.networkmanager.enable = true;
}
