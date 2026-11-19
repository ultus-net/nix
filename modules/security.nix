{ config, pkgs, lib, ... }:
let
  cfg = config.securityDefaults;
in
{
  # Security module: small, pragmatic defaults for desktop usage; each line
  # explains the reason for the chosen default.

  options.securityDefaults = {
    # A headless host needs neither a fingerprint daemon nor mDNS discovery,
    # so both desktop extras stay opt-in. The role that owns a desktop turns
    # them on.
    enableFprintd = lib.mkEnableOption "the fingerprint daemon";

    enableAvahi = lib.mkEnableOption "mDNS/zeroconf service discovery";
  };

  config = {
    # Fingerprint authentication, when the hardware and PAM integration exist.
    services.fprintd.enable = cfg.enableFprintd;

    # Avahi provides mDNS/zeroconf for local network discovery (printers and
    # other services). `openFirewall` relaxes the rules for that discovery.
    services.avahi = lib.mkIf cfg.enableAvahi {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };

    # Start an SSH agent in user sessions to hold private keys for
    # authentication.
    programs.ssh.startAgent = true;

    # Keep the firewall enabled by default and avoid opening extra ports here.
    networking.firewall.enable = true;

    # sops decrypts secrets at activation and needs no daemon or key material
    # in the store, so every host can carry it.
    environment.systemPackages = [ pkgs.sops ];
  };
}
