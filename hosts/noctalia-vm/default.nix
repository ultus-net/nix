{ config, pkgs, lib, ... }:
{
  # VM-only host for previewing the Noctalia desktop without touching real
  # hardware. Not installed on hardware.
  imports = [ ../../roles/noctalia.nix ];

  networking.hostName = "noctalia-vm";

  users.users.noctalia = {
    isNormalUser = true;
    description = "Noctalia preview";
    extraGroups = [ "wheel" "video" "render" "input" ];
  };
  users.groups.noctalia = { };

  # Skip the normal greeter for the preview VM; autologin the preview user.
  services.displayManager.autoLogin = {
    enable = true;
    user = "noctalia";
  };

  # QEMU: provide a virtio GPU with virgl so Umbriel/Noctalia can render.
  virtualisation.vmVariant = {
    virtualisation = {
      memorySize = 4096;
      cores = 4;
      diskSize = 4096;
      qemu.options = [ "-vga" "none" "-device" "virtio-vga-gl" "-display" "gtk,gl=on" ];
    };
  };
}
