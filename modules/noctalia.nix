{ config, pkgs, lib, ... }:
let
  cfg = config.noctalia;
in
{
  options.noctalia = {
    enable = lib.mkEnableOption "the Noctalia desktop: Umbriel, the Noctalia shell, Luciole and the greeter";
  };

  config = lib.mkIf cfg.enable {
    programs.umbriel.enable = true;

    programs.noctalia = {
      enable = true;

      # Umbriel runs as a systemd user service and marks itself ready by
      # starting umbriel-session.target. Binding Noctalia to that target is
      # what orders the shell after the compositor and before autostart.
      systemd = {
        enable = true;
        target = "umbriel-session.target";
      };

      recommendedServices.enable = true;
    };

    # The Noctalia greeter is greetd-based, so it replaces SDDM entirely.
    services.displayManager.noctalia-greeter.enable = true;

    # Luciole is not in nixpkgs, so the role ships it from pkgs/.
    environment.systemPackages = [ (pkgs.callPackage ../pkgs/luciole { }) ];
  };
}
