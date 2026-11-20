# Installation

A host in this flake installs from a NixOS live ISO with one `nixos-install`
call. The disk layout lives in that host's `hardware.nix`, so the procedure below
assumes an existing host output: `tower`, `work-laptop`, `elitedesk-800-g4`, or
`base-server`.

## Before starting

- A NixOS live ISO with working network.
- The target disk, which the install overwrites.
- The flake output to install. `nix flake show` lists them.

The installer environment has `nix-command` and `flakes` disabled by default. Add
the flags, or the command fails before it reads the flake:

```bash
nix --extra-experimental-features 'nix-command flakes' flake show /mnt/nix
```

## 1. Partition and mount

Partition with the NixOS manual's UEFI example. No host here uses BIOS boot.
The layout the flake expects is fixed:

| Mount | Filesystem | Size | Purpose |
| --- | --- | --- | --- |
| `/mnt/boot` | FAT32, label `EFI` | 512 MiB or more | EFI system partition |
| `/mnt` | ext4, label `nixos-root` | the rest | root |

Both labels matter, and the host's own `hardware.nix` is what names them. The
role placeholders use the same paths so a role-only output still evaluates. A
mislabelled ESP still installs and boots once, because the firmware reads the
ESP directly. The installed system then mounts nothing at `/boot`, so the next
`nixos-rebuild boot` writes kernels into the root filesystem and the machine
keeps booting the old generation.

A missing `/mnt/boot` mount produces an install that does not boot.

## 2. Clone the flake into the target root

```bash
git clone https://github.com/ultus-net/nix.git /mnt/nix
```

When `/nix` is its own volume, clone into the home tree instead, so the store
mount does not also hold the repository. `hosts/work-laptop` sets
`machines.autoUpgrade.flakePath` to `/home/hunter/Documents/nix`, so clone
there:

```bash
git clone https://github.com/ultus-net/nix.git /mnt/home/hunter/Documents/nix
```

## 3. Regenerate the hardware config, or keep the labels

`hosts/<host>/hardware.nix` is written in one of two conventions, and a host
stays on the one it started with:

- **Labels** name the disks `/dev/disk/by-label/nixos-root` and
  `/dev/disk/by-label/EFI`. One file installs any number of identical
  machines, so it does not change per unit. `elitedesk-800-g4` uses this, and
  nothing needs regenerating while the layout in section 1 holds. Those are
  the same paths the roles carry as placeholders; an installed machine is
  configured by its own file, never by the placeholder.
- **UUIDs** name the disks the installer found. The file belongs to that one
  machine, so a reinstall or a different disk means regenerating it. `tower`
  uses this.
- **Subvolumes** name one btrfs volume by label and mount separate subvolumes
  from it. `work-laptop` labels its NixOS volume `nixos` and mounts `@root`,
  `@home`, `@nix` and `@boot` from it, so generations stay off the ESP it
  shares with a bootc slot. Its ESP is named by UUID because the other OS
  already owns that partition.

An encrypted root replaces the root `device` with the `/dev/mapper` name from
section 4, whichever convention the host started on. The ESP keeps its label,
or its UUID, as usual.

A UUID-based host that moves to a different disk regenerates its file on the
target:

```bash
nixos-generate-config --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix /mnt/nix/hosts/tower/hardware.nix
```

A label-based host that turns out to be a different machine class regenerates
too, then rewrites the root `device` from the UUID back to its label. Otherwise
the shared file stops matching its siblings.

`hardware.nix` is the file that names the bootloader, the root filesystem, and
the kernel modules. Each role ships placeholder `fileSystems` values with
`lib.mkDefault`, so the host's `hardware.nix` wins. A stale or placeholder
`hardware.nix` is the usual cause of a failed install.

## 4. Optional: LUKS root

Encrypt the root partition before creating the filesystem, using the manual's
LUKS example, and open it before mounting.

The generated `hardware.nix` then carries the `boot.initrd.luks.devices` entry
and the `/dev/mapper` root filesystem. Nothing in this flake enables LUKS, so
that file is the only place the change belongs.

## 5. Install

```bash
nix --extra-experimental-features 'nix-command flakes' \
  nixos-install --root /mnt --flake /mnt/nix#tower
```

`--root /mnt` points the installer at the mounted target. The flake attribute
after `#` selects the host. `nixos-install` prompts for a root password, which
it writes into the installed system.

## 6. First boot

The account in each host starts locked: no password hash is committed, so there
is nothing to log in with until one is set. On the console:

```bash
passwd hunter
```

An SSH-only machine needs a key before it can accept a login, ideally in the
host config so the first switch carries it:

```nix
users.users.hunter.openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAA..." ];
```

## 7. Verify

| Check | Command |
| --- | --- |
| Boots to a login prompt | watch the console |
| Login works | `passwd hunter` sets one; SSH needs a key |
| Desktop starts | `systemctl status display-manager` |
| Network | `ping -c 3 8.8.8.8` |
| Audio | `speaker-test -t wav -c 2` |
| Home Manager active | `home-manager generations` |
| Flakes enabled in the installed system | `nix flake show /mnt/nix` |
| Rebuild works | `sudo nixos-rebuild switch --flake /mnt/nix#tower` |

`modules/base.nix` sets `nix.settings.experimental-features`, so the installed
system needs no flags.

## Troubleshooting

- **`experimental Nix feature 'nix-command' is disabled`**: the installer
  environment, not the installed system. Add
  `--extra-experimental-features 'nix-command flakes'`.
- **`cannot find flake ... in the flake registries`**: the attribute name is
  wrong, or the path is not a flake. `nix flake show /mnt/nix` prints the
  outputs.
- **Evaluation fails during install**: run the same `flake show` command, then
  `nix build` the host output to see the full error.
- **The system installs but never boots**: `/mnt/boot` was not mounted during
  the install, or `hardware.nix` names a bootloader the firmware cannot use.
- **It boots, but a rebuild does not take effect**: the ESP label or UUID does
  not match `hardware.nix`, so the kernel was written to the root filesystem
  instead of the ESP. `findmnt /boot` shows whether it is a separate mount.
- **The first login is impossible**: expected. The account is locked until
  `passwd` runs on the console.
