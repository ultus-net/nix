# Usage

Day-to-day operation of an installed host: rebuild, switch a desktop, enable a
module, update, roll back.

## Rebuild

```bash
sudo nixos-rebuild switch --flake .#tower
```

`switch` activates immediately. `boot` makes the change take effect on the next
boot, which is what a kernel or NVIDIA change wants. `test` activates without
touching the boot entry, so a reboot undoes it.

Two build-only forms, for checking a change without touching the running system:

```bash
nixos-rebuild build --flake .#tower
nix build .#nixosConfigurations.tower.config.system.build.toplevel
```

## Switch desktop

A host picks its desktop by the role it imports. There is no runtime switch: the
role is a build input.

```nix
# hosts/tower/default.nix
imports = [
  ./hardware.nix
  ../../roles/noctalia.nix  # kde, dux, hyprland, xfce, noctalia, or base
];
```

`scripts/switch-desktop.sh <desktop> [host]` rewrites that import line and
rebuilds. The valid names are `kde`, `dux`, `hyprland`, `xfce`, `noctalia` and
`base`.

The Dux Shell and Noctalia roles each have a VM-only host, for looking at the
desktop without changing what a real machine runs:

```bash
nix build .#nixosConfigurations.dux-vm.config.system.build.vm
./result/bin/run-dux-vm-vm

nix build .#nixosConfigurations.noctalia-vm.config.system.build.vm
./result/bin/run-noctalia-vm-vm
```

Both VMs log in without a greeter: `dux-vm` through SDDM autologin, `noctalia-vm`
through greetd's `initial_session`, because `services.displayManager.autoLogin`
does not apply to greetd. Both ask QEMU for a virgl display, and the guest user
matches the desktop name. If the window is black, the host gave QEMU no GL
context; change `gtk,gl=on` to `sdl,gl=on` in that host's `default.nix`.

`hosts/example/` is a skeleton host with the option groups commented out. It is
there to be copied when a new machine joins; CI does not build it.

## Enable a module

Modules are opt-in, and most are guarded by an option under `machines.*`,
`gaming.*` or the module's own namespace. The import alone is not always enough.

```nix
imports = [ ../../modules/gaming.nix ];

gaming.enable = true;
gaming.kernelTuning = true;   # opt-in; never disables CPU mitigations
```

```nix
imports = [ ../../modules/multimedia.nix ];
multimedia.enable = true;
```

Three modules apply their defaults on import and take no option:
`development.nix`, `laptop.nix` and `common-packages.nix`. `modules/README.md`
holds the inventory, and `FEATURES.md` describes what each one installs.

## Update

`tower` and `work-laptop` set `machines.autoUpgrade.enable`. The unit fetches
`origin/main`, fast-forwards the checkout, and rebuilds. A commit reaches a
machine only after it passed CI, because the fast-forward only takes what is on
the remote branch.

Input updates stay manual, so a nixpkgs bump is a reviewed change:

```bash
nix flake update                          # all inputs
nix flake lock --update-input nixpkgs     # one input
sudo nixos-rebuild switch --flake .#tower
```

## Roll back

```bash
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
sudo nixos-rebuild switch --rollback
```

A specific generation:

```bash
sudo nix-env --switch-generation 42 --profile /nix/var/nix/profiles/system
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
```

`nix.gc` keeps three system generations and collects store paths older than 14
days, so the rollback window is short by design.

## Agent sessions

`tower` and `work-laptop` install `agent-sandbox`. It runs an agent against one
checkout in a throwaway container whose only route out is an allowlisting proxy.

```bash
sudo agent-sandbox run ~/Projects/some-checkout          # interactive shell
sudo agent-sandbox run ~/Projects/some-checkout -- claude
agent-sandbox list
agent-sandbox stop --all
```

[AGENT-SANDBOX.md](AGENT-SANDBOX.md) states the boundary, what it refuses, and
the first-run checks.

## Before pushing

CI runs the same gates, so a local run is the cheaper copy:

```bash
python3 scripts/check-layering.py
python3 scripts/check-layering.py --self-test
bash scripts/check-no-password-hash.sh .
python3 tests/agent-sandbox-proxy.py
nix flake check          # boots one VM per host, so it is the slow one
```

`bash -n scripts/*.sh` catches a shell syntax error without a build. The
`flake check` form is what gates `main`, and it takes 15 to 25 minutes because
each host test boots a real system in QEMU.

## Failure

`journalctl -b -u <unit>` for a service, `journalctl -xe` for the tail of
everything. `nixos-rebuild dry-run --flake .#tower` prints what a switch would
change. `TROUBLESHOOTING.md` holds the failures already hit here, with their
fixes.
