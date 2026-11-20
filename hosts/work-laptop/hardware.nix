# Dell Pro 14 PC14250. Core Ultra 7 255U (Arrow Lake-U), 32 GB, Intel graphics
# on i915. The disk keeps a bootc slot on p3 and gives NixOS a new p4, so
# NixOS names p4 by label: one file survives a reinstall of that volume, and
# the ESP is the existing one the bootc slot also uses.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # The NVMe sits behind Intel VMD and enumerates in a VMD domain, so vmd must
  # load before nvme or the machine stops in an emergency shell.
  boot.initrd.availableKernelModules = [ "vmd" "nvme" "xhci_pci" "thunderbolt" "usbhid" "usb_storage" "uas" "sd_mod" ];
  boot.kernelModules = [ "kvm-intel" "dell_laptop" "dell_wmi" ];

  # Arrow Lake needs a kernel newer than the default channel.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # i915 is the verified driver. Blacklisting xe pins that choice on kernels
  # that also carry the alternate driver; remove it once xe is tested here.
  boot.blacklistedKernelModules = [ "xe" ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = [ "subvol=@root" "compress=zstd:1" "noatime" "ssd" "discard=async" ];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = [ "subvol=@home" "compress=zstd:1" "noatime" "ssd" "discard=async" ];
  };

  # The store is needed before the rest of the fstab mounts.
  fileSystems."/nix" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = [ "subvol=@nix" "compress=zstd:1" "noatime" "ssd" "discard=async" ];
    neededForBoot = true;
  };

  # Generations live on p4, never on the 600M ESP the bootc slot shares.
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = [ "subvol=@boot" "compress=zstd:1" "noatime" "ssd" "discard=async" ];
  };

  # The ESP predates this install and bootupd owns \EFI\fedora\, so NixOS adds
  # only \EFI\nixos\ here.
  fileSystems."/boot/efi" = {
    device = "/dev/disk/by-uuid/533B-75BD";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  # No disk swap: zram covers it, and hibernation is not configured.
  swapDevices = [ ];

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # The AX211 Wi-Fi and the i915 GuC/HuC blobs live outside the
  # redistributable subset.
  hardware.enableAllFirmware = true;

  # Mesa drives the integrated GPU, iHD gives VA-API decode, and the VPL
  # runtime covers encode. There is no dGPU, so `modules/nvidia.nix` must not
  # be imported.
  hardware.graphics = {
    enable = true;
    extraPackages = [ pkgs.intel-media-driver pkgs.vpl-gpu-rt ];
  };
}
