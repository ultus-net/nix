# Modules

Host-agnostic configuration fragments. A module declares an option, guards its
config behind that option, and never names a path under `hosts/`. That last rule
is what `scripts/check-layering.py` enforces.

## Inventory

| Module | Option prefix | On import |
| --- | --- | --- |
| `base.nix` | none | sets `stateVersion`, flakes, `nix.gc`, locale; imports `zram.nix` |
| `networking.nix` | none | NetworkManager |
| `security.nix` | `securityDefaults` | firewall, SSH agent, `sops`; fprintd and avahi only when enabled |
| `audio.nix` | none | PipeWire |
| `fonts.nix` | none | fontconfig, JetBrains Mono and FiraCode Nerd Fonts, `noto-fonts-color-emoji` |
| `home-manager.nix` | none | the HM NixOS module |
| `development.nix` | none | language toolchains and linters |
| `nvidia.nix` | none | proprietary driver, KMS, 32-bit libs |
| `laptop.nix` | none | `power-profiles-daemon`, `thermald`, `upower`, libinput, Bluetooth |
| `common-packages.nix` | `commonPackages` | nothing until enabled |
| `multimedia.nix` | `multimedia` | nothing until enabled |
| `gaming.nix` | `gaming` | nothing until enabled |
| `containers.nix` | `machines.containers` | nothing until enabled |
| `virtualization.nix` | `virtualization` | nothing until enabled |
| `sysadmin.nix` | `sysadmin` | nothing until enabled |
| `wayland-utils.nix` | `waylandUtils` | nothing until enabled; mixer, media keys, clipboard history, screenshot annotation |
| `pince.nix` | `pince` | nothing until enabled |
| `deploy-config.nix` | `deployConfig` | nothing until enabled |
| `wallpapers.nix` | `machines.wallpapers` | nothing until enabled |
| `zram.nix` | `machines.zram` | defaults via `base.nix` |
| `auto-upgrade.nix` | `machines.autoUpgrade` | nothing until enabled |
| `agent-sandbox.nix` | `machines.agentSandbox` | nothing until enabled |
| `kde.nix` | `kde` | nothing until enabled; composed by `roles/kde.nix` |
| `xfce.nix` | `xfce` | nothing until enabled; composed by `roles/xfce.nix` |
| `hyprland.nix` | `hyprland` | nothing until enabled; composed by `roles/hyprland.nix` |
| `dux.nix` | `dux` | nothing until enabled; composed by `roles/dux.nix` |
| `noctalia.nix` | `noctalia` | nothing until enabled; Umbriel, the shell, the greetd greeter and Luciole; composed by `roles/noctalia.nix` |

## Options worth knowing

### `multimedia`

```nix
multimedia = {
  enable = true;
  enableVideoEditing = true;     # Kdenlive, Blender
  enableAudioProduction = true;  # Audacity, Ardour
  extraPackages = [ ];
};
```

Players, image tools, `ffmpeg`, `yt-dlp`, screenshot and recording tools, and
OBS.

### `gaming`

```nix
gaming = {
  enable = true;            # Steam, Lutris, Heroic, MangoHUD, GameMode
  enableSteam = true;       # the NixOS programs.steam module
  kernelTuning = true;      # governor, kernel params, sysctl; this host only
  enableI386Compat = true;  # 32-bit libraries
  enableProtonEnv = true;   # Proton environment variables
  optimizeSteamIO = true;   # Steam I/O and cloud-sync tuning
};
```

`kernelTuning` is the one that must not be in shared defaults. It never disables
CPU mitigations, and `PERFORMANCE.md` lists exactly what it sets.

Every one of these sits inside `lib.mkIf cfg.enable`, so `gaming.enable = true`
is required as well. `kernelTuning = true` on its own changes nothing.

### `machines.containers`

```nix
machines.containers = {
  enable = true;
  enableDistrobox = true;
  enableKubernetes = false;   # kubectl, k9s, helm
  enableDockerCompose = true;
  extraPackages = [ ];
};
```

### `sysadmin`

```nix
sysadmin = {
  enable = true;
  enableBackupTools = true;         # restic, rclone, borgbackup
  enableNetworkDiagnostics = true;  # nmap, wireshark, iperf3
  enableHardwareMonitoring = true;  # smartmontools, lm_sensors
  extraPackages = [ ];
};
```

### `machines.wallpapers`

```nix
machines.wallpapers = {
  enable = true;
  rotationInterval = 300;   # seconds
};
```

Installs the `nixos-artwork` set system-wide and rotates it. Every desktop role
sets `enable = lib.mkDefault true`.

### `machines.autoUpgrade`

```nix
machines.autoUpgrade = {
  enable = true;
  flakePath = "/home/hunter/Documents/nix";
  ref = "main";
  dates = "weekly";
};
```

`system.autoUpgrade` is the only updater. A `preStart` hook runs `git fetch`
then `merge --ff-only` for `ref`, so a host only moves to a commit that passed
CI on `main`. `--no-update-lock-file` keeps the lock under review: bumping an
input is a commit, not a timer.

`safe.directory` names `flakePath`, not `*`, so the git trust the unit grants is
the one checkout it reads.

### `machines.agentSandbox`

```nix
machines.agentSandbox = {
  enable = true;
  allowedHosts = [ "github.com" "*.github.com" ];
  allowedPorts = [ 443 ];
  tools = [ pkgs.bashInteractive pkgs.git pkgs.curl ];
  homeSize = "1G";
  memoryMax = "8G";
  cpuQuota = "400%";
  tasksMax = 4096;
};
```

[AGENT-SANDBOX.md](../documentation/AGENT-SANDBOX.md) states the boundary.

### `machines.zram`

```nix
machines.zram = {
  enableAutoSize = true;    # min(total_ram / 2, maxSize)
  maxSize = 4294967296;     # 4 GiB
  size = 0;                 # explicit size, when auto-sizing is off
  compAlgorithm = "lz4";
};
```

## Naming

A new module takes a namespace named for its concern, not for the host that
wanted it. If two modules would need the same prefix, they are one module. Add
the option to the table above in the same change, or the table drifts.
