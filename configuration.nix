{ config, lib, pkgs, options, ... }:
{
  environment.systemPackages = [ pkgs.neovim pkgs.docker-compose ];

  services.openssh = {
    enable = true;
    permitRootLogin = "yes";
  };

  virtualisation.docker.enable = true;

  virtualisation.libvirtd = {
    enable = true;
    onBoot = "ignore";
    qemu.runAsRoot = true;
  };

  networking.firewall.allowedTCPPorts = [ 80 21 ];
  users.users.root.password = "root";
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC7Zmk5m0lxtAUQ7waVIeOPlIaM2JVnHHFjZGXYtDeN0QtpM2Bm0PU/sE+dMcwd4Wxn/tiNXjaFSFmcA3IlGW7y9H5ciqQ1mY7If2E0pXT9onLhAVZ5Ia7fRVa7BtBgVdFNk551GkfWfLEXBkrdgwms5wo5qF5VLAAu1FxHCgmBElhhLJuMMDgeoH8E7RWxi5uXscl+vY4+blA22iEY0EklKMjn2hfxt8TqJwZpdixOCJ/2YhOm3Q6zUzEn8c3/K4INPq1VyqMbqIro6G9uuvbdsZRxINMGc56XZSEG7mWlNPdr8oFUJfSvjAJ52Mxw/6HZrKG+UKnSaX4lQkpLtebMxaEgCBhm6RnlcOdLg8DVmsWXn1h9PmUDkdz4Fx970zm+BmUAGnLBoVN+qfgV6kYiEYYIpE2KIPCFIMuPSNKKkBNBWPBKvReH9jnpKkmXvcMzvgnc1Eh6Uc2rLyxSngytLecORS4bYpmggupDGAnISWXaocytKtQESG4pkEeoAqh99T7HpnCfuXNr+J63AWm7qpDYS2PlWUiCDvVhiJniWpixapLfeSUXHYvM2fDjVG4DhOgzbCbapphAFuvrmhQQnfRG9Z+gH2ox8eZc1nBHHJWFdJxGlEByHh7jyPAiZejuX5wjWqsc9V3GwoZj9EVn/Lemy1mblFnjqhD6qnM1Mw== ben@bensimms.moe"
  ];
}
