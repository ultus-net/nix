{ config, lib, ... }:
let
  cfg = config.cockpit;

  # Cockpit signs in through PAM, so the host needs at least one account that
  # can authenticate. System accounts have no shell and cannot.
  normalUsers = lib.filter (user: user.isNormalUser) (lib.attrValues config.users.users);
in
{
  options.cockpit = {
    enable = lib.mkEnableOption "the Cockpit web console";

    plugins = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = ''
        Cockpit plugins to install beside the console. A plugin needs the
        service it manages, so `cockpit-machines` needs libvirtd and
        `cockpit-podman` needs `virtualisation.podman`.
      '';
      example = lib.literalExpression "with pkgs; [ cockpit-machines cockpit-podman ]";
    };
  };

  config = lib.mkIf cfg.enable {
    # The console serves HTTPS on 9090 with a self-signed certificate, so a
    # browser warns once. `openFirewall` stays false: the way in is
    # `ssh -L 9090:localhost:9090`, and no management port reaches the LAN.
    services.cockpit = {
      enable = true;
      inherit (cfg) plugins;
      settings.WebService = {
        # Single-host console. Logging into other hosts from this one is the
        # path a cockpit-ws CVE took, so it stays off regardless of version.
        LoginTo = false;
        # TLS is mandatory. Plain HTTP would put the PAM login on the wire.
        AllowUnencrypted = false;
      };
    };

    # A host can grant a password imperatively with `passwd`, so the config
    # cannot know whether one is set. It can know that nobody exists to sign in.
    warnings = lib.optional (normalUsers == [ ]) ''
      cockpit.enable is on, but this host has no normal account. Cockpit
      authenticates through PAM, so there is nobody to sign in as. Add the
      admin account, or turn cockpit off here.
    '';
  };
}
