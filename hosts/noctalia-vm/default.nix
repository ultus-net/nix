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

  # The preview VM skips the greeter. `services.displayManager.autoLogin` only
  # drives SDDM and GDM, and this role logs in through greetd, so the session
  # starts from greetd's initial_session instead.
  services.greetd.settings.initial_session = {
    command = "${config.programs.umbriel.package}/bin/start-umbriel";
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
