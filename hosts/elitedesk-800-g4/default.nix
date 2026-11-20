{ pkgs, ... }:
{
  # HP EliteDesk 800 G4 Mini, used two ways: a desktop test rig and a small dev
  # server. The role import is the swappable line, so
  # `scripts/switch-desktop.sh <desktop> elitedesk-800-g4` changes the desktop
  # and leaves the server services below in place.

  # A desktop role replaces `roles/base.nix` and imports none of the server
  # modules below, so the ones that must survive a swap are imported here. The
  # module system dedupes the overlap with the base role.
  imports = [
    ./hardware.nix
    ../../roles/base.nix
    ../../modules/security.nix
    ../../modules/networking.nix
    ../../modules/zram.nix
    ../../modules/cockpit.nix
    ../../modules/virtualization.nix
    ../../modules/containers.nix
  ];

  networking.hostName = "elitedesk";

  # The console is reachable over an SSH tunnel; the firewall stays closed.
  # `cockpit-machines` drives libvirtd and `cockpit-podman` drives the rootless
  # Podman socket that `virtualisation.podman` starts.
  cockpit.enable = true;
  cockpit.plugins = with pkgs; [
    cockpit-machines
    cockpit-podman
  ];

  virtualization.enable = true;

  # Podman rather than Docker: this machine is greenfield, so there is nothing
  # to migrate, and Podman needs no daemon. `dockerCompat` keeps `docker` and
  # compose invocations working for anything that assumes the Docker CLI.
  machines.containers.enable = true;
  machines.containers.runtime = "podman";
  machines.containers.enableDockerCompose = true;

  # `roles/base.nix` sets these, but a desktop role replaces that import, so
  # the host keeps them.
  machines.zram.enableAutoSize = true;
  machines.zram.maxSize = 4294967296; # 4GiB max

  users.users = {
    hunter = {
      isNormalUser = true;
      description = "Hunter";
      shell = pkgs.zsh;
      group = "hunter";
      extraGroups = [
        "wheel"
        "networkmanager"
        "podman"          # the Podman socket, which also serves /run/docker.sock
        "libvirtd"
        "kvm"
      ];

      # No password hash is committed. Before the first switch, add an SSH key
      # below, so there is a way in without a console. The account otherwise
      # starts locked, and Cockpit signs in through PAM, so set the first
      # password at the machine with `sudo passwd hunter`.

      openssh.authorizedKeys.keys = [
        # Add your SSH public keys here
      ];
    };
  };

  users.groups.hunter = { };

  # The account's shell. A desktop role also sets this, so it survives a swap
  # in either direction.
  programs.zsh.enable = true;
}
