{ config, pkgs, lib, ... }:
let
  cfg = config.securityDefaults;
in
{
  # Security defaults shared by every host. The two desktop extras are opt-in,
  # because a headless host needs neither.
  options.securityDefaults = {
    enableFprintd = lib.mkEnableOption "the fingerprint daemon";

    enableAvahi = lib.mkEnableOption "mDNS/zeroconf service discovery";
  };

  config = {
    services.fprintd.enable = cfg.enableFprintd;

    # `openFirewall` relaxes the rules for printer and device discovery.
    services.avahi = lib.mkIf cfg.enableAvahi {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };

    programs.ssh.startAgent = true;

    networking.firewall.enable = true;

    # sops decrypts at activation and needs no daemon or key material in the
    # store, so every host can carry it.
    environment.systemPackages = [ pkgs.sops ];
  };
}
