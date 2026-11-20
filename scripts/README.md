# Scripts

Gates CI runs, and helpers used on a real machine.

## Gates

| Script | Fails when | Check |
| --- | --- | --- |
| `check-layering.py` | a role or module names a path under `hosts/` | `checks.<system>.layering` |
| `check-no-password-hash.sh` | a committed hash appears outside `hosts/example/` | `checks.<system>.no-initial-password` |

`check-layering.py --self-test` plants two violations and two prose cases, then
asserts it catches the first pair and ignores the second. A checker that stopped
matching fails its own test.

`check-no-password-hash.sh` assembles its needle at runtime, so it does not match
its own source.

## Machine helpers

### `switch-desktop.sh <desktop> [host]`

Rewrites the host's role import and rebuilds. Valid names are `kde`, `dux`,
`hyprland`, `xfce` and `base`. The host defaults to `hostname -s`, so the bare
form works on the machine it targets. It shows the diff and asks before writing.
On a unit wrapper, one that imports `../<host>/default.nix` or `../<host>`, it
edits the shared host and rebuilds the unit named, so the change reaches every
unit built from that host. Any other host file is treated as its own role file.

### `switch-host.sh [<flake-ref>]`

Build or switch a host from the flake. Defaults to `.#tower`.

### `deploy-config.sh`

Copies this checkout to `/etc/nixos`, with a timestamped backup first. The
system-scope unit is what makes the `deploy-config` command available after a
rebuild. Useful when a machine should rebuild from `/etc/nixos` rather than from
the checkout that auto-upgrade fast-forwards.

```bash
sudo nixos-rebuild switch --flake /etc/nixos#tower
```

### `validate-hosts-home-manager.sh`

Evaluates each host's Home Manager profile without switching. It is the cheap
copy of the `home-manager-hunter.service` failure, which otherwise only shows up
during a switch.

### `collect-system-info.sh`

Hardware, NixOS version, installed packages, the active session, and the tail of
the journal, in one paste-able block. Written for a bug report.

### `verify-performance.sh`

Prints the governor, zram state, I/O scheduler, congestion control,
`/proc/cmdline`, memory and swap, tmpfs usage, and GameMode status.
`PERFORMANCE.md` explains what each value should be.

### `setup-displaylink.sh`

Fetches the DisplayLink driver archive under the name the nixpkgs `displaylink`
package expects, so `work-laptop` builds without a manual fetch. For a dock, not
for a laptop's internal panel.

### `partition-drive.sh <device>`

Wipes the named device and lays out a NixOS install: GPT for UEFI, an ESP, a swap
partition, and the rest as root, formatted and mounted under `/mnt`.

It destroys everything on the device. Check the name with `lsblk` first, and do
not run it against a disk that holds another system.

The wallpaper generators (`create-*-wallpaper.sh`) produce the assets used by
the wallpaper module. They are build-time conveniences, not gates.

## Conventions

- Run from the repository root. Most helpers resolve paths relative to it.
- Anything needing root says so in its usage line and refuses when it lacks it.
- A script that writes to the tree shows the change and asks first.
