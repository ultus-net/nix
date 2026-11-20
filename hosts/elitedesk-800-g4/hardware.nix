# HP EliteDesk 800 G4 Mini. Coffee Lake, Intel UHD 630, I219-LM NIC, no dGPU
# and no battery. Not generated output: the machine is not installed yet, so
# the two file systems use the label convention this repo already installs
# with. Replace them with real UUIDs from `nixos-generate-config` at install.
{ lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usbhid" "uas" "sd_mod" ];
  boot.kernelModules = [ "kvm-intel" ];

  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/nixos-root";
    fsType = "ext4";
  };

  fileSystems."/boot" = lib.mkDefault {
    device = "/dev/disk/by-label/EFI";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  swapDevices = [ ];

  hardware.cpu.intel.updateMicrocode = true;

  # Mesa drives the UHD 630, and iHD gives it VA-API decode. There is no
  # NVIDIA hardware here, so `modules/nvidia.nix` must not be imported.
  hardware.graphics = {
    enable = lib.mkDefault true;
    extraPackages = [ pkgs.intel-media-driver ];
  };
}
