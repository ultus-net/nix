# nix

A NixOS flake for three machines and the roles they compose. The repository is
public as a worked example of host → role → module layering. It is not open to
pull requests: it configures my hardware, and a change lands here because this
machine needs it.

## Hosts

| Host | Desktop | What it is |
| --- | --- | --- |
| `tower` | KDE | Home workstation. NVIDIA, the games drive, Docker, libvirt, PINCE. |
| `work-laptop` | KDE | Laptop. TLP, fwupd, DisplayLink, the work toolchain. |
| `base-server` | none | Headless. A role-only output, so it cannot rot unnoticed. |

`nixosConfigurations` carries all three. `homeConfigurations."hunter@x86_64-linux"`
is the Home Manager profile, and `dev-image` is the toolchain container published
to `ghcr.io/ultus-net/nix-dev`.

## Layout

```
nix/
├── flake.nix               # inputs, outputs, checks
├── hosts/                  # one directory per machine: hardware + identity + role choice
├── roles/                  # desktop and server compositions (kde, hyprland, xfce, base)
├── modules/                # host-agnostic pieces, each guarded by an option
├── pkgs/                   # sources a module installs (agent-sandbox, others)
├── home/                   # Home Manager profiles
├── tests/                  # one nixosTest per host, plus the proxy unit test
├── containers/dev/         # toolchain image, built with dockerTools
├── scripts/                # gates and helpers CI runs
└── documentation/          # the pages linked below
```

A host imports a role. A role imports modules. Nothing under `roles/` or
`modules/` may name a path under `hosts/`, and
`scripts/check-layering.py` fails CI when one does.

## Install

Install a host from a NixOS live ISO:

```bash
git clone https://github.com/ultus-net/nix.git /mnt/nix
nixos-install --root /mnt --flake /mnt/nix#tower
```

The account starts locked. Set the first password on the console after the
reboot:

```bash
passwd hunter
```

[INSTALL.md](documentation/INSTALL.md) carries the partitioning example, the LUKS
variant, and the post-install checks.

## Update

`tower` and `work-laptop` fast-forward their checkout to `origin/main` and
rebuild with `system.autoUpgrade`, so only commits that passed CI reach a
machine. `machines.autoUpgrade` records the schedule and the checkout path.
Input updates stay manual: `nix flake update`, then a rebuild.

## Documentation

| Page | Covers |
| --- | --- |
| [INSTALL.md](documentation/INSTALL.md) | Partitioning, `nixos-install`, first password, verification |
| [USAGE.md](documentation/USAGE.md) | Rebuilds, desktops, updates, rollback, agent sessions |
| [FEATURES.md](documentation/FEATURES.md) | Every module and what enables it |
| [ARCHITECTURE.md](documentation/ARCHITECTURE.md) | Layering, outputs, and why the tree looks like this |
| [AGENT-SANDBOX.md](documentation/AGENT-SANDBOX.md) | What an agent session can reach, and what it cannot |
| [PERFORMANCE.md](documentation/PERFORMANCE.md) | Gaming and kernel tuning, all opt-in |
| [SECRETS.md](documentation/SECRETS.md) | Credentials and where they live |
| [TROUBLESHOOTING.md](documentation/TROUBLESHOOTING.md) | Failures already hit, and their fixes |
| [FAQ.md](documentation/FAQ.md) | Decisions this tree encodes, and why |
| [CI-CD-GUIDE.md](.github/CI-CD-GUIDE.md) | What each workflow proves |
| [modules/](modules/README.md) | The module inventory |
| [roles/](roles/README.md) | The desktop roles |
| [hosts/](hosts/README.md) | Host conventions and overrides |
| [home/](home/README.md) | The Home Manager profiles |
| [scripts/](scripts/README.md) | Each script and its gate |
| [containers/dev/](containers/dev/README.md) | The toolchain image |

## Checks

`nix flake check` runs the layering gate, the password gate, the proxy unit test,
and one `nixosTest` per host that boots the real host module in QEMU. The build
job then builds each host's toplevel. `.github/workflows/ci.yml` is the only
workflow that gates `main`.
