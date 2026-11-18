# Roles

## Purpose
This directory holds desktop "roles": small NixOS module fragments that
describe a desktop environment, related packages, and role-level features
(QoL, developer packages, desktop services). Roles do NOT set
machine-specific values such as `networking.hostName` or disk identifiers.
Each role carries a placeholder `fileSystems` block so the flake evaluates, and
the host overrides it.

These roles are **incomplete system configurations**. They
cannot be installed directly without adding:
1. Real `fileSystems` values (the role ships placeholders; use the host's `hardware.nix`)
2. At least one user account
3. A hostname

For a complete example, see `hosts/example/default.nix`.

## Available Roles

### Headless/Server Role

- **base.nix** - Minimal headless base (no desktop environment)
  - Essential CLI tools and modern replacements
  - Security hardening (firewall, fail2ban, SSH)
  - NetworkManager for network configuration
  - ZRAM compressed swap
  - Suitable for servers, containers, VMs, and headless systems
  - Optional modules include development, containers, sysadmin, and virtualization

### Desktop Environments

- **kde.nix** - KDE Plasma 6 (Qt-based)
  - Highly customizable
  - Wayland support
  - Wide range of applications

- **hyprland.nix** - Hyprland
  - Wayland compositor
  - Dynamic tiling and window management

- **xfce.nix** - XFCE
  - Low resource usage
  - Traditional desktop paradigm
  - Optional Wayland session available
  

## Usage
- To use a role when deploying to hardware, import it from a `hosts/`
  entry. For example:

  ```nix
  imports = [
    ../../modules/base.nix
    ../../roles/kde.nix
    ../../modules/common-users.nix
  ];
  networking.hostName = "my-pc";
  ```

- Roles are intentionally shareable: you can reuse the same role across
  many machines.

## Notes
- Keep roles focused on desktop-level concerns: session managers,
  desktop packages, and per-user Home Manager defaults. Avoid embedding
  disk UUIDs, LUKS settings, or bootloader device paths here.
