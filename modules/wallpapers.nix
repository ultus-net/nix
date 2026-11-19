{ config, pkgs, lib, ... }:

let
  cfg = config.machines.wallpapers;
  
  # Local wallpapers shipped in this repo (installed to /share/backgrounds).
  # Use the entire assets/wallpapers directory so you can add/remove images
  # without changing the module.
  localWallpapers = pkgs.stdenv.mkDerivation {
    name = "nix-local-wallpapers";
    src = ./../assets/wallpapers;
    buildCommand = ''
      mkdir -p $out/share/backgrounds/nixos
      cp -a "$src"/* $out/share/backgrounds/nixos/ || true
    '';
  };
  
in
{
  options.machines.wallpapers = {
    enable = lib.mkEnableOption "NixOS official wallpaper collection with automatic rotation";
    
    rotationInterval = lib.mkOption {
      type = lib.types.int;
      default = 300;
      description = "Time in seconds between wallpaper changes";
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Install only the local wallpapers package (from assets/wallpapers)
    environment.systemPackages = [ localWallpapers ];
    
    # Make wallpapers easily accessible via symlink
    environment.pathsToLink = [ "/share/backgrounds" ];
  };
}
