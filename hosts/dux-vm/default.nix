{ config, pkgs, lib, ... }:
{
  # VM-only host for looking at the Dux Shell desktop without touching a real
  # machine. It is not installed on hardware.
  #
  #   nix build .#nixosConfigurations.dux-vm.config.system.build.vm
  #   ./result/bin/run-dux-vm-vm
  imports = [ ../../roles/dux.nix ];

  networking.hostName = "dux-vm";

  users.users.dux = {
    isNormalUser = true;
    description = "Dux Shell preview";
    extraGroups = [ "wheel" "video" "render" "input" ];
  };
  users.groups.dux = { };

  # A preview VM skips the login screen; the account has no password.
  services.displayManager.autoLogin = {
    enable = true;
    user = "dux";
  };

  # QEMU has no GPU. A plain virtio GPU still gives the guest a DRM node, and
  # Mesa renders through llvmpipe on it. Virgl needs a host GL context, and QEMU
  # aborts without one, so the preview would never reach the desktop. xres/yres
  # set the preferred mode, since QEMU defaults to 1280x800.
  virtualisation.vmVariant = {
    virtualisation = {
      memorySize = 4096;
      cores = 4;
      diskSize = 4096;
      qemu.options = [ "-vga" "none" "-device" "virtio-vga,xres=1920,yres=1080" "-display" "gtk" ];
    };
  };
}
