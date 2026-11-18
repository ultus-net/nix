{ config, lib, pkgs, ... }:
let
  cfg = config.machines.agentSandbox;

  # Values are substituted as plain text at evaluation time, so the launcher and
  # the container entry contain no reference to the project they mount.
  fill = replacements: file:
    builtins.replaceStrings (builtins.attrNames replacements) (builtins.attrValues replacements)
      (builtins.readFile file);

  # Tools the session can run. The store is mounted read-only and there is no
  # daemon socket, so this closure is fixed at build time: the session cannot
  # install anything. Add a package here and switch the host to extend it.
  toolenv = pkgs.buildEnv {
    name = "agent-sandbox-tools";
    paths = cfg.tools;
    pathsToLink = [ "/bin" ];
    ignoreCollisions = true;
  };

  rootfs = pkgs.runCommand "agent-sandbox-rootfs" { } ''
    mkdir -p $out/bin $out/etc $out/home/agent $out/run $out/tmp $out/workspace
    chmod 1777 $out/tmp
    ln -s ${pkgs.bashInteractive}/bin/bash $out/bin/sh
    ln -s ${pkgs.bashInteractive}/bin/bash $out/bin/bash

    printf '%s\n' \
      'NAME=agent-sandbox' \
      'ID=agent-sandbox' \
      'PRETTY_NAME="Agent sandbox"' \
      'VERSION_ID=1' \
      > $out/etc/os-release

    printf '%s\n' \
      'root:x:0:0:agent sandbox:/home/agent:/bin/sh' \
      > $out/etc/passwd

    printf '%s\n' 'root:x:0:' > $out/etc/group
    printf '%s\n' 'passwd: files' 'group: files' 'hosts: files' > $out/etc/nsswitch.conf
    printf '%s\n' '127.0.0.1 localhost' > $out/etc/hosts
  '';

  entry = pkgs.writeText "agent-sandbox-entry" (fill {
    "@@SOCAT@@" = "${pkgs.socat}/bin/socat";
  } ../pkgs/agent-sandbox/entry.sh);

  launcher = pkgs.writeShellApplication {
    name = "agent-sandbox";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.systemd
    ];
    text = fill {
      "@@NSPAWN@@" = "${config.systemd.package}/bin/systemd-nspawn";
      "@@MACHINECTL@@" = "${config.systemd.package}/bin/machinectl";
      "@@ROOTFS@@" = "${rootfs}";
      "@@ENTRY@@" = "${entry}";
      "@@SOCKET@@" = cfg.socketPath;
      "@@TOOLENV@@" = "${toolenv}";
      "@@CACERT@@" = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      "@@HOMESIZE@@" = cfg.homeSize;
      "@@MEMORYMAX@@" = cfg.memoryMax;
      "@@CPUQUOTA@@" = cfg.cpuQuota;
      "@@TASKSMAX@@" = toString cfg.tasksMax;
    } ../pkgs/agent-sandbox/launcher.sh;
  };

  allowlist = pkgs.writeText "agent-sandbox-allowlist" (lib.concatLines cfg.allowedHosts);

  proxy = pkgs.writeText "agent-proxy.py" (builtins.readFile ../pkgs/agent-sandbox/proxy.py);
in
{
  options.machines.agentSandbox = {
    enable = lib.mkEnableOption "the per-session agent sandbox";

    allowedHosts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        # Agent vendor APIs.
        "api.anthropic.com"
        "api.openai.com"
        # Repository and release access.
        "github.com"
        "*.github.com"
        "*.githubusercontent.com"
        "codeload.github.com"
        # Nix binary cache.
        "cache.nixos.org"
        # Package registries.
        "registry.npmjs.org"
        "pypi.org"
        "files.pythonhosted.org"
        "proxy.golang.org"
        "sum.golang.org"
        "storage.googleapis.com"
      ];
      description = ''
        Host names the session may reach through the proxy. An entry beginning
        with `*.` matches subdomains as well as the bare name. A new entry needs
        a reason recorded beside it.
      '';
    };

    allowedPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [ 443 ];
      description = ''
        Ports a CONNECT may target. Keep this at 443: an open port turns the
        proxy into a path to every service on an allowed host.
      '';
    };

    socketPath = lib.mkOption {
      type = lib.types.str;
      default = "/run/agent-sandbox/proxy.sock";
      description = "Unix socket the proxy listens on and the session mounts.";
    };

    tools = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = with pkgs; [
        bashInteractive
        cacert
        curl
        fd
        git
        gnutar
        go
        gzip
        jq
        nodejs
        python3
        ripgrep
      ];
      description = ''
        Packages whose `bin` directories the session gets on PATH. The store is
        read-only inside the sandbox, so this list is the whole toolchain: add a
        package here and switch the host rather than installing inside.
      '';
    };

    homeSize = lib.mkOption {
      type = lib.types.str;
      default = "1G";
      description = "Size of the session's tmpfs home.";
    };

    memoryMax = lib.mkOption {
      type = lib.types.str;
      default = "8G";
      description = "`MemoryMax` for the session scope.";
    };

    cpuQuota = lib.mkOption {
      type = lib.types.str;
      default = "400%";
      description = "`CPUQuota` for the session scope.";
    };

    tasksMax = lib.mkOption {
      type = lib.types.int;
      default = 4096;
      description = "`TasksMax` for the session scope.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.agent-sandbox-proxy = {
      description = "Allowlisting CONNECT proxy for the agent sandbox";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = lib.concatStringsSep " " [
          "${pkgs.python3}/bin/python3"
          proxy
          "--socket ${cfg.socketPath}"
          "--allowlist ${allowlist}"
          "--ports ${lib.concatMapStringsSep "," toString cfg.allowedPorts}"
        ];
        RuntimeDirectory = "agent-sandbox";
        RuntimeDirectoryMode = "0755";
        DynamicUser = true;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
        ];
        CapabilityBoundingSet = "";
        MemoryMax = "512M";
      };
    };

    environment.systemPackages = [ launcher ];
  };
}
