{ config, pkgs, lib, inputs, ... }:
{
  # KDE/Plasma 6 desktop role. Keep host specifics in `hosts/`.
  # This profile provides a modern Wayland-based desktop with SDDM display manager.
  imports = [
    ../modules/base.nix  # Import base machine config for boot/system defaults
    ../modules/common-packages.nix
    ../modules/kde.nix
    ../modules/audio.nix           # PipeWire audio stack
    ../modules/fonts.nix           # Nerd Fonts and emoji support
    ../modules/home-manager.nix
    ../modules/wallpapers.nix
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

  commonPackages.enable = true;
  commonPackages.packages = [ pkgs.git pkgs.htop pkgs.chromium pkgs.spotify pkgs.zed-editor pkgs.opencode pkgs.discord ];

  # PINCE debugger

  # KDE Plasma 6 with sensible defaults
  kde.enable = true;
  kde.enableWayland = true;
  kde.enableKDEConnectFirewall = lib.mkDefault true;
  kde.enableBluetoothManager = lib.mkDefault true;
  kde.enableKWalletPAM = lib.mkDefault true;
  kde.optimizeFonts = lib.mkDefault true;
  
  # Enable NixOS wallpaper collection by default
  machines.wallpapers.enable = lib.mkDefault true;
}
