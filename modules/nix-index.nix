{ config, pkgs, lib, ... }:
let
  cfg = config.nixIndex;

  # Both the writer and the probe name this path, because `nix-index` defaults
  # to it and a probe on any other path would rebuild on every run. It is
  # pinned rather than derived from `XDG_CACHE_HOME`, so a host that moves its
  # cache cannot silently break the contract. `%h` is the systemd user specifier
  # for the home directory; the shell script gets `$HOME` from the user manager.
  cacheDir = "%h/.cache/nix-index";

  # systemd has no guaranteed PATH for user units, so the probe calls `find` by
  # store path. Exit 0 runs the rebuild, exit 1 skips it.
  staleProbe = pkgs.writeShellScript "nix-index-stale" ''
    set -eu
    db="$HOME/.cache/nix-index/files"
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
        nixpkgs tree to index, passed to `nix-index -f`. The default is the
        tree this host was built from, so the index matches the packages the
        host can install and no `<nixpkgs>` channel is needed. A host on a
        fixed channel can point this at its channel path instead.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # `programs.nix-index` supplies `nix-locate` and the shell hook. The hook
    # reads `~/.cache/nix-index/files`; without that file it reports every miss
    # as not found, so this module is what makes the option useful.
    programs.nix-index.enable = true;

    systemd.user.services.nix-index-update = {
      description = "Rebuild the nix-index file database";
      serviceConfig = {
        Type = "oneshot";
        ExecCondition = "${staleProbe}";
        ExecStart = "${pkgs.nix-index}/bin/nix-index -d ${cacheDir} -f ${cfg.nixpkgs}";
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
