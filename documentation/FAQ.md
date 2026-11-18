# Notes and answers

Decisions this tree encodes, and the reason each one exists. Most of these were
asked once, by me, while building it.

## Why does a fresh install refuse to log in?

The account ships locked. No password hash is committed for a real host, and
`scripts/check-no-password-hash.sh` fails CI when `initialHashedPassword`
appears outside `hosts/example/`. Set the first password on the console:

```bash
passwd hunter
```

An SSH-only host needs a key in the host config instead, because there is no
console to type on. `INSTALL.md` step 6 covers both.

## Why is `base-server` a `nixosConfigurations` entry with no host directory?

It exists so the headless role cannot rot. A role that no output uses stops
compiling the moment its modules change, and nobody notices. `mkSystem
./roles/base.nix` keeps it in `flake check` without inventing a machine that
does not exist.

## Why can't a module import something under `hosts/`?

Because that is the layering inversion this tree was built around. A host is a
leaf: it picks a role and supplies hardware. A role is reusable composition. A
module is host-agnostic. The moment a module reads `hosts/tower`, it compiles
only for `tower` and the reason to have roles disappears.

`scripts/check-layering.py` fails CI on any code reference to `hosts/` under
`roles/` or `modules/`. It strips comments and string bodies first, so prose
about hosts stays legal.

## Why does Hyprland not get the gaming tuning?

`gaming.kernelTuning` used to live in shared defaults, which meant every host
inherited a `mitigations=off` and a tuned network stack whether or not it played
games. It is now an option that one host turns on. Shared defaults stay secure.

## Why is `networking.nftables.enable` still off?

`tower` runs Docker, and the nixpkgs manual warns that the nftables backend
fights Docker's iptables NAT. Turning it on is not a hardening win if the
container network stops working. The sandbox network model avoids the question
entirely: `--private-network` with a unix-socket proxy.

## Why is there no disk encryption?

None of these machines hold anything that a LUKS prompt would protect, and an
unattended auto-upgrade cannot unlock a root volume on its own. If that changes,
the change belongs in one host's `hardware.nix`, because nothing else in the tree
sets `fileSystems`.

## Why is `system.autoUpgrade` the only update path?

Two update paths drift. The unit fast-forwards the checkout to `origin/main` and
rebuilds, so a machine only ever runs a commit that passed CI. There is no
second script to keep in sync, and no way to push an untested commit at a host.

Input bumps stay manual: `nix flake update` is a reviewed commit, not a timer.

## Why does `nix flake check` take twenty minutes?

It boots one `nixosTest` per host in QEMU and waits for `multi-user.target`. That
is the gate that catches a unit that is `linked` but not `enabled`, an
assertion that only holds on a VM, and a module that evaluates but does not
start. A syntax grep would pass all three.

It aborts sibling checks when one fails, so a cancelled host test after a failure
is the same failure, not a second one.

## Can a second machine join without touching a module?

Yes. Copy `hosts/example/`, generate a `hardware.nix` on the target, pick a role,
and add one `mkSystem` line to `flake.nix`. If that needs a change under
`modules/`, the module has a host assumption in it and that is the bug.

## Why is Flatpak not installed?

Every package here comes from nixpkgs, so one `flake.lock` describes the whole
system and a rollback restores it. Flatpak adds a second, unpinned package
source that `nixos-rebuild` cannot revert. Where a package is missing, the fix is
a nixpkgs bump or an overlay.

## Where do the wallpapers come from?

`nixos-artwork`, installed system-wide under
`/run/current-system/sw/share/backgrounds/nixos/`, rotated on a timer by
`machines.wallpapers`. Home Manager links them at `~/.wallpapers`. Disable per
host with `machines.wallpapers.enable = false`.
