{ config, pkgs, lib, ... }:
{
  imports = [
    ../modules/base.nix
    ../modules/common-packages.nix
    ../modules/audio.nix
    ../modules/fonts.nix
    ../modules/home-manager.nix
    ../modules/wallpapers.nix
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

  programs.zsh.enable = true;

  machines.wallpapers.enable = lib.mkDefault true;

  commonPackages.enable = true;
}
