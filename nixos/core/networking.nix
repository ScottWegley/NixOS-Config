{hostName, ...}: {
  networking.hostName = hostName;

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      8080
      80
      443
      53317
    ];
  };

  networking.networkmanager.enable = true;
}
