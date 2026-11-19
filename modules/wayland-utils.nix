{ config, pkgs, lib, ... }:
let
  cfg = config.waylandUtils;
in
{
  options.waylandUtils = {
    enable = lib.mkEnableOption "the Wayland session utilities a wlroots desktop needs";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      pwvucontrol    # PipeWire mixer
      playerctl      # media keys over MPRIS
      brightnessctl  # backlight keys
      cliphist       # clipboard history
      satty          # screenshot annotation
      wlr-randr      # output modes and layout on wlroots
      wf-recorder    # screen recording
    ];

    # cliphist only stores entries, so a wl-paste watcher has to feed it.
    systemd.user.services.cliphist = {
      description = "Clipboard history watcher for cliphist";
      wantedBy = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      serviceConfig.ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --watch ${pkgs.cliphist}/bin/cliphist store";
    };
  };
}
