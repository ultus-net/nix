# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Changed

- `hosts/work-laptop` now describes the two-slot disk the Dell Pro 14 will
  carry. NixOS mounts a btrfs volume labelled `nixos` as `@root`, `@home`,
  `@nix` and `@boot`, keeps its generations off the 600M ESP it shares with
  the bootc slot, and boots with GRUB instead of systemd-boot. The previous
  values described an ext4 root, a swap partition and kernels on the ESP,
  none of which match that disk.
- `documentation/INSTALL.md` names both disk labels (`EFI` for the ESP and
  `nixos-root` for the root) and states what a mislabelled ESP costs: the
  machine installs and boots once, then keeps booting the old generation
  because rebuilds write the kernel into the root filesystem. It also records
  the two `hardware.nix` conventions, labels for identical machines and UUIDs
  for a single install, with the encrypted-root case named separately.
  `elitedesk-800-g4` is label-based, so identical EliteDesks share one file.
- Desktop applications moved out of the shared package set into the desktop
  roles: `chromium`, `spotify`, `zed-editor`, `opencode` and `discord`, and
  `thunar` on Xfce only. The headless role had installed a browser, a music
  client and a file manager. The shared set uses `yq-go` rather than the Python
  `yq`, matching the dev image.
- The shared set no longer carries `wl-clipboard` or four `nixos-artwork`
  wallpaper packs. `wl-clipboard` moved to `wayland-utils.nix`, and the only
  wallpapers are the ones in `assets/wallpapers`.
- Documentation is written for the owner, not for a contributor. `README.md` is
  the front page, and every page states what the tree does and why. Second-person
  tutorial tone, "getting started" framing and the contributor workflow are gone.
- Repository renamed from `nixos-base` to `nix`: GitHub URL, ghcr image
  (`ghcr.io/ultus-net/nix-dev`), clone paths in docs, and the `system.autoUpgrade`
  flake path, which is now `/home/hunter/Documents/nix`. **Action on each host:**
  rename the checkout directory to match before the next auto-upgrade, or point
  `flake` at wherever the checkout lives.
- Layering runs host -> role -> module. `machines/` became `hosts/`,
  `profiles/` became `roles/`, and shared defaults moved to `modules/base.nix`.
  `scripts/check-layering.py` fails CI if a role or module imports `hosts/`.
- Hosts declare `users.users` directly. `modules/common-users.nix` and its
  untyped `machines.users` option are gone. PINCE is a tower-only opt-in.
- Gaming tuning is opt-in per host through `gaming.kernelTuning`. CPU
  mitigations stay on for every host: `mitigations=off`, `tsc=reliable` and
  `clocksource=tsc` are removed. `kernel.yama.ptrace_scope` defaults to 1.
- Flake outputs are only `nixosConfigurations`, per-system `devShells` and
  `packages.dev-image`, `homeConfigurations`, `templates`, `formatter` and
  `checks`. The `<desktop>-workstation` outputs are removed, so a desktop is a
  role a host imports. `scripts/switch-desktop.sh <desktop> [host]` rewrites
  that import and rebuilds the host.
- Inputs are `nixpkgs` and `home-manager` only. `nixpkgs-stable`,
  `flake-utils` and `devshell` are gone, and `flake.lock` is refreshed to
  nixpkgs 2026-11-16.
- CI proves behaviour: branch-name check, `nix flake check` (layering,
  password gate, one `nixosTest` per host) and a toplevel build per host. The
  syntax-only jobs and the QEMU serial scraper are deleted.

### Removed

- `documentation/CONTRIBUTING.md`. The repository is public as a worked example
  and does not take pull requests, so a contribution guide described a workflow
  that does not exist.
- COSMIC, GNOME and Cinnamon support: their `roles/` bundles and `modules/`,
  the `nixos-cosmic` input, `scripts/export-cosmic.sh` and
  `documentation/QUICK-INSTALL-COSMIC.md`. KDE, Hyprland and XFCE remain.
- Flake outputs `cosmicImage`, `kdeImage`, `packages.default` and
  `homeManagerModules`, plus `modules/boot.nix`.
- `documentation/QUICK-INSTALL-CALAMARES.md`, which only described the COSMIC
  graphical install path.

### Added

- `hosts/elitedesk-800-g4/`: the HP EliteDesk 800 G4 Mini profile. Coffee Lake
  with UHD 630, so Intel microcode and `intel-media-driver` instead of NVIDIA.
  It runs Cockpit with `cockpit-machines` and `cockpit-podman`, libvirt, and the
  Podman runtime. The role import is the swappable line, so
  `scripts/switch-desktop.sh` turns the same host into a desktop test rig.
- `machines.containers.runtime` selects `docker` or `podman`. Podman adds a
  Docker-compatible CLI and socket, and `enableDockerCompose` installs
  `podman-compose` on that runtime. Docker stays the default, so `tower` is
  unchanged.
- `modules/cockpit.nix` (`cockpit.enable`): the Cockpit web console on port 9090
  over HTTPS. Every headless host gets it through `roles/base.nix`, and the
  firewall stays closed, so access is `ssh -L 9090:localhost:9090`. Plugins are
  per host through `cockpit.plugins`. Sign-in goes through PAM, so an account
  needs a password before the console is usable. A warning fires when the host
  has no normal account at all. Multi-host login and plain HTTP are pinned off.
- `modules/wayland-utils.nix` (`waylandUtils.enable`): the wlroots session
  baseline. `pwvucontrol`, `playerctl`, `brightnessctl`, `cliphist` with its
  `wl-paste` watcher, `satty`, `wlr-randr` and `wf-recorder`. The noctalia, dux
  and hyprland roles enable it.
- `modules/nix-index.nix` (`nixIndex.enable`): `nix-locate` and the
  command-not-found hook over an index of the flake's own nixpkgs. A daily user
  timer runs a `find` probe and rebuilds only when the cache is missing or older
  than `nixIndex.maxAgeDays`, so the expensive rebuild stays weekly. `tower`
  enables it.
- The shared package set gains `lnav`, `jless`, `watchexec`, `gitleaks`, `nh` and
  `nix-search-tv`.
- The shared package set carries `nix-output-monitor`, `nvd` and `nix-tree`, and
  the development toolchain adds `meson`, `ninja`, `ccache`, `clang`, `gdb` and
  `uv`. `tower` and `work-laptop` now import `development.nix`; no host did, so
  its list was unreachable.
- `sysadmin.nix` gains `mtr` and `ethtool`, `tower` enables
  `machines.containers.enableDockerCompose`, and the noctalia, dux and hyprland
  roles enable `services.gvfs` so their file managers get trash, removable
  devices and remote locations. Hyprland also gets `grim` and `slurp` with a
  Print binding that annotates in `satty`.
- `tower` enables `sysadmin`, `services.lact` and `programs.yubikey-manager`, and
  adds `goverlay` and `sbctl`. `nvtop` was already supplied by `nvidia.nix`, so
  no second GPU monitor is added.
  The home profile adds `zathura`, `pandoc`, `libreoffice`, `thunderbird`,
  `signal-desktop` and `keepassxc`, and `security.nix` adds `sops`.
- `dev-image` flake output and `containers/dev`: an OCI toolchain image with
  Node, Python, Go, and agent CLIs, built from the flake's nixpkgs. CI publishes
  it to `ghcr.io/ultus-net/nix-dev`.
- `modules/auto-upgrade.nix`: `machines.autoUpgrade` fast-forwards the checkout
  to `origin/main`, then rebuilds from the pinned lock. It is the only updater.
- `lib/forAllSystems.nix` and a `nixfmt-rfc-style` formatter output.
- `checks.<system>.<host>`: a `nixosTest` per host that boots the real host
  module in QEMU.
- `modules/agent-sandbox.nix`, enabled on `tower` and `work-laptop`
  (`machines.agentSandbox`): an `agent-sandbox` launcher for a transient
  `systemd-nspawn` session, and an allowlisting `CONNECT` proxy in front of its
  only egress. `documentation/AGENT-SANDBOX.md` states what it isolates and what
  it does not.
- `modules/dux.nix` and `roles/dux.nix`: the Dux Shell desktop (the renamed
  DankMaterialShell) on Hyprland via `programs.dux-shell`. `hosts/dux-vm/` is a
  VM-only host that autologins to it, built with
  `nix build .#nixosConfigurations.dux-vm.config.system.build.vm`.
- `roles/noctalia.nix` and `modules/noctalia.nix`: the Noctalia desktop
  (Umbriel compositor, Noctalia shell bound to `umbriel-session.target`, the
  greetd-based `noctalia-greeter`) and `pkgs/luciole` packaged in-tree at a
  pinned upstream commit and exported as `packages.<system>.luciole`.
  `hosts/noctalia-vm/` is a VM-only preview that starts Umbriel straight from
  greetd, built with
  `nix build .#nixosConfigurations.noctalia-vm.config.system.build.vm`.
- `tower` boots Noctalia, not KDE. Its `imports` now name
  `roles/noctalia.nix`, and the KDE option block and the SDDM `kscreen`
  tmpfiles rule are deleted from the host.

### Fixed

- The `dux-vm` host test asserted `systemctl is-enabled sddm.service`, which
  exits 4 because SDDM is reached through `display-manager.service` rather than
  by its own unit name. It now asserts that alias exists.
- The `cliphist` watcher was bound to `graphical-session.target`, which neither
  Umbriel nor Hyprland starts. It now binds to `waylandUtils.sessionTarget`, and
  the noctalia, dux and hyprland roles set the real target. It also restarts on
  failure, because a dead watcher stops clipboard history for the session.
- `gaming.nix` filtered its package list by attribute presence, which hid four
  entries nixpkgs had dropped (`latencyflex`, `libFAudio`, `obs_vkcapture`,
  `mangohud-profiles`) and made `enableI386Compat` a no-op because
  `lib32Packages` does not exist. The list is explicit, `faudio` replaces
  `libFAudio`, and the 32-bit set comes from `pkgsi686Linux`. Steam Remote Play
  and the dedicated-server firewall openings are now options defaulting to
  `false`; both were unconditionally open.
- `obs-studio` was installed as a bare package, so the capture plugin would not
  have loaded. It comes from `programs.obs-studio` with `obs-vkcapture` wrapped
  in. `wireshark` comes from `programs.wireshark`, which supplies the `dumpcap`
  setcap wrapper, and `tower` adds `hunter` to the `wireshark` group.
  `yubikey-manager` comes from `programs.yubikey-manager`, which enables PC/SC
  and the udev rules; the bare package could not reach the key.
- `security.nix` put `fprintd` and `avahi` on every host it was imported by,
  including the headless `base-server`. Both are now `securityDefaults`
  options defaulting to `false`, and `tower` sets them.
- `virtualization.nix` listed `virt-manager` and `OVMF` beside
  `programs.virt-manager.enable` and the libvirtd QEMU firmware settings.
  `modules/wallpapers.nix` carried an unused `wallpaperPackages` binding of 44
  `nixos-artwork` derivations. Both are deleted.
- The dev shell pinned the Python `yq` while the shared set and the dev image
  use `yq-go`, so the same command had two implementations. The shell uses
  `yq-go`.
- `modules/sysadmin.nix` did not evaluate: it listed `dogdns`, which nixpkgs
  removed in favour of `doggo`. No host had enabled the module, so the break was
  invisible until `tower` turned it on.
- The desktop preview VMs ask QEMU for a plain `virtio-vga` and render through
  Mesa. Virgl aborted QEMU with `Couldn't find current GLX or EGL context` on a
  host that gave it no GL context, so the preview died before the guest booted.
  The GTK and SDL backends failed the same way. The device also sets
  `xres=1920,yres=1080`, because QEMU's default 1280x800 mode is magnified by the
  GTK console to fill the window.
- `pince` comes from nixpkgs. The in-tree package pinned `v0.4.4`, a tag
  upstream has since dropped, so `nix build .#nixosConfigurations.tower`
  failed on a 404. The 260-line local patch set is deleted with it.
- The password-hash gate searched for its own needle and matched the option
  name in comments and in `flake.nix`. The needle is now assembled at runtime
  in `scripts/check-no-password-hash.sh`, and the search skips hidden
  directories.
- The `work-laptop` host test asserted `systemctl is-enabled fwupd.service`.
  fwupd's unit is linked into `/etc/systemd/system` rather than enabled, so
  `is-enabled` exits 1 and the test failed on `main`. It now asserts
  `tlp.service`, which this host enables through `services.tlp`.

### Security

- No password hash is committed for a real host. The account starts locked and
  the first password is set on the console after the first switch. CI fails if
  `initialHashedPassword` appears outside `hosts/example/`.
- An agent session cannot reach the internet directly: it has no network
  interface except loopback, and its one route out is a unix socket to a proxy
  that accepts `CONNECT` on port 443 for allowlisted names only. A literal IP is
  refused and there is no resolver inside the session.
- The proxy resolves a name once, keeps only addresses that are globally
  routable and unicast, and dials one of those addresses. An allowed name cannot
  point the session at a LAN host, at loopback, at a link-local address, or at a
  multicast group, and no second lookup can change where the dial goes.
- An agent session cannot use the Nix daemon, so it cannot build a
  fixed-output derivation whose builder would run on the host network. The store
  is mounted read-only and the daemon socket is not mounted.
- `checks.<system>.agent-sandbox-proxy` exercises the proxy's allowlist matching,
  its address classification and its dialer, so a widening of any of them fails
  CI.
- The auto-upgrade unit trusts only its configured checkout (`safe.directory`
  names that path) rather than every repository git can see.

### Added - Performance Optimizations (January 2026, superseded)

The tuning below was added in one pass and later narrowed. `mitigations=off`,
`tsc=reliable`, `clocksource=tsc`, the kyber scheduler and `ntsync.enable=1` are
removed, and the remaining set is opt-in per host through
`gaming.kernelTuning`. `documentation/PERFORMANCE.md` lists what is in effect
now. Everything here is kept as history.

#### System-Level Improvements
- **zram compression swap**: 8GB max with zstd algorithm for better memory management and reduced SSD wear
- **Performance CPU governor**: Maximum frequency mode for desktop responsiveness
- **Gamemode integration**: Automatic CPU/GPU performance boost for gaming
- **Optimized I/O schedulers**: 
  - kyber for NVMe (gaming workloads)
  - mq-deadline for SATA SSDs (QLC optimization)
- **TCP BBR congestion control**: Improved network throughput and latency
- **SSD-optimized mount options**: noatime, nodiratime, discard=async, commit=60 on all filesystems
- **tmpfs for /tmp**: 50% RAM max for faster temporary file operations
- **Boot optimizations**: Reduced timeout to 3s, systemd journal size limits (500MB/1week)

#### Kernel Tuning
- **Low-latency parameters**: 
  - `mitigations=off` for 5-10% CPU performance gain
  - `processor.max_cstate=1` for reduced wake latency
  - `ntsync.enable=1` for 10-20% Wine/Proton performance boost
  - `tsc=reliable` and `clocksource=tsc` for stable high-performance timing
  - `transparent_hugepage=always` for better memory performance
- **sysctl tuning**:
  - `vm.swappiness=10` - prefer RAM over swap
  - `vm.vfs_cache_pressure=50` - better filesystem cache
  - `vm.dirty_ratio=10` - optimized write behavior
  - Network performance tuning for gaming/streaming

#### User Environment
- **Wayland session variables**: Proper configuration for MOZ_ENABLE_WAYLAND, NIXOS_OZONE_WL, etc.
- **Gaming environment variables**: 
  - WINEFSYNC for ntsync support
  - VK_ICD_FILENAMES for NVIDIA GPU preference
  - STEAM_EXTRA_COMPAT_TOOLS_PATHS for Proton tools

#### Documentation
- **[PERFORMANCE.md](documentation/PERFORMANCE.md)**: Comprehensive performance tuning guide
  - Detailed explanation of each optimization
  - Verification commands and benchmarking
  - Troubleshooting common issues
  - Reverting changes when needed
- **[verify-performance.sh](scripts/verify-performance.sh)**: Automated verification script
  - Checks all performance settings
  - Color-coded output for easy verification
  - Boot time analysis

#### Configuration Changes
- **tower.nix**: Added performance optimization section with all system-level tuning
- **home/hunter.nix**: Enabled session variables for Wayland and gaming optimization
- **zram module**: Now imported and configured in tower configuration
- **Swapfile size**: Reduced from 32GB to 16GB (zram handles primary swapping)

### Expected Performance Improvements
- Boot time: 15-20% faster (41s → 33-35s)
- Gaming FPS: 5-15% improvement
- System responsiveness: Significantly smoother under load
- Network performance: 10-30% better throughput on high-latency connections
- SSD lifespan: Extended by ~30% through reduced write operations

### Security Considerations
- `mitigations=off` disables Spectre/Meltdown protections
- Acceptable for gaming desktop, **NOT recommended for servers**
- Can be reverted by commenting out kernel parameter

---

## Previous Versions

### NVIDIA Driver Improvements (January 2026)
- Enabled `hardware.nvidia.powerManagement.enable` for suspend/resume stability
- Switched to open NVIDIA kernel module (`hardware.nvidia.open = true`)
- Fixed Xid 13 GPU crashes on wake from suspend

### Initial Release
- Modular NixOS flake supporting 6 desktop environments
- COSMIC (System76) desktop integration
- Home Manager configuration templates
- Comprehensive documentation suite
- Automated installation scripts

---

**Note**: This changelog documents major changes. For complete commit history, see the Git log.
