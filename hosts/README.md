# Hosts

One directory per machine. A host is the leaf of the tree: identity, hardware,
and the role it picks.

| Host | Role | Notes |
| --- | --- | --- |
| `tower/` | `noctalia.nix` | NVIDIA, gaming, multimedia, Docker, libvirt, PINCE, agent sandbox |
| `work-laptop/` | `kde.nix` | TLP, fwupd, DisplayLink, agent sandbox |
| `dux-vm/` | `dux.nix` | VM-only preview: SDDM autologin, software-rendered virtio GPU, no hardware |
| `noctalia-vm/` | `noctalia.nix` | VM-only preview: greetd autostart, software-rendered virtio GPU, no hardware |
| `example/` | `kde.nix` | skeleton, copied when a machine joins; not built by CI |

`base-server` has no directory. It is `mkSystem ./roles/base.nix` in
`flake.nix`, which keeps the headless role under `flake check` without
inventing a machine.

## A host directory

```
hosts/tower/
├── default.nix    # imports, hostname, users, host-only options
└── hardware.nix   # filesystems, bootloader, kernel modules
```

`hardware.nix` is what `nixos-generate-config` writes. Nothing else in the tree
sets `fileSystems` except a role's `lib.mkDefault` placeholder, so a stale
`hardware.nix` is the usual cause of a failed install.

## What belongs here

- `imports`: `./hardware.nix`, the chosen role, and any module this host alone
  needs. `base.nix` arrives through the role; importing it twice is harmless and
  usually redundant.
- `networking.hostName`, and anything else that is true of this machine only.
- The user account. There is no shared users module; a host owns its accounts.
- Host-only options: `machines.autoUpgrade`, `machines.agentSandbox`,
  `machines.wallpapers`, `gaming.kernelTuning`, DisplayLink, PINCE.

## What does not

A change that more than one host would want belongs in `roles/` or `modules/`,
not here. If a host needs a new module, the module takes an option and the host
sets it.

## Overrides

A host wins over a role because a role uses `lib.mkDefault` for anything a
machine might differ on. Retention and zram sizing live in `modules/base.nix`
and `modules/zram.nix`; `FEATURES.md` carries the option lists, so this file
does not restate them.

## Adding a machine

1. `cp -r hosts/example hosts/<name>`.
2. Install on the target, then copy the generated
   `hardware-configuration.nix` over `hosts/<name>/hardware.nix`.
3. Set the role import, the hostname and the account.
4. Add one line to `nixosConfigurations` in `flake.nix`:
   `mkSystem ./hosts/<name>/default.nix`.
5. Add a `nixosTest` in `tests/hosts.nix`, or the host is not gated.

That last step is the one that gets skipped. A host with no test is a host whose
next module change can break it silently.
