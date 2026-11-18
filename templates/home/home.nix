{ config, pkgs, lib, ... }:
{
  # Standalone Home Manager example. On NixOS, Home Manager is integrated by
  # modules/home-manager.nix, so a host does not import this file.
  home.username = "csh"; # change if needed
  home.homeDirectory = "/home/csh"; # NixOS default path

  # State version (bump when migrating options)
  home.stateVersion = "24.11";
}
