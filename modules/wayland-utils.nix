{ config, pkgs, lib, ... }:
let
  cfg = config.waylandUtils;
in
{
  options.waylandUtils = {
    enable = lib.mkEnableOption "the Wayland session utilities a wlroots desktop needs";

    sessionTarget = lib.mkOption {
      type = lib.types.str;
      default = "graphical-session.target";
      description = ''
        The systemd user target the compositor starts. The clipboard watcher
        binds to this target, so it must name the real one.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      wl-clipboard   # Wayland clipboard CLI
      pwvucontrol    # PipeWire mixer
      playerctl      # media keys over MPRIS
      brightnessctl  # backlight keys
      cliphist       # clipboard history
      satty          # screenshot annotation
      wlr-randr      # output modes and layout on wlroots
      wf-recorder    # screen recording
    ];

    # cliphist only stores entries, so a wl-paste watcher has to feed it. A
    # watcher bound to the wrong target never starts, and one that dies leaves
    # clipboard history silently off for the rest of the session.
    systemd.user.services.cliphist = {
      description = "Clipboard history watcher for cliphist";
      wantedBy = [ cfg.sessionTarget ];
      partOf = [ cfg.sessionTarget ];
      serviceConfig = {
        ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --watch ${pkgs.cliphist}/bin/cliphist store";
        Restart = "on-failure";
        RestartSec = 2;
      };
    };
  };
}
