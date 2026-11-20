{ config, pkgs, lib, ... }:
let
  cfg = config.nixIndex;

  # systemd does not expand `$HOME` in ExecCondition, and the user manager has
  # no guaranteed PATH, so the probe resolves the cache directory itself and
  # calls `find` by store path.
  staleProbe = pkgs.writeShellScript "nix-index-stale" ''
    set -eu
    db="''${XDG_CACHE_HOME:-$HOME/.cache}/nix-index/files"
    if [ ! -e "$db" ]; then
      exit 0
    fi
    if [ -n "$(${pkgs.findutils}/bin/find "$db" -newermt "-${toString cfg.maxAgeDays} days" -print -quit)" ]; then
      exit 1
    fi
    exit 0
  '';
in
{
  options.nixIndex = {
    enable = lib.mkEnableOption "a local nixpkgs file index for `nix-locate` and command-not-found";

    maxAgeDays = lib.mkOption {
      type = lib.types.int;
      default = 6;
      description = ''
        Age after which the daily probe rebuilds the index. A rebuild evaluates
        all of nixpkgs and fetches a narinfo for every store path, so the probe
        runs daily and the rebuild stays weekly in practice.
      '';
    };

    nixpkgs = lib.mkOption {
      type = lib.types.path;
      default = pkgs.path;
      defaultText = lib.literalExpression "pkgs.path";
      description = ''
        nixpkgs tree to index. Defaults to the tree this host was built from,
        so the index matches the packages the host can actually install.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # `programs.nix-index` supplies `nix-locate` and the shell hook. The hook
    # reads the cache this module maintains; without the cache it reports every
    # miss as not found.
    programs.nix-index.enable = true;

    systemd.user.services.nix-index-update = {
      description = "Rebuild the nix-index file database";
      serviceConfig = {
        Type = "oneshot";
        ExecCondition = "${staleProbe}";
        ExecStart = "${pkgs.nix-index}/bin/nix-index -f ${cfg.nixpkgs}";
        Nice = 19;
        IOSchedulingClass = "idle";
      };
    };

    # A daily probe costs one `find`. The probe is what keeps the rebuild
    # bounded: it fires only when the cache is missing or older than
    # `maxAgeDays`.
    systemd.user.timers.nix-index-update = {
      description = "Daily probe for a stale nix-index cache";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        RandomizedDelaySec = "1h";
        Persistent = true;
      };
    };
  };
}
