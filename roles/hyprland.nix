{ config, pkgs, lib, ... }:
{
  # Hyprland desktop profile (Omarchy-style, opinionated)
  #
  # This profile enables the Hyprland desktop environment with Omarchy-inspired modular config.
  #
  # NOTE: This requires hyprland.nix to be present in the workspace.

  imports = [
    ../modules/base.nix
    ../modules/common-packages.nix
    ../modules/home-manager.nix
    ../modules/wallpapers.nix
    ../modules/wayland-utils.nix
    ../modules/hyprland.nix
  ];

  # CRITICAL: Placeholder filesystem configuration for flake evaluation.
  # For real installations, you MUST replace these with your actual disk
  # configuration from `nixos-generate-config --root /mnt`. See INSTALL.md.
  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/nixos-root";
    fsType = "ext4";
  };

  fileSystems."/boot" = lib.mkDefault {
    device = "/dev/disk/by-label/EFI";
    fsType = "vfat";
  };


  # Enable Hyprland desktop
  hyprland.enable = true;
  waylandUtils.enable = true;
  waylandUtils.sessionTarget = "hyprland-session.target";

  # Ensure zsh is enabled if set as default shell
  programs.zsh.enable = true;

  # Nautilus links GVfs for trash, removable devices and remote locations.
  services.gvfs.enable = true;

  # Enable NixOS wallpaper collection by default
  machines.wallpapers.enable = lib.mkDefault true;

  # Desktop apps live with the desktop, not in the shared package set.
  commonPackages.enable = true;
  commonPackages.packages = [ pkgs.git pkgs.curl pkgs.chromium pkgs.spotify pkgs.zed-editor pkgs.opencode pkgs.discord ];
}
