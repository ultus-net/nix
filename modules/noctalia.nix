{ config, pkgs, lib, ... }:
let
  cfg = config.noctalia;
in
{
  options.noctalia = {
    enable = lib.mkEnableOption "the Noctalia desktop role (Umbriel + Noctalia shell)";
  };

  config = lib.mkIf cfg.enable {
    programs.umbriel.enable = true;

    programs.noctalia = {
      enable = true;
      # Bind the user service to the graphical-session.target by default
      systemd.target = "graphical-session.target";
    };

    # Use the Noctalia greeter (greetd-based) rather than SDDM
    services.displayManager.noctalia-greeter.enable = true;

    # Install Luciole from the in-tree package
    environment.systemPackages = with pkgs; [ (import ../pkgs/luciole { inherit pkgs; }) ];

    # Ensure commonly-needed services are present for a desktop session
    networking.networkmanager.enable = lib.mkDefault true;
    hardware.bluetooth.enable = lib.mkDefault true;
    services.upower.enable = lib.mkDefault true;
    services.power-profiles-daemon.enable = lib.mkDefault true;
  };
}
