{ config, pkgs, lib, ... }:
{
  # Work Laptop - Portable workstation with KDE and DisplayLink support
  # Hardware configuration generated from nixos-generate-config

  imports = [
    ../../modules/base.nix
    ../../roles/kde.nix
    ../../modules/auto-upgrade.nix
    ./hardware.nix
  ];

  # ============================================================================
  # Machine Identity
  # ============================================================================
  
  networking.hostName = "work-laptop";

  # Automatic updates follow origin/main, so a PR gates every change.
  machines.autoUpgrade = {
    enable = true;
    flakePath = "/home/hunter/Documents/nix";
  };

  # ============================================================================
  # Regional Settings
  # ============================================================================
  
  # Set timezone to New Zealand
  time.timeZone = "Pacific/Auckland";

  # Locale settings for New Zealand
  i18n.defaultLocale = "en_NZ.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_NZ.UTF-8";
    LC_IDENTIFICATION = "en_NZ.UTF-8";
    LC_MEASUREMENT = "en_NZ.UTF-8";
    LC_MONETARY = "en_NZ.UTF-8";
    LC_NAME = "en_NZ.UTF-8";
    LC_NUMERIC = "en_NZ.UTF-8";
    LC_PAPER = "en_NZ.UTF-8";
    LC_TELEPHONE = "en_NZ.UTF-8";
    LC_TIME = "en_NZ.UTF-8";
  };

  # ============================================================================
  # DisplayLink & Docking Station Support
  # ============================================================================
  
  # DisplayLink drivers for docking stations
  # Note: DisplayLink traditionally uses X11. For Wayland, the evdi kernel module
  # is loaded, and XWayland provides compatibility for DisplayLink displays.
  # Temporarily disabled DisplayLink - requires manual driver download from Synaptics
  # Enable DisplayLink support via the upstream NixOS hardware.video.displaylink module
  # (triggered when "displaylink" is present in services.xserver.videoDrivers).
  # services.xserver.videoDrivers = [ "modesetting" "displaylink" ];

  # Enable Thunderbolt support for Thunderbolt docking stations
  services.hardware.bolt.enable = true;

  # ============================================================================
  # User Configuration
  # ============================================================================
  
  # Primary user configuration - reuse existing hunter user with home-manager
  users.users = {
    hunter = {
      isNormalUser = true;
      description = "Hunter";
      shell = pkgs.bash;
      group = "hunter";
      extraGroups = [
        "wheel"           # sudo access
        "networkmanager"  # network configuration
        "video"           # access to video devices
        "bluetooth"       # bluetooth device management
      ];

      # IMPORTANT: Set a real password after first boot!
      # Run: sudo passwd hunter
      initialHashedPassword = lib.mkDefault "";

      openssh.authorizedKeys.keys = [
        # Add your SSH public keys here for remote access
      ];
    };
  };

  # Home Manager configuration - reusing hunter.nix
  home-manager.users.hunter = import ../../home/hunter.nix;

  # Create user group
  users.groups.hunter = {};

  # ============================================================================
  # Laptop Power Management & Optimizations
  # ============================================================================
  
  # Configure logind for proper suspend/resume handling
  # Helps the greeter restore displays properly after sleep
  services.logind = {
    lidSwitch = "suspend";
    lidSwitchDocked = "ignore";
    lidSwitchExternalPower = "suspend";
    settings = {
      Login = {
        HandlePowerKey = "suspend";
        IdleAction = "ignore";
      };
    };
  };

  # SSD TRIM support
  services.fstrim.enable = true;
  
  # Firmware updates
  services.fwupd.enable = true;

  # Disable power-profiles-daemon since we're using TLP for advanced battery management
  services.power-profiles-daemon.enable = false;

  # TLP for advanced battery management
  services.tlp = {
    enable = true;
    settings = {
      # Battery charge thresholds (if supported by hardware)
      START_CHARGE_THRESH_BAT0 = 75;
      STOP_CHARGE_THRESH_BAT0 = 80;

      # CPU scaling governors
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

      # Intel CPU energy performance policy
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

      # Disable USB autosuspend for docking station reliability
      USB_AUTOSUSPEND = 0;

      # Disable Wake-on-LAN
      WOL_DISABLE = "Y";
    };
  };

  # Intel thermal management
  services.thermald.enable = true;

  # Better desktop responsiveness
  services.system76-scheduler.enable = true;

  # ============================================================================
  # Connectivity
  # ============================================================================
  
  # Bluetooth support - enabled by default on laptop
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  hardware.bluetooth.settings = {
    General = {
      Enable = "Source,Sink,Media,Socket";
      Experimental = true;
    };
  };
  services.blueman.enable = true;

  # ============================================================================
  # Input Devices
  # ============================================================================
  
  # Touchpad configuration with libinput
  services.libinput = {
    enable = true;
    touchpad = {
      tapping = true;
      naturalScrolling = true;
      middleEmulation = true;
      disableWhileTyping = true;
    };
  };

  # ============================================================================
  # Services
  # ============================================================================
  
  # Printer support with CUPS
  services.printing.enable = true;
  
  # Avahi for network printer discovery
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # ============================================================================
  # System Packages
  # ============================================================================
  
  environment.systemPackages = with pkgs; [
    # System monitoring
    htop
    btop
    powertop
    
    # Hardware utilities
    pciutils
    usbutils
    lm_sensors

    # Thunderbolt tools
    thunderbolt

    # DisplayLink support - requires manual driver download (see nixpkgs displaylink package message)
    # displaylink

    # Bluetooth utilities
    bluez
    bluez-tools

    # Disk management
    gnome-disk-utility

    # Network tools
    networkmanagerapplet
  ];

}
