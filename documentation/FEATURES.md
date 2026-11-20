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
| `security.nix` | `securityDefaults.*` | yes |
| `audio.nix` | none | yes |
| `fonts.nix` | none | yes |
| `zram.nix` | `machines.zram.*` | yes (imported by `base.nix`) |
| `home-manager.nix` | none | yes |
| `multimedia.nix` | `multimedia.enable` | no |
| `gaming.nix` | `gaming.enable` | no |
| `containers.nix` | `machines.containers.enable` | no |
| `virtualization.nix` | `virtualization.enable` | no |
| `sysadmin.nix` | `sysadmin.enable` | no |
| `wayland-utils.nix` | `waylandUtils.enable` | no |
| `nvidia.nix` | none | yes |
| `pince.nix` | `pince.enable` | no |
| `wallpapers.nix` | `machines.wallpapers.enable` | no |
| `agent-sandbox.nix` | `machines.agentSandbox.enable` | no |
| `auto-upgrade.nix` | `machines.autoUpgrade.enable` | no |
| `deploy-config.nix` | `deployConfig.enable` | no |
| `dux.nix` | `dux.enable` | no |
| `noctalia.nix` | `noctalia.enable` | no |

The desktops are roles, not modules: `roles/kde.nix`, `roles/noctalia.nix`,
`roles/hyprland.nix`, `roles/xfce.nix`, `roles/dux.nix`, `roles/base.nix`.
`modules/kde.nix`, `modules/noctalia.nix`, `modules/xfce.nix`,
`modules/hyprland.nix` and `modules/dux.nix` are what those roles compose.

## Defaults every host inherits

`modules/base.nix` sets the parts that must not be per-host: `stateVersion`, the
`nix-command` and `flakes` features, `nix.gc`, the locale, and sshd with password
authentication and root login off. `networking.nix` adds NetworkManager.
`security.nix` applies the firewall, the SSH agent and `sops`, and gates the two
desktop extras behind options: `securityDefaults.enableFprintd` and
`securityDefaults.enableAvahi` both default to `false`, so a headless host gets
neither a fingerprint daemon nor an mDNS responder. `tower` sets both.
`audio.nix` is PipeWire, `fonts.nix` the Nerd Fonts, `zram.nix` compressed swap,
`home-manager.nix` the HM wiring.

## Packages

`common-packages.nix` is the CLI set: `fzf`, `zoxide`, `eza`, `bat`, `ripgrep`,
`fd`, `lazygit`, `delta`, `starship`. It also carries `nix-output-monitor`,
`nvd` and `nix-tree`, because every host rebuilds itself. It is a list, so a
host adds to it rather than forking it. Desktop applications do not belong
here: `chromium`, `spotify`, `zed-editor`, `opencode` and `discord` come from
the role that owns the desktop, so the headless role stays headless.

`wayland-utils.nix` is the wlroots session baseline: `wl-clipboard`,
`pwvucontrol`, `playerctl`, `brightnessctl`, `cliphist`, `satty`, `wlr-randr`
and `wf-recorder`. `waylandUtils.sessionTarget` names the systemd user target
the compositor starts, because the `cliphist` watcher binds to it: Umbriel
starts `umbriel-session.target` and Hyprland starts `hyprland-session.target`,
so a watcher bound to `graphical-session.target` never runs. The noctalia, dux
and hyprland roles enable it and set the target. KDE and Xfce bring their own
equivalents.

`development.nix` is the toolchain: Python, Node, Go, Rust, the build tools, the
formatters and the linters. It has no option because a machine that imports it
wants all of it; a machine that wants half of it should import nixpkgs packages
directly.

## Gaming

`gaming.nix` is all behind `gaming.enable`, so every option below is inert
until a host turns the module on.

| Option | Default | Effect |
| --- | --- | --- |
| `gaming.enable` | `false` | Steam, Lutris, Heroic, MangoHUD, GameMode, `vkBasalt`, Wine, 32-bit drivers |
| `gaming.enableSteam` | `false` | the NixOS `programs.steam` module, 32-bit graphics and controller udev rules |
| `gaming.enableI386Compat` | `false` | the i686 Vulkan loader and FAudio from `pkgsi686Linux` |
| `gaming.steamRemotePlayFirewall` | `false` | opens the Steam Remote Play ports |
| `gaming.steamDedicatedServerFirewall` | `false` | opens the Source dedicated-server ports |
| `gaming.kernelTuning` | `false` | kernel, network and flatpak tuning on that host only |

Both firewall options stay closed. Remote Play needs its ports only while
streaming, and the dedicated-server ports only when hosting one, so a host
opens them deliberately rather than inheriting them.

The package list is explicit, not presence-filtered. A package that leaves
nixpkgs fails evaluation here instead of disappearing from the set silently.
That filter had already hidden four dead entries.

Everything is inside `lib.mkIf cfg.enable`, so `gaming.enable` gates the rest.
Setting `kernelTuning = true` alone changes nothing; `tower` sets both.

`gaming.kernelTuning` never disables CPU mitigations. The tuning it does apply
lives in the host that opts in, so `work-laptop` does not inherit a gaming
network stack.

## Multimedia

`multimedia.nix` is the media set: VLC, MPV, Feh, Imv, GIMP, ImageMagick, FFmpeg
and `yt-dlp`, plus the screenshot tools `grim`, `slurp`, `flameshot` and `peek`.
OBS comes from `programs.obs-studio` with the `obs-vkcapture` plugin wrapped in,
so game capture reaches it; a bare `obs-studio` package ignores plugins.
Kdenlive, Blender and Shotcut sit behind `enableVideoEditing`, and Audacity and
Ardour behind `enableAudioProduction`, both defaulting to `false`. Only `tower`
imports it.

## Containers and virtualisation

`containers.nix` gives Docker, with `docker-compose`, `distrobox` and `boxbuddy`,
`kubectl`, `k9s`, `helm`, `kubectx` and `kustomize` behind their own options.
`tower` enables Docker and Compose.

`virtualization.nix` gives `libvirt`, QEMU/KVM with the hardware acceleration
flags, `virt-manager` through its program option, `virt-viewer` and `virsh`, plus
the libvirt default network. Firmware comes from the libvirtd QEMU settings, so
the module no longer lists `OVMF` separately.

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

`machines.wallpapers` installs the local wallpapers from `assets/wallpapers`
under `/share/backgrounds`. It carries no `nixos-artwork` packages and no
rotation timer, so `rotationInterval` is currently unused. Enabled on every
desktop role.
