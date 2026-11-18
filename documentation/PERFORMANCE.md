# Performance

The tuning `tower` carries, why each piece is there, and how to check it is
still on. None of this is in the shared defaults.

## What stays global and what does not

| Setting | Scope | Where |
| --- | --- | --- |
| ZRAM swap | every host | `modules/zram.nix`, imported by `base.nix` |
| CPU governor, kernel params, sysctl | `gaming.kernelTuning` only | `modules/gaming.nix` |
| `zstd` zram, 4 GiB swapfile | `tower` | `hosts/tower/default.nix` |
| tmpfs `/tmp`, boot timeout, journal cap | `tower` | `hosts/tower/default.nix` |
| `noatime`/`discard` mount options | `tower` | `hosts/tower/default.nix` |

The split is the point. A laptop does not inherit a gaming governor, a latency
kernel parameter set, or a BBR stack, and every host still gets compressed swap
because that is a general win.

## Memory

ZRAM is the primary swap. `tower` sets `zramSwap` directly with `zstd` and a 50%
memory bound; every other host gets `machines.zram.*`, which sizes to
`min(total_ram / 2, machines.zram.maxSize)` with `lz4`.

```bash
zramctl
swapon --show        # zram should outrank the swapfile
```

The 4 GiB swapfile is overflow only. Hibernation would need a swapfile at least
the size of RAM, which is the reason `tower` does not hibernate.

## CPU and processes

`gaming.kernelTuning` sets the governor:

```nix
powerManagement.cpuFreqGovernor = "performance";
```

That costs idle power, roughly 10 to 20 W. `schedutil` is the alternative if the
machine starts running hot.

```bash
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

GameMode comes from `hosts/tower/default.nix`:

```nix
programs.gamemode = {
  enable = true;
  settings = {
    general.renice = 10;
    gpu.apply_gpu_optimisations = "accept-responsibility";
  };
};
```

```bash
gamemoderun %command%      # in Steam launch options
gamemoded -s               # is it active
```

## Kernel

`gaming.kernelTuning` adds three parameters:

```nix
boot.kernelParams = [
  "processor.max_cstate=2"        # shallower C-state, lower wake latency
  "nowatchdog"
  "transparent_hugepage=always"
];
```

CPU mitigations stay on for every host. `mitigations=off` was tried and removed:
it trades security for a few percent, and `tower` runs agent sessions.

```bash
cat /proc/cmdline
```

`sysctl`, same option:

```nix
boot.kernel.sysctl = {
  "vm.swappiness" = 10;
  "vm.vfs_cache_pressure" = 50;
  "vm.dirty_ratio" = 10;
  "vm.dirty_background_ratio" = 5;
  "net.core.default_qdisc" = "fq";
  "net.ipv4.tcp_congestion_control" = "bbr";
  "net.ipv4.tcp_fastopen" = 3;
  "net.ipv4.tcp_mtu_probing" = 1;
};
```

BBR is the one worth knowing how to undo. On a very low-latency LAN it can lose
to `cubic`:

```nix
boot.kernel.sysctl."net.ipv4.tcp_congestion_control" = "cubic";
```

```bash
sysctl net.ipv4.tcp_congestion_control
sysctl net.core.default_qdisc
```

## Storage

A udev rule in `gaming.nix` pins the NVMe scheduler to `none`, which is what the
driver wants for a device with no seek cost:

```bash
cat /sys/block/nvme0n1/queue/scheduler
```

`tower` mounts with:

```nix
options = [ "noatime" "nodiratime" "discard" "commit=60" ];
```

`noatime` and `nodiratime` drop write traffic nobody reads. `discard` trims
continuously; `services.fstrim` also runs weekly, so either alone would do.
`commit=60` batches metadata writes, which trades up to a minute of lost writes
on a hard power cut for less SSD wear. On a machine that holds nothing
irreplaceable that is the right trade.

## Boot

```nix
boot.tmp.useTmpfs = true;
boot.tmp.tmpfsSize = "50%";
boot.loader.timeout = 3;
services.journald.extraConfig = ''
  SystemMaxUse=500M
  MaxRetentionSec=1week
'';
```

tmpfs `/tmp` is RAM-speed and costs no SSD writes, with the trade that a large
temporary file eats RAM. The half-of-RAM cap is the ceiling. A tmpfs `/tmp` also
means `/tmp` does not survive a reboot, which is why nothing here puts state in
it.

## Gaming environment

`home/hunter.nix` sets:

```nix
WINEFSYNC = "1";
VK_ICD_FILENAMES = "/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.x86_64.json";
STEAM_EXTRA_COMPAT_TOOLS_PATHS = "$HOME/.steam/root/compatibilitytools.d";
```

`WINEFSYNC` is the futex-based sync path in Wine and Proton; some older titles
crash with it, and unsetting it here is the fix. The Vulkan ICD pin matters
because a hybrid machine can otherwise pick the wrong GPU.

Wayland variables, set for the desktop session:

```nix
MOZ_ENABLE_WAYLAND = "1";
NIXOS_OZONE_WL = "1";
QT_QPA_PLATFORM = "wayland";
SDL_VIDEODRIVER = "wayland";
```

## Verifying

`scripts/verify-performance.sh` prints the governor, zram state, both I/O
schedulers, the congestion control setting, `/proc/cmdline`, memory and swap,
tmpfs usage, and GameMode's status. Run it after a switch that touched any of
the above.

```bash
./scripts/verify-performance.sh
```

`systemd-analyze` for boot time. `mangohud <game>` for frame time, which is a
better number than FPS when the question is smoothness.

## Undoing a change

Set `gaming.kernelTuning = false` in `hosts/tower/default.nix`. The governor,
the kernel parameters and the sysctl block all disappear together, because they
are one option.

There is no security trade to undo: mitigations were never turned off.
