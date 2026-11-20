{ config, lib, ... }:
let
  cfg = config.cockpit;
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
    # The console listens on 9090 over HTTPS with a self-signed certificate.
    # `services.cockpit.openFirewall` stays false: a host reaches it through
    # `ssh -L 9090:localhost:9090`, so no management port is exposed to the LAN.
    services.cockpit = {
      enable = true;
      inherit (cfg) plugins;
    };
  };
}
