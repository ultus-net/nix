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

Both labels matter. The role placeholders and the label-based hosts resolve
`/dev/disk/by-label/EFI` and `/dev/disk/by-label/nixos-root`, so a mislabelled
ESP boots but leaves `/boot` unmounted, and the next `nixos-rebuild boot`
fails. Label each filesystem when you create it.

A missing `/mnt/boot` mount produces an install that does not boot.

## 2. Clone the flake into the target root

```bash
git clone https://github.com/ultus-net/nix.git /mnt/nix
```

## 3. Regenerate the hardware config, or keep the labels

`hosts/<host>/hardware.nix` is written in one of two conventions, and a host
stays on the one it started with:

- **Labels** name the disks `/dev/disk/by-label/nixos-root` and
  `/dev/disk/by-label/EFI`. One file installs any number of identical
  machines, so the file never changes per unit. `elitedesk-800-g4` uses this.
  Nothing to regenerate while the disk layout in section 1 holds.
- **UUIDs** name the disks the installer found. The file is specific to that
  one machine, so a reinstall or a different disk means regenerating it.
  `tower` and `work-laptop` use this.

A UUID-based host that moves to a different disk regenerates its file on the
target:

```bash
nixos-generate-config --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix /mnt/nix/hosts/tower/hardware.nix
```

A label-based host that turns out to be a different machine class regenerates
too, then rewrites the two `device` lines from UUIDs back to the labels above.
Otherwise the shared file stops matching its siblings.

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
- **The system installs but does not boot**: `/mnt/boot` was not mounted during
  the install, or `hardware.nix` names a bootloader the firmware cannot use.
- **The first login is impossible**: expected. The account is locked until
  `passwd` runs on the console.
