{ config, pkgs, lib, ... }:
let
  cfg = config.gaming;

  # Explicit, not presence-filtered: a package that leaves nixpkgs must fail
  # evaluation here instead of disappearing from the set without a word.
  # NOTE: "steam" is excluded; use gaming.enableSteam for programs.steam.
  gamingPackages = with pkgs; [
    lutris
    heroic
    gamescope
    mangohud
    vkbasalt
    gamemode
    faudio
    vulkan-tools
    vulkan-loader
    wine
    protonup-qt
    protontricks
    winetricks
  ];

  # 32-bit libraries Proton needs. `pkgsi686Linux` resolves to real i686
  # builds; the old presence filter looked for a set that does not exist.
  lib32Packages = with pkgs.pkgsi686Linux; [
    vulkan-loader
    faudio
  ];
in {
  options.gaming = {
    enable = lib.mkEnableOption "Enable gaming QoL packages and helpers (opt-in)";
    
    enableSteam = lib.mkEnableOption "Enable Steam via the NixOS programs.steam module";

    # Kernel, network and flatpak tuning that only makes sense on a gaming
    # desktop. Shared defaults stay secure, so a host opts in explicitly.
    kernelTuning = lib.mkEnableOption "Apply gaming kernel, network and flatpak tuning (no CPU-mitigation trade)";
    
    optimizeSteamIO = lib.mkEnableOption "Enable I/O optimizations for Steam (reduces cloud sync delays)";
    
    packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      description = "Extra packages (from pkgs) to include for gaming usage.";
    };

    # Toggle for installing common i386 (lib32) compatibility packages.
    enableI386Compat = lib.mkEnableOption "Add common i386/lib32 compatibility packages when available";

    # Both firewall openings default to closed. Remote Play only needs the
    # ports while streaming, and the dedicated-server ports only when hosting.
    steamRemotePlayFirewall = lib.mkEnableOption "open the Steam Remote Play firewall ports";

    steamDedicatedServerFirewall = lib.mkEnableOption "open the Source dedicated-server firewall ports";

    # Informational toggle: if true, the module may expose instructions
    # or notes about Flatpaks (it does not install Flatpaks automatically).
    enableFlatpaks = lib.mkEnableOption "Expose convenience notes for installing common Flatpaks (no automatic flatpak installs)";

    # Proton environment helpers: write environment variables to the system
    # environment when requested (useful for Proton/Game compatibility tuning).
    enableProtonEnv = lib.mkEnableOption "Write recommended Proton-related environment variables to the system environment";
    protonEnv = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Attribute set of environment variables to write when enableProtonEnv is true. Example: { PROTON_FSR4_UPGRADE = 1; }";
    };
  };

  config = lib.mkIf cfg.enable {
    # Compose systemPackages from user-specified packages plus the available
    # gaming packages and optional lib32 compatibility packages.
    environment.systemPackages = (cfg.packages or []) ++ gamingPackages ++ lib.optionals cfg.enableI386Compat lib32Packages;

    # Enable Steam via the proper NixOS module (avoids steam-unwrapped build issues)
    programs.steam = lib.mkIf cfg.enableSteam {
      enable = true;
      remotePlay.openFirewall = cfg.steamRemotePlayFirewall;
      dedicatedServer.openFirewall = cfg.steamDedicatedServerFirewall;
      
      # Add extra packages to the FHS environment for compatibility
      extraCompatPackages = with pkgs; [
        # Additional runtime libraries that games might need
        curl
        dbus
        fontconfig
        freetype
        glib
        pango
        zenity
        xdg-utils
        zlib
        libbsd
        libcap
        SDL2
        openssl
        udev
        gtk3
        cairo
        pciutils
        which
        alsa-lib
        at-spi2-atk
        at-spi2-core
        nspr
        nss
        cups
        libdrm
        expat
        libxkbcommon
        wayland
      ];
    };
    
    # Enable 32-bit graphics drivers for Steam/Proton compatibility
    hardware.graphics.enable32Bit = lib.mkIf cfg.enableSteam true;

    # Enable Steam hardware support (udev rules for controllers and input devices)
    hardware.steam-hardware.enable = lib.mkIf cfg.enableSteam true;

    # I/O scheduling optimizations for Steam (reduces cloud sync delays)
    systemd.services.steam-io-optimize = lib.mkIf (cfg.enableSteam && cfg.optimizeSteamIO) {
      description = "Optimize I/O scheduler for Steam directory";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "steam-io-optimize" ''
          # Find the block device for home directory
          HOME_DEV=$(df -P /home | tail -1 | awk '{print $1}' | sed 's/[0-9]*$//')
          if [ -b "$HOME_DEV" ]; then
            # Use none scheduler for NVMe/SSD, or mq-deadline for others
            if [[ "$HOME_DEV" =~ nvme ]]; then
              echo "none" > /sys/block/$(basename "$HOME_DEV")/queue/scheduler 2>/dev/null || true
            else
              echo "mq-deadline" > /sys/block/$(basename "$HOME_DEV")/queue/scheduler 2>/dev/null || true
            fi
            # Increase read-ahead for better sequential performance
            echo 2048 > /sys/block/$(basename "$HOME_DEV")/queue/read_ahead_kb 2>/dev/null || true
          fi
        '';
      };
    };

    # Optionally write Proton-related variables into the system environment
    # so they are available system-wide (use with care).
    environment.variables = lib.mkIf cfg.enableProtonEnv cfg.protonEnv;

    # Gaming kernel and network tuning. Deliberately excludes mitigations=off,
    # tsc=reliable and clocksource=tsc: those trade security or portability for
    # a few percent, and this host runs agents.
    boot.kernelParams = lib.mkIf cfg.kernelTuning [
      "nowatchdog"
      "transparent_hugepage=always"
      "processor.max_cstate=2"
    ];

    powerManagement.cpuFreqGovernor = lib.mkIf cfg.kernelTuning "performance";

    services.udev.extraRules = lib.mkIf cfg.kernelTuning ''
      ACTION=="add", SUBSYSTEM=="usb", TEST=="power/wakeup", ATTR{power/wakeup}="enabled"
      ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", TEST=="queue/scheduler", ATTR{queue/scheduler}="none"
    '';

    boot.kernel.sysctl = lib.mkIf cfg.kernelTuning {
      "net.core.default_qdisc" = "fq";
      "net.ipv4.tcp_congestion_control" = "bbr";
      "vm.swappiness" = 10;
      "vm.vfs_cache_pressure" = 50;
      "vm.dirty_ratio" = 10;
      "vm.dirty_background_ratio" = 5;
      "vm.min_free_kbytes" = 262144;
      "vm.dirty_expire_centisecs" = 3000;
      "vm.dirty_writeback_centisecs" = 1500;
      "net.core.netdev_max_backlog" = 16384;
      "net.core.somaxconn" = 8192;
      "net.ipv4.tcp_fastopen" = 3;
      "net.ipv4.tcp_mtu_probing" = 1;
      "net.ipv4.tcp_window_scaling" = 1;
      "net.ipv4.tcp_timestamps" = 1;
      "net.ipv4.tcp_sack" = 1;
      "net.core.rmem_max" = 134217728;
      "net.core.wmem_max" = 134217728;
      "net.ipv4.tcp_rmem" = "4096 87380 67108864";
      "net.ipv4.tcp_wmem" = "4096 65536 67108864";
      "vm.watermark_scale_factor" = 200;
      "vm.page-cluster" = 0;
      "net.core.optmem_max" = 65536;
      "kernel.sched_migration_cost_ns" = 5000000;
      "kernel.sched_autogroup_enabled" = 0;
    };

    # Steam and game libraries sit outside the home directory, so their flatpak
    # overrides are gaming-specific rather than global.
    system.activationScripts.gamingFlatpakOverrides =
      lib.mkIf (cfg.kernelTuning && config.services.flatpak.enable) ''
        mkdir -p /var/lib/flatpak/overrides

        cat > /var/lib/flatpak/overrides/com.valvesoftware.Steam << EOF
[Context]
filesystems=xdg-data/applications:create;xdg-data/icons:create;/games:rw;/mnt:rw;/run/media:rw;xdg-music;xdg-pictures;xdg-videos;
devices=all;

[Environment]
__NV_PRIME_RENDER_OFFLOAD=1
__GLX_VENDOR_LIBRARY_NAME=nvidia
__VK_LAYER_NV_optimus=NVIDIA_only
EOF
      '';
  };
}
