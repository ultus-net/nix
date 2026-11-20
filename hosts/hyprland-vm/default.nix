{ config, pkgs, lib, ... }:
{
  # VM-only host for looking at the Hyprland desktop without touching a real
  # machine. It is not installed on hardware.
  #
  #   nix build .#nixosConfigurations.hyprland-vm.config.system.build.vm
  #   ./result/bin/run-hyprland-vm-vm
  imports = [ ../../roles/hyprland.nix ];

  networking.hostName = "hyprland-vm";

  users.users.hyprland = {
    isNormalUser = true;
    description = "Hyprland preview";
    extraGroups = [ "wheel" "video" "render" "input" ];
  };
  users.groups.hyprland = { };

  # A preview VM skips the login screen; the account has no password.
  services.displayManager.autoLogin = {
    enable = true;
    user = "hyprland";
  };

  # QEMU: virgl aborts without a host GL context, so render through Mesa's
  # software path at 1920x1080. USAGE.md has the full reasoning and the opt-in.
  virtualisation.vmVariant = {
    virtualisation = {
      memorySize = 4096;
      cores = 4;
      diskSize = 8192;
      qemu.options = [ "-vga" "none" "-device" "virtio-vga,xres=1920,yres=1080" "-display" "gtk" ];
    };
  };
}
