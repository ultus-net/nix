{ config, lib, ... }:
let
  cfg = config.cockpit;

  # Cockpit signs in through PAM, so an account without a password cannot
  # authenticate. Only normal users count: the system accounts have no shell.
  hasPassword = user:
    (user.hashedPassword or null) != null
    || (user.hashedPasswordFile or null) != null
    || (user.password or "") != ""
    || (user.initialPassword or null) != null;

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

    warnings = lib.optional (lib.all (user: !(hasPassword user)) normalUsers) ''
      cockpit.enable is on, but no normal account has a password. Cockpit
      authenticates through PAM, so nobody can sign in. Set
      `hashedPasswordFile` on the admin account, or turn cockpit off here.
    '';
  };
}
