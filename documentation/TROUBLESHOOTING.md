# Troubleshooting

Failures already hit on these machines, with the fix that worked. Written after
the fact, so each entry names the symptom rather than the cause.

## Installation

**`experimental Nix feature 'nix-command' is disabled`**

The installer environment, not the installed system. Add the flags:

```bash
nix --extra-experimental-features 'nix-command flakes' flake show /mnt/nix
```

**`does not provide attribute`**

The name after `#` is not a host. `nix flake show /mnt/nix` lists them, and the
attribute matches the directory under `hosts/`, except `base-server`, which is a
role-only output.

**Installs, then does not boot**

`/mnt/boot` was not mounted during the install, or `hardware.nix` names a
bootloader the firmware cannot use. Each role ships placeholder `fileSystems`
values with `lib.mkDefault`, so a placeholder `hardware.nix` silently wins over
nothing.

**No space left on device, during install**

`/boot` is too small for the kernel and initrd set. Check with `df -h /boot`,
and give it 1 GiB on a machine that keeps several generations.

## First login

**Login is impossible after the first boot**

Expected. No password hash is committed for a real host, so the account is
locked. On the console:

```bash
passwd hunter
```

An SSH-only machine needs `users.users.hunter.openssh.authorizedKeys.keys` set in
the host config instead.

## Desktop

**`display-manager.service` fails**

`journalctl -xeu display-manager.service` first. The usual cause is a role
imported twice, or a host whose `hardware.nix` sets the GPU options while
`modules/nvidia.nix` sets them again.

**KDE starts on X11**

`kde.enableWayland` and `kde.enableXWayland` are both options on `modules/kde.nix`
and both default on. A host that sets one off in its own config wins.

## Network

**No network after boot**

NetworkManager is in `modules/networking.nix`, which every role imports.
`systemctl status NetworkManager`, then `nmtui`.

**Containers lose their network after an nftables change**

`networking.nftables.enable` is off on purpose. The nixpkgs manual warns that the
nftables backend fights Docker's iptables NAT, and `tower` runs Docker. Leave it
off, and give a service its own port rule instead.

**SSH refuses a connection**

`sshd` and the firewall come from `modules/security.nix`, with password
authentication and root login off. A refused connection is usually a missing key,
not a closed port: check `/etc/ssh/sshd_config` for the key, then
`journalctl -u sshd`.

## Builds

**`hash mismatch`**

The cached hash does not match the download. `nix-store --verify
--check-contents --repair` fixes a damaged store; a real mismatch means the
upstream content moved, which for a pinned input is a reason to bump it
deliberately with `nix flake lock --update-input <input>`.

**Out of memory during a build**

```bash
nixos-rebuild switch --option max-jobs 1 --option cores 2
```

ZRAM absorbs some of it, but a large Rust or Chromium build still wants real
swap.

**The build downloads everything again**

A changed `flake.lock` means a different store closure. `nix flake metadata` shows
the current pins, and `nixos-rebuild dry-build --flake .#tower` shows what would
be fetched before it starts.

## Home Manager

**`Collision between ...`**

The same file is declared twice, usually a package in
`environment.systemPackages` and again in `home.packages`. Remove one.

**`home-manager-hunter.service` fails**

`journalctl --user -xeu home-manager-hunter.service`. The unit runs on every
switch, so a failure here is an evaluation error in the HM profile, not a system
fault. `home-manager build` gives the error without touching the running system.

## Recovery

**A rebuild leaves the system unbootable**

Pick the previous generation at the boot menu, then:

```bash
sudo nixos-rebuild switch --rollback
```

**A user change locks the account out**

TTY on `Ctrl+Alt+F2`, or boot the previous generation. `sudo passwd hunter`
restores a login without a rebuild.

**The system needs a rescue**

Boot the live ISO, mount the root and boot partitions under `/mnt`, fix the
checkout, and rerun `nixos-install --root /mnt --flake /mnt/nix#tower`.

## CI

**`systemctl is-enabled <unit>` fails in a host test**

A unit can be `linked` and still not `enabled`, so `is-enabled` exits 1 on a
correct system. `fwupd.service` on `work-laptop` is exactly that: the module
links it, the host does not enable it. Assert a unit the host actually enables,
or assert the state that is meant.

**A host test is cancelled next to a failure**

`nix flake check` aborts sibling checks when one fails. The cancelled test is the
same failure, not a second one. Fix the reported assertion and rerun.

**Flake check passes locally but nothing builds**

Local evaluation and a local build are different things. On this workstation
`nix` has no `/nix/store` outside the workspace, so evaluation works and every
build fails on a missing path. The build job is where a build is proved.

## Commands worth remembering

```bash
journalctl -b -u <unit>          # one service, this boot
journalctl -xe                   # the tail of everything
nixos-rebuild dry-build --flake .#tower
nixos-rebuild test --flake .#tower
nix flake show
nix flake metadata
nixos-option services.openssh
```

The NixOS manual is the authority for an option's meaning:
<https://nixos.org/manual/nixos/stable/>.
