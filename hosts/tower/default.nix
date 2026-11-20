{ config, pkgs, lib, ... }:
{
  # Tower - Main home workstation with full feature set

  imports = [
    ../../modules/base.nix
    ./hardware.nix

    # Desktop environment - Switched to Noctalia for the noctalia desktop
    ../../roles/noctalia.nix

    # Hardware modules
    ../../modules/nvidia.nix
    ../../modules/pince.nix

    # Security module can now be safely imported with KDE
    ../../modules/security.nix

    # All optional feature modules
    ../../modules/development.nix
    ../../modules/gaming.nix
    ../../modules/multimedia.nix
    ../../modules/sysadmin.nix
    ../../modules/nix-index.nix
    ../../modules/virtualization.nix
    ../../modules/containers.nix
    ../../modules/auto-upgrade.nix
    ../../modules/agent-sandbox.nix
    ../../modules/deploy-config.nix
    # NOTE: zram.nix is already imported via modules/base.nix
  ];

  # Agent sessions run in a transient container: no host home, no daemon
  # socket, and egress only through the allowlisting proxy.
  machines.agentSandbox.enable = true;

  # Machine identity
  networking.hostName = "tower";

  # Set timezone to New Zealand
  time.timeZone = "Pacific/Auckland";

  # Automatically mount the dedicated games drive
  fileSystems."/games" = {
    device = "/dev/disk/by-uuid/23fa1b43-1a18-48d6-ad19-6ce94dce6333";
    fsType = "ext4";
    # Make the volume show up clearly in GUI file managers
    options = [
      "x-gvfs-show"        # show as a drive in GVFS-based file managers
      "x-gvfs-name=Games"  # display name "Games" in the sidebar
      "noatime"            # SSD optimization
      "nodiratime"         # SSD optimization
      "discard"            # Enable TRIM support
      "nofail"             # boot without the game drive attached
      "commit=60"          # Write to disk every 60s (better for gaming loads)
    ];
  };

  # Kernel modules (uinput and I2C/SMBus for OpenRGB, AMD P-State for performance)
  boot.kernelModules = [
    "uinput"
    "i2c-dev"
    "i2c-piix4"  # common on AMD chipsets
    "i2c-i801"   # common on Intel chipsets
    "fuse"       # FUSE for AppImage mounting
    "amd_pstate_epp"  # AMD P-State EPP driver for Zen 4 performance
  ];

  # Boot optimizations
  boot.loader.timeout = 3; # Faster boot menu timeout (default is 5s)
  
  # Use tmpfs for /tmp (faster, saves SSD writes)
  boot.tmp.useTmpfs = true;
  boot.tmp.tmpfsSize = "50%"; # Use up to 50% of RAM for /tmp
  
  # Systemd journal size limits (prevent excessive disk usage)
  services.journald.settings.Journal = {
    SystemMaxUse = "500M";
    SystemMaxFileSize = "50M";
    MaxRetentionSec = "1week";
  };

  # PINCE is a game-memory debugger; it needs ptrace, so it is host-scoped.
  pince.enable = true;

  # Primary user configuration
  users.users = {
    hunter = {
      isNormalUser = true;
      description = "Hunter";
      shell = pkgs.zsh;
      group = "hunter";  # Primary group
      extraGroups = [
        "wheel"           # sudo access
        "networkmanager"  # network configuration
        "video"           # access to video devices
        "audio"           # access to audio devices
        "docker"          # docker access
        "libvirtd"        # VM management
        "kvm"             # KVM access
        "i2c"             # access to /dev/i2c-* devices
        "bluetooth"       # bluetooth device management
        "wireshark"       # unprivileged packet capture via the dumpcap wrapper
      ];

      # No password hash is committed. The account starts locked; set the
      # first password on the console with `sudo passwd hunter` after the first
      # switch. CI fails if a committed hash reappears outside hosts/example.

      openssh.authorizedKeys.keys = [
        # Add your SSH public keys here
      ];
    };
  };

  # Home Manager configuration
  home-manager.users.hunter = import ../../home/hunter.nix;

  # Create user group
  users.groups.hunter = {};

  # Enable all optional feature modules
  gaming.enable = true;
  gaming.enableSteam = true;  # Use native Steam via NixOS module
  gaming.optimizeSteamIO = true;  # Enable I/O optimizations for Steam cloud sync
  gaming.kernelTuning = true;    # Gaming kernel/network tuning, opt-in
  multimedia.enable = true;
  virtualization.enable = true;
  machines.containers.enable = true;
  machines.containers.enableDockerCompose = true;

  # Desktop security extras: fingerprint login and mDNS discovery. The
  # headless role leaves both off, so tower opts in explicitly.
  securityDefaults.enableFprintd = true;
  securityDefaults.enableAvahi = true;

  # PC/SC, the udev rules and the manager binary in one option, rather than a
  # bare package that cannot talk to the YubiKey.
  programs.yubikey-manager.enable = true;

  # Backup, network diagnostics and hardware monitoring. The module already
  # carries the package lists, so this host does not repeat them.
  sysadmin.enable = true;

  # Offline `nix-locate` and command-not-found. The daily probe rebuilds the
  # index only when it is older than a week.
  nixIndex.enable = true;

  # GPU fan curves and monitoring for the RTX 3070.
  services.lact.enable = true;

  # Configuration deployment helper
  deployConfig.enable = true;

  # Automatic updates follow origin/main, so a PR gates every change.
  machines.autoUpgrade = {
    enable = true;
    flakePath = "/home/hunter/Documents/nix";
  };

  # Gamemode for automatic performance boosting in games
  programs.gamemode = {
    enable = true;
    settings = {
      general = {
        renice = 10; # Prioritize games
      };
      gpu = {
        apply_gpu_optimisations = "accept-responsibility";
        gpu_device = 0; # Primary GPU (RTX 3070)
        amd_performance_level = "high"; # For AMD iGPU if used
      };
      custom = {
        start = "${pkgs.libnotify}/bin/notify-send 'GameMode Started'";
        end = "${pkgs.libnotify}/bin/notify-send 'GameMode Ended'";
      };
    };
  };
  
  # Enhanced NVIDIA settings for RTX 3070 gaming
  hardware.nvidia = {
    # Enable nvidia-settings GUI
    nvidiaSettings = true;
    
    # Force full composition pipeline off for lower latency
    forceFullCompositionPipeline = false;
    
    # Enable power management for better performance/power balance
    powerManagement.enable = true;
    powerManagement.finegrained = false;  # Not supported on RTX 3070
  };

  # Enable NixOS official wallpaper collection with rotation
  machines.wallpapers.enable = true;
  machines.wallpapers.rotationInterval = 300;  # 5 minutes

  # ========================================================================
  # PERFORMANCE OPTIMIZATIONS
  # ========================================================================
  # 
  # Hardware: AMD Ryzen 5 7600 (6C/12T), RTX 3070, 30GB RAM, NVMe + SSD
  # Focus: Gaming, multitasking, low latency, high throughput
  # 
  # Key optimizations:
  # - AMD Zen 4 specific: P-State EPP, preferred core, optimized C-states
  # - 50% zram (~15GB) for efficient memory compression
  # - IRQ balancing for multi-core efficiency
  # - Enhanced network buffers for gaming/streaming
  # - NVMe-optimized I/O and memory management
  # - Reduced swap (4GB disk + 15GB zram) with 30GB RAM
  # - Performance CPU governor with frequency boost
  # - System76 scheduler + GameMode integration
  # ========================================================================
  
  # Enable zram for better swap performance and reduced SSD wear
  # Uses official NixOS zramSwap module instead of custom implementation
  zramSwap = {
    enable = true;
    algorithm = "zstd";       # Better compression ratio than lz4
    memoryPercent = 50;       # Use 50% of RAM (~15GB on 30GB system) - you have plenty
    priority = 100;           # Higher priority than disk swap
  };

  # Hardware-specific kernel parameters. Gaming tuning (watchdog, THP,
  # C-states, I/O scheduler, BBR and the vm/net sysctls) lives in
  # modules/gaming.nix behind gaming.kernelTuning.
  boot.kernelParams = [
    "amd_pstate=active"    # AMD P-State EPP driver for power/perf
    "amd_prefcore=enable"  # Preferred core ranking
    "amd_iommu=on"
    "iommu=pt"             # Pass-through mode for VMs
  ];

  # PINCE is enabled on this host, so system-wide ptrace attach stays available.
  boot.kernel.sysctl."kernel.yama.ptrace_scope" = 0;

  # Filesystem optimizations for SSDs
  # These options are merged with hardware.nix
  fileSystems."/".options = [ "noatime" "nodiratime" "discard" "commit=60" ];
  
  # For FAT /boot partition, only add noatime (preserve fmask/dmask from hardware.nix)
  fileSystems."/boot".options = lib.mkAfter [ "noatime" ];

  # Swap file as fallback (zram handles primary swap needs)
  # With 30GB RAM + 15GB zram, disk swap rarely needed
  # For hibernation: swap size should equal RAM (30GB). Without hibernation,
  # 4GB is sufficient as emergency overflow. Set to 0 to disable if not needed.
  swapDevices = [
    {
      device = "/swapfile";
      size = 4096; # Size in MB (4GB) - emergency overflow only
      priority = 10; # Lower priority than zram (higher number = lower priority)
    }
  ];

  # Workstation optimizations
  services.fstrim.enable = true;  # SSD TRIM support
  services.fwupd.enable = true;   # Firmware updates

  # Printer support
  services.printing.enable = true;
  services.avahi = {
    enable = true;
    nssmdns4 = true;  # Network printer discovery
  };

  # Bluetooth support
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  # Better desktop responsiveness
  services.system76-scheduler.enable = true;
  
  # IRQ balancing for better multi-core performance (important for 6-core Ryzen)
  services.irqbalance.enable = true;

  # System-wide zsh shell support
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  # Additional system packages for tower workstation
  # (wallpapers are now provided via assets/wallpapers and the
  #  machines.wallpapers module, so we no longer install the
  #  nixos-artwork wallpaper packages here.)
  environment.systemPackages = with pkgs; [
    # System monitoring. htop and btop come from the shared set, and nvtop
    # comes from modules/nvidia.nix, so this host adds only the rest.
    iotop
    powertop

    # GPU overlay settings for MangoHud
    goverlay

    # Secure Boot key management; sbctl signs the bootloader and kernels.
    sbctl

    # RGB managers
    openrgb

    # FUSE runtime for AppImages
    fuse
    fuse3

    # AccountsService package (provides accounts-daemon)
    accountsservice

    # Disk management
    gparted
    gnome-disk-utility
  ];

  # Autostart OpenRGB for graphical sessions (system-wide)
  environment.etc."xdg/autostart/openrgb.desktop".text = ''
[Desktop Entry]
; Auto-start OpenRGB for desktop sessions
Type=Application
Name=OpenRGB
Exec=${pkgs.openrgb}/bin/OpenRGB -p tower-openrgb.orp
X-GNOME-Autostart-enabled=true
NoDisplay=false
'';

  # Let NixOS install OpenRGB's udev rules properly
  services.udev.packages = [ pkgs.openrgb ];

  # ckb-next removed for unsupported Lighting Node CORE; use OpenRGB instead
}
