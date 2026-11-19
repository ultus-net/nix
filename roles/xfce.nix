{ config, pkgs, lib, inputs, ... }:
{
  # Xfce desktop profile
  imports = [
    ../modules/base.nix
    ../modules/common-packages.nix
    ../modules/xfce.nix
    ../modules/home-manager.nix
    ../modules/wallpapers.nix
  ];

  # CRITICAL: Placeholder filesystem configuration for flake evaluation.
  # For real installations, you MUST replace these with your actual disk
  # configuration from nixos-generate-config --root /mnt. See INSTALL.md.
  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/nixos-root";
    fsType = "ext4";
  };

  fileSystems."/boot" = lib.mkDefault {
    device = "/dev/disk/by-label/EFI";
    fsType = "vfat";
  };

  commonPackages.enable = true;
  # Thunar is Xfce's own file manager; the browser and the music client are
  # desktop apps, so they live with the desktop rather than the shared set.
  commonPackages.packages = [ pkgs.git pkgs.curl pkgs.thunar pkgs.chromium pkgs.spotify pkgs.zed-editor pkgs.opencode pkgs.discord ];

  xfce.enable = true;
  
  # Enable NixOS wallpaper collection by default
  machines.wallpapers.enable = lib.mkDefault true;
}
