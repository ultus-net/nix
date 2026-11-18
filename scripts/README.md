# Scripts

Helper scripts for managing your NixOS system.

## Available Scripts

### `deploy-config.sh`
Sync your local nix repository to `/etc/nixos` (the system location).

**Usage:**
```bash
deploy-config           # Interactive sync with confirmation
# or use the shorter alias:
deploy-cfg
```

**What it does:**
1. Shows a preview of changes (dry-run)
2. Asks for confirmation
3. Creates a timestamped backup of `/etc/nixos`
4. Syncs `~/Documents/nix/` → `/etc/nixos/`
5. Shows next steps for rebuilding

**After deployment:**
```bash
sudo nixos-rebuild switch --flake /etc/nixos#tower
```

This script is automatically available system-wide after rebuilding.

### `switch-desktop.sh`
Point a host at a different desktop role and rebuild that host. It shows the
diff, asks for confirmation, and rewrites the host's role import.

**Usage:**
```bash
./scripts/switch-desktop.sh <desktop> [host]
```

**Example:**
```bash
# Switch tower from KDE to Hyprland
./scripts/switch-desktop.sh hyprland tower
```

**Available desktops:** kde, xfce, hyprland. The host defaults to
`hostname -s`, so `./scripts/switch-desktop.sh hyprland` works on the machine
it targets.

### `switch-host.sh`
Build or switch to a host from the flake. Defaults to `.#tower`.

**Usage:**
```bash
./scripts/switch-host.sh [<flake-ref>]
```

### `check-layering.py`
Fail when a role or shared module imports a path under `hosts/`. Layering runs
host -> role -> module, so that import inverts it. CI runs the gate and its
`--self-test`.

**Usage:**
```bash
python3 ./scripts/check-layering.py
python3 ./scripts/check-layering.py --self-test
```

### `check-no-password-hash.sh`
Fail when a committed password hash appears outside `hosts/example/`. The needle
is assembled at runtime, so the script does not match itself. CI runs it as
`checks.<system>.no-initial-password`.

**Usage:**
```bash
./scripts/check-no-password-hash.sh .
```

### `collect-system-info.sh`
Gather system information for troubleshooting.

**Usage:**
```bash
./scripts/collect-system-info.sh
```

This collects:
- Hardware configuration
- NixOS version
- Installed packages
- Active desktop environment
- System logs

### `setup-displaylink.sh`
Prepare the proprietary DisplayLink driver blob for NixOS so the `displaylink`
package can build without manual fiddling.

**Usage (from repo root):**
```bash
./scripts/setup-displaylink.sh
```

What it does:
- Downloads the official Ubuntu DisplayLink driver ZIP via `nix-prefetch-url`
	under the name expected by the nixpkgs `displaylink` package.
- After it succeeds, you can rebuild (for example):

```bash
sudo nixos-rebuild switch --flake .#work-laptop
```

### `validate-hosts-home-manager.sh`
Validate Home Manager configurations.

**Usage:**
```bash
./scripts/validate-hosts-home-manager.sh
```

### `verify-performance.sh`
Verify that all performance optimizations are active and working correctly.

**Usage:**
```bash
./scripts/verify-performance.sh
```

**What it checks:**
- CPU governor settings
- zram compression swap status
- I/O scheduler configuration (kyber/mq-deadline)
- TCP BBR congestion control
- Kernel boot parameters (C-states, hugepages, watchdog)
- Memory tuning (swappiness, VFS cache pressure)
- tmpfs configuration
- Gamemode service status
- Boot time analysis

**When to run:**
- After rebuilding with performance optimizations
- To troubleshoot performance issues
- Periodically to ensure settings persist

See [PERFORMANCE.md](../documentation/PERFORMANCE.md) for details on each optimization.

### `partition-drive.sh`
Automatically partition a drive for NixOS installation. This script handles all partitioning automatically - you just specify which drive to use.

**Usage:**
```bash
sudo ./scripts/partition-drive.sh <device>
```

**Examples:**
```bash
# Partition /dev/sda for NixOS
sudo ./scripts/partition-drive.sh /dev/sda

# Partition an NVMe drive
sudo ./scripts/partition-drive.sh /dev/nvme0n1
```

**Warning:** This script will **destroy all data** on the target device.

**What it does automatically:**
1. Detects firmware type (UEFI or BIOS)
2. Wipes the target device
3. Creates partition table (GPT for UEFI, MBR for BIOS)
4. Creates boot partition (512M)
5. Creates swap partition (8G)
6. Creates root partition (remaining space)
7. Formats all partitions with appropriate filesystems
8. Mounts partitions at /mnt ready for installation

After running this script, you're ready to install:
```bash
nixos-generate-config --root /mnt
nano /mnt/etc/nixos/configuration.nix
nixos-install
```

## Tips

- Make scripts executable: `chmod +x scripts/*.sh`
- Run from repository root for best results
- Most scripts require sudo/root privileges
- Check script comments for detailed usage information
