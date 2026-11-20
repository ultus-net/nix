{ config, pkgs, lib, ... }:
let
  cfg = config.machines.containers;
in {
  options.machines.containers = {
    enable = lib.mkEnableOption "Enable container and virtualization tools (opt-in)";

    runtime = lib.mkOption {
      type = lib.types.enum [ "docker" "podman" ];
      default = "docker";
      description = ''
        Container runtime. `docker` keeps the existing compose workflow.
        `podman` is daemonless, and this module gives it the `docker` alias
        and the Docker socket so existing invocations keep working.
      '';
    };

    enableDistrobox = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install distrobox for running other Linux distributions in containers";
    };
    
    enableKubernetes = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Install Kubernetes tools (kubectl, k9s, helm)";
    };
    
    enableDockerCompose = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Install a compose implementation: `docker-compose` on the Docker
        runtime, `podman-compose` on Podman.
      '';
    };
    
    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      description = "Additional container-related packages to install";
    };
  };

  config = lib.mkIf cfg.enable {
    # One runtime at a time. The nixpkgs modules assert that the Docker socket
    # and Docker itself are not both served, so the runtime selects both.
    virtualisation.docker.enable = cfg.runtime == "docker";

    virtualisation.podman = lib.mkIf (cfg.runtime == "podman") {
      enable = true;
      dockerCompat = true;
      # `/run/docker.sock` as a symlink to the Podman socket, so tools that
      # hardcode the Docker path keep working. The socket answers as root, so
      # membership of the `podman` group is root-equivalent, exactly as
      # membership of `docker` is.
      dockerSocket.enable = true;
    };
    
    # Enable container networking
    virtualisation.containers.enable = true;
    
    environment.systemPackages = with pkgs; [
      # Core container tools
    ] ++ lib.optionals (cfg.runtime == "docker") [
      docker
    ] ++ lib.optionals cfg.enableDockerCompose [
      (if cfg.runtime == "podman" then podman-compose else docker-compose)
    ] ++ lib.optionals cfg.enableDistrobox [
      distrobox
      boxbuddy     # Distrobox GUI
    ] ++ lib.optionals cfg.enableKubernetes [
      kubectl
      k9s          # Kubernetes TUI
      helm         # Kubernetes package manager
      kubectx      # Switch between clusters
      kustomize    # Kubernetes config management
    ] ++ cfg.extraPackages;
  };
}
