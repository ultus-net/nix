{ config, pkgs, lib, ... }:
let
  cfg = config.noctalia;
in
{
  options.noctalia = {
    enable = lib.mkEnableOption "the Noctalia desktop: Umbriel, the Noctalia shell, Luciole and the greeter";
  };

  config = lib.mkIf cfg.enable {
    # Umbriel and the shell come from the nixpkgs modules, which also ship the
    # session file, the user unit and the portal. Nothing here re-packages them.
    programs.umbriel.enable = true;

    programs.noctalia = {
      enable = true;

      # The user service ships off by default and defaults its target to
      # graphical-session.target. Umbriel starts umbriel-session.target, so
      # enable the unit and bind it to the compositor's own target.
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
