{ config, pkgs, lib, ... }:
{
  imports = [
    ../modules/base.nix
    ../modules/common-packages.nix
    ../modules/audio.nix
    ../modules/fonts.nix
    ../modules/home-manager.nix
    ../modules/wallpapers.nix
    ../modules/wayland-utils.nix
    ../modules/noctalia.nix
  ];

  # Placeholder filesystem configuration for flake evaluation.
  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/nixos-root";
    fsType = "ext4";
  };

  fileSystems."/boot" = lib.mkDefault {
    device = "/dev/disk/by-label/EFI";
    fsType = "vfat";
  };

  noctalia.enable = true;
  waylandUtils.enable = true;
  waylandUtils.sessionTarget = "umbriel-session.target";

  programs.zsh.enable = true;

  # Luciole and Nautilus link GVfs for trash, removable devices and remote
  # locations. The NixOS service wires D-Bus, FUSE and the GIO module.
  services.gvfs.enable = true;

  machines.wallpapers.enable = lib.mkDefault true;

  # Desktop apps live with the desktop, not in the shared package set.
  commonPackages.enable = true;
  commonPackages.packages = [ pkgs.chromium pkgs.spotify pkgs.zed-editor pkgs.opencode pkgs.discord ];
}
