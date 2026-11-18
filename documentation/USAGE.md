# Usage Guide

## TL;DR

```bash
# Switch desktops (already installed system)
sudo nixos-rebuild switch --flake .#tower

# Update packages
nix flake update && sudo nixos-rebuild switch --flake .#your-host

# Test in VM before deploying
nix build .#nixosConfigurations.tower.config.system.build.vm
./result/bin/run-*-vm

# Create custom machine config (advanced)
cp hosts/example/default.nix hosts/my-machine/default.nix
# Edit my-machine.nix, then reference it in flake.nix
```

## Quick Start

### For New Installations

1. Boot the NixOS live ISO
2. Partition and mount your disk to `/mnt`
3. Clone this repository:
   ```bash
   cd /mnt
   git clone https://github.com/ultus-net/nix
   ```
4. Generate hardware configuration:
   ```bash
   nixos-generate-config --root /mnt
   ```
5. Install a host:
   ```bash
   nixos-install --flake /mnt/nix#tower
   ```

See `INSTALL.md` for detailed installation instructions.

## Switching Desktops

A host chooses its desktop by the role it imports. Edit the host entry point,
change the role, then rebuild:

```bash
# hosts/tower/default.nix imports ../../roles/kde.nix
sudo nixos-rebuild switch --flake .#tower
```

Available roles are `roles/kde.nix`, `roles/hyprland.nix`, `roles/xfce.nix`
and `roles/base.nix` for a headless host. `scripts/switch-desktop.sh <desktop>
[host]` rewrites the host's role import and rebuilds that host.

### Test Without Switching
```bash
# Build without activating
nixos-rebuild build --flake .#tower

# Or using nix directly
nix build .#nixosConfigurations.tower.config.system.build.toplevel
```

## Helper Scripts

### Switch Host Script
Use the provided script to build or switch configurations:

```bash
# Build the default configuration
./scripts/switch-host.sh

# Switch a host (requires root)
sudo ./scripts/switch-host.sh .#tower
sudo ./scripts/switch-host.sh .#work-laptop
```

### Desktop Switcher
```bash
# Interactive desktop environment switcher
./scripts/switch-desktop.sh
```

### Validation
```bash
# Validate configurations before deploying
./scripts/validate-hosts-home-manager.sh
```

See `scripts/README.md` for complete script documentation.

## Creating Your Own Machine Configuration

**When do you need this?** 
- You want to customize beyond what roles offer
- You're setting up multiple machines with different hardware
- You want machine-specific settings (hostname, users, hardware config)

**Don't need this if:**
- You just want to use a pre-built desktop (import a role)
- You're testing different desktops (just change the role import)

### Steps:

1. Copy the example machine template:
   ```bash
   cp hosts/example/default.nix hosts/my-machine/default.nix
   ```

2. Edit `hosts/my-machine/default.nix`:
   ```nix
   { config, pkgs, lib, inputs, ... }:
   {
     imports = [
       ../../modules/base.nix        # Shared defaults
       ./hardware.nix                # Your hardware config
       ../../roles/kde.nix           # Choose your desktop
     ];

     # Set your hostname
     networking.hostName = "my-machine";

     # Add your user
     users.users = {
       yourname = {
         enable = true;
         isAdmin = true;
         shell = pkgs.bash;
       };
     };
   }
   ```

3. Add to `flake.nix`:
   ```nix
   nixosConfigurations = {
     # ... existing configs ...
     my-machine = mkSystem ./hosts/my-machine/default.nix;
   };
   ```

4. Build and switch:
   ```bash
   sudo nixos-rebuild switch --flake .#my-machine
   ```

See `hosts/README.md` for detailed machine configuration guide.

## Enabling Optional Modules

### Add Multimedia Support
```nix
imports = [
  ../modules/multimedia.nix
];

multimedia.enable = true;
```

### Add Gaming Support
```nix
imports = [
  ../modules/gaming.nix
];

gaming.enable = true;
gaming.enableSteam = true;
```

### Add Development Tools
```nix
imports = [
  ../modules/development.nix
];
```

### Laptop Configuration
```nix
imports = [
  ../modules/laptop.nix
];
```

See `FEATURES.md` for all available modules.

## Testing in a VM

Build and run a VM to test configurations before deploying:

```bash
# Build VM
nix build .#nixosConfigurations.work-laptop.config.system.build.vm

# Run VM
./result/bin/run-*-vm
```

## Agent Sessions

`tower` and `work-laptop` install `agent-sandbox`. It runs an agent against one
checkout in a throwaway container with no route to the internet except an
allowlisting proxy:

```bash
sudo agent-sandbox run ~/Projects/some-checkout          # interactive shell
sudo agent-sandbox run ~/Projects/some-checkout -- claude
agent-sandbox list
agent-sandbox stop --all
```

What the session can reach, what it cannot, and the first-run checks are in
[AGENT-SANDBOX.md](AGENT-SANDBOX.md).

## Updating Your System

A host with `machines.autoUpgrade.enable` rebuilds from `origin/main` on its own
schedule, after fast-forwarding the checkout, so only commits that passed CI
reach it. To update by hand:

```bash
# Update all inputs
nix flake update

# Update specific input
nix flake lock --update-input nixpkgs
```

### Rebuild After Update
```bash
sudo nixos-rebuild switch --flake .#your-host
```

## Rolling Back

If something goes wrong, you can rollback to a previous generation:

```bash
# List available generations
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Rollback to previous generation
sudo nixos-rebuild switch --rollback

# Switch to specific generation
sudo nix-env --switch-generation <number> --profile /nix/var/nix/profiles/system
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
```

## Local Testing

Before pushing changes, test locally:

```bash
# Quick validation
nix flake check

# Build specific configuration
nix build .#nixosConfigurations.tower.config.system.build.toplevel

# Test VM boot
nix build .#nixosConfigurations.work-laptop.config.system.build.vm
./result/bin/run-*-vm
```

## Troubleshooting

If you encounter issues:

1. Check `TROUBLESHOOTING.md` for common problems and solutions
2. Review logs: `journalctl -xe`
3. Verify configuration: `nixos-rebuild dry-run --flake .#your-host`
4. Ask for help in the NixOS community channels

## Next Steps

- Read `FEATURES.md` to explore available modules
- Check `CONTRIBUTING.md` to add your own customizations
- Review `SECRETS.md` for secrets management
- Explore `modules/README.md` for module documentation
