{ config, pkgs, lib, ... }:
{
  # Dux Shell desktop role. Dux Shell runs on the Hyprland compositor here,
  # because modules/dux.nix wires the two together.
  imports = [
    ../modules/base.nix
    ../modules/common-packages.nix
    ../modules/audio.nix
    ../modules/fonts.nix
    ../modules/home-manager.nix
    ../modules/wallpapers.nix
    ../modules/dux.nix
  ];

  # CRITICAL: Placeholder filesystem configuration for flake evaluation.
  # For real installations, replace these with your actual disk configuration
  # from `nixos-generate-config --root /mnt`.
  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/nixos-root";
    fsType = "ext4";
  };

  fileSystems."/boot" = lib.mkDefault {
    device = "/dev/disk/by-label/EFI";
    fsType = "vfat";
  };

  dux.enable = true;

  programs.zsh.enable = true;

  machines.wallpapers.enable = lib.mkDefault true;

  commonPackages.enable = true;
  commonPackages.packages = [ pkgs.git pkgs.curl ];
}
