{ config, lib, ... }:
let
  cfg = config.machines.autoUpgrade;
in
{
  options.machines.autoUpgrade = {
    enable = lib.mkEnableOption "weekly auto-upgrade from a reviewed remote commit";

    flakePath = lib.mkOption {
      type = lib.types.str;
      description = ''
        Local checkout of this flake. The unit pulls `ref` into this directory
        and rebuilds the host from the pinned lock file.
      '';
      example = "/home/hunter/Documents/nix";
    };

    ref = lib.mkOption {
      type = lib.types.str;
      default = "main";
      description = "Remote branch to follow. Only merged commits reach a host.";
    };

    dates = lib.mkOption {
      type = lib.types.str;
      default = "weekly";
      description = "systemd calendar expression for the upgrade timer.";
      example = "daily";
    };
  };

  config = lib.mkIf cfg.enable {
    # One updater. `system.autoUpgrade` rebuilds the host from the lock file;
    # the preStart hook brings the checkout to the reviewed remote commit.
    # Input updates stay manual, so a lock-file change is reviewed like code.
    system.autoUpgrade = {
      enable = true;
      inherit (cfg) dates;
      flake = "${cfg.flakePath}#${config.networking.hostName}";
      flags = [ "--no-update-lock-file" ];
      allowReboot = false;
    };

    systemd.services.nixos-upgrade.preStart = ''
      git -c safe.directory=${lib.escapeShellArg cfg.flakePath} -C ${lib.escapeShellArg cfg.flakePath} fetch --quiet origin ${lib.escapeShellArg cfg.ref}
      git -c safe.directory=${lib.escapeShellArg cfg.flakePath} -C ${lib.escapeShellArg cfg.flakePath} merge --ff-only FETCH_HEAD
    '';
  };
}
