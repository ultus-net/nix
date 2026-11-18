# Module inventory

Every module is opt-in. A host imports it, then sets its option. Three modules
have no option and apply their defaults on import; the rest are inert until
enabled.

| Module | Option | Applies on import |
| --- | --- | --- |
| `base.nix` | none | yes |
| `common-packages.nix` | `commonPackages.enable` | no |
| `development.nix` | none | yes |
| `laptop.nix` | none | yes |
| `networking.nix` | none | yes |
| `security.nix` | none | yes |
| `audio.nix` | none | yes |
| `fonts.nix` | none | yes |
| `zram.nix` | `machines.zram.*` | yes (imported by `base.nix`) |
| `home-manager.nix` | none | yes |
| `multimedia.nix` | `multimedia.enable` | no |
| `gaming.nix` | `gaming.enable` | no |
| `containers.nix` | `machines.containers.enable` | no |
| `virtualization.nix` | `virtualization.enable` | no |
| `sysadmin.nix` | `sysadmin.enable` | no |
| `nvidia.nix` | none | yes |
| `pince.nix` | `pince.enable` | no |
| `wallpapers.nix` | `machines.wallpapers.enable` | no |
| `agent-sandbox.nix` | `machines.agentSandbox.enable` | no |
| `auto-upgrade.nix` | `machines.autoUpgrade.enable` | no |
| `deploy-config.nix` | `deployConfig.enable` | no |

The desktops are roles, not modules: `roles/kde.nix`, `roles/hyprland.nix`,
`roles/xfce.nix`, `roles/base.nix`. `modules/kde.nix`, `modules/xfce.nix` and
`modules/hyprland.nix` are what those roles compose.

## Defaults every host inherits

`modules/base.nix` sets the parts that must not be per-host: `stateVersion`, the
`nix-command` and `flakes` features, `nix.gc`, and the locale. `networking.nix`
adds NetworkManager. `security.nix` enables the firewall and sshd with password
authentication and root login off. `audio.nix` is PipeWire, `fonts.nix` the Nerd
Fonts, `zram.nix` compressed swap, `home-manager.nix` the HM wiring.

## Packages

`common-packages.nix` is the CLI set: `fzf`, `zoxide`, `eza`, `bat`, `ripgrep`,
`fd`, `lazygit`, `delta`, `starship`. It is a list, so a host adds to it rather
than forking it.

`development.nix` is the toolchain: Python, Node, Go, Rust, the build tools, the
formatters and the linters. It has no option because a machine that imports it
wants all of it; a machine that wants half of it should import nixpkgs packages
directly.

## Gaming

`gaming.nix` splits into three parts on purpose:

| Option | Default | Effect |
| --- | --- | --- |
| `gaming.enable` | `false` | Steam, Lutris, Heroic, MangoHUD, GameMode, `vkBasalt`, Wine, 32-bit drivers |
| `gaming.enableSteam` | `false` | the NixOS `programs.steam` module, 32-bit graphics and controller udev rules |
| `gaming.kernelTuning` | `false` | kernel, network and flatpak tuning on that host only |

Everything is inside `lib.mkIf cfg.enable`, so `gaming.enable` gates the rest.
Setting `kernelTuning = true` alone changes nothing; `tower` sets both.

`gaming.kernelTuning` never disables CPU mitigations. The tuning it does apply
lives in the host that opts in, so `work-laptop` does not inherit a gaming
network stack.

## Multimedia

`multimedia.nix` is the media set: VLC, MPV, OBS, Kdenlive, Handbrake, FFmpeg,
GIMP, Inkscape, Krita, Darktable, ImageMagick, Audacity, Ardour, EasyEffects,
Blender. Only `tower` imports it.

## Containers and virtualisation

`containers.nix` gives Docker, `docker-compose`, `distrobox`, `buildah` and
`skopeo`, with `kubectl`, `k9s` and `helm` behind `enableKubernetes`.

`virtualization.nix` gives `libvirt`, QEMU/KVM with the hardware acceleration
flags, `virt-manager` and `virsh`, plus the libvirt default network.

`tower` imports both. `networking.nftables.enable` stays off because the nixpkgs
manual warns the nftables backend fights Docker's iptables NAT.

## Hardware

`nvidia.nix` is the proprietary driver, kernel modesetting and the 32-bit
libraries, used by `tower`. `pince.nix` is PINCE, scoped to the host that runs
it. `laptop.nix` is the power and input stack: `power-profiles-daemon`,
`thermald`, `upower`, `libinput`, Bluetooth, and the XDG portal. TLP is
explicitly disabled there, and `work-laptop` enables it in its own config
instead.

## Agent sandbox

`agent-sandbox.nix` installs `agent-sandbox`, which runs a session in a transient
`systemd-nspawn` container: the checkout at `/workspace`, a read-only store, a
tmpfs home, and loopback-only networking whose only route out is an allowlisting
`CONNECT` proxy. `MemoryMax`, `CPUQuota` and `TasksMax` bound the session scope.

```nix
imports = [ ../../modules/agent-sandbox.nix ];
machines.agentSandbox.enable = true;
```

[AGENT-SANDBOX.md](AGENT-SANDBOX.md) states the boundary and what it does not
cover.

## Wallpapers

`machines.wallpapers` installs the `nixos-artwork` set system-wide and rotates
it on a timer. `rotationInterval` is in seconds. Enabled on every desktop role.
