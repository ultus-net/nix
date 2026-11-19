# Roles

A role is a desktop or server composition: the modules it needs and the defaults
that belong to that desktop. One role per output, imported by a host.

| File | Composition |
| --- | --- |
| `kde.nix` | KDE Plasma 6 on Wayland, SDDM, the KDE app set, wallpapers |
| `hyprland.nix` | Hyprland, Waybar, Wofi, Kitty, wallpapers |
| `xfce.nix` | XFCE on X11, Thunar, wallpapers |
| `dux.nix` | Dux Shell on Hyprland, SDDM, the Dux packages |
| `base.nix` | headless: CLI set, security, NetworkManager, zram |

`base-server` is built straight from `roles/base.nix` by `flake.nix`, so the
headless composition keeps compiling without a host directory behind it.

## What a role may contain

- Module imports and the option values that every machine on that desktop wants.
- Desktop services: display manager, session variables, portal backends.
- Placeholder `fileSystems` entries with `lib.mkDefault`, so the flake evaluates
  before a host has a real disk. The host's `hardware.nix` wins.

## What a role may not contain

| Not this | Because |
| --- | --- |
| `networking.hostName` | identity, and a role is shared |
| disk UUIDs, LUKS, bootloader device paths | hardware, and a role is shared |
| a user account | each host owns its accounts |
| a path under `hosts/` | the layering gate fails the build |

The last row is the one CI enforces. `scripts/check-layering.py` strips comments
and string bodies, then fails on any code reference to `hosts/` under `roles/` or
`modules/`.

## Using one

```nix
# hosts/<name>/default.nix
imports = [
  ./hardware.nix
  ../../roles/kde.nix
];
```

A role is not installable on its own. It has no disk, no hostname and no user
until a host supplies them. `hosts/example/` is the skeleton that shows the
whole shape.
