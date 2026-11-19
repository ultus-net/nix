{ config, pkgs, lib, ... }:
let
  cfg = config.dux;
in
{
  options.dux = {
    enable = lib.mkEnableOption "the Dux Shell desktop on Hyprland";
  };

  config = lib.mkIf cfg.enable {
    # Dux Shell is the renamed DankMaterialShell. It provides the bar,
    # launcher and session UI; Hyprland is the compositor underneath.
    programs.hyprland.enable = true;

    programs.dux-shell = {
      enable = true;

      # Hyprland 0.57 starts hyprland-session.target itself. Without UWSM it
      # never starts graphical-session.target, so the unit would stay idle.
      systemd.target = "hyprland-session.target";
    };

    # SDDM's Wayland mode needs a greeter compositor. The X11 greeter works
    # everywhere and leaves the Wayland session itself untouched.
    services.xserver.enable = true;
    services.displayManager = {
      sddm.enable = true;
      defaultSession = "hyprland";
    };

    environment.systemPackages = with pkgs; [
      kitty # Hyprland's example config binds its terminal to kitty
      nautilus
      firefox
      brightnessctl
      playerctl
    ];
  };
}
