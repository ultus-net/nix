# Hosts

## Purpose
This directory holds one directory per machine, each with a `default.nix`
entry point. A host composes the shared defaults (`modules/base.nix`) with a
`roles/<name>.nix` entry and, when installing, an installer-generated
hardware file.

Shared modules are located under `modules/`. Host files can import them with
paths such as `../../modules/common-users.nix`.

## Quick Template

Example `hosts/my-pc/default.nix`:

```nix
{ config, pkgs, lib, ... }:
{
  # Shared defaults, the chosen role, and the shared users module.
  imports = [
    ../../modules/base.nix
    ../../roles/cosmic.nix
    ../../modules/common-users.nix
    ./hardware.nix  # generated during install
  ];
  networking.hostName = "my-pc";
}
```

## ZRAM Tuning
The zram module is provided at `modules/zram.nix` and exposes `machines.zram.*`
options. By default zram size is computed as min(total RAM / 2,
`machines.zram.maxSize`). You can override explicitly with `machines.zram.size`
or disable the heuristic with `machines.zram.enableAutoSize = false`.

## GC and Generation Retention
The machine master config (`modules/base.nix`) includes a weekly
systemd timer that:

- keeps the last **3** system generations
- runs `nix-collect-garbage --delete-older-than 14d` to remove older store paths

This is the default retention policy for machines; you can override it per
machine by replacing or disabling the unit.

## OpenSSH Hardening
OpenSSH is enabled by default with the following settings:

- password authentication disabled
- keyboard-interactive authentication disabled
- root login disabled

Override these per-machine if you need a different behavior.

## Override Examples

Temporarily allow SSH password login for an install session (not recommended
long-term):

```nix
services.openssh.settings.PasswordAuthentication = true;
services.openssh.settings.KbdInteractiveAuthentication = true;
```

Change retention policy (example: keep 5 generations and keep store paths for
30 days):

```nix
systemd.services.nixos-gc-keep-generations.serviceConfig.ExecStart = lib.mkForce ''
  /bin/sh -e -c '\
    PROFILE=/nix/var/nix/profiles/system; \
    KEEP=5; \
    GENS=$(nix-env --list-generations --profile "$PROFILE" | awk '\''/^[[:space:]]*[0-9]+/{gsub("\\*","",$1); print $1}'\'' | sort -n || true); \
    if [ -n "$GENS" ]; then \
      MAX=$(echo "$GENS" | tail -n1); \
      if [ "$MAX" -gt "$KEEP" ]; then \
        THRESH=$((MAX - KEEP)); \
        nix-env --profile "$PROFILE" --delete-generations "1-$THRESH" || true; \
      fi; \
    fi; \
    nix-collect-garbage --delete-older-than 30d || true'
'';
```

## Users
Centralized user creation lives in `modules/common-users.nix`. You can
declare multiple users by setting `machines.users` in a machine file; the
format matches the NixOS `users.users` attribute set.
