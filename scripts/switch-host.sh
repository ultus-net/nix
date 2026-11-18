#!/usr/bin/env bash
set -euo pipefail

# Helper to build or switch to a named host from a flake.
# Usage:
#   ./scripts/switch-host.sh [<flake-ref>]
# If no <flake-ref> is provided the script defaults to `.#tower`.
# Examples:
#   ./scripts/switch-host.sh          # builds/switches to .#tower
#   ./scripts/switch-host.sh .#tower
#   ./scripts/switch-host.sh .#work-laptop

REF=".#tower"
if [ "$#" -gt 1 ]; then
  echo "Usage: $0 [<flake-ref>]  (e.g. .#tower or .#work-laptop)"
  exit 2
fi

if [ "$#" -eq 1 ]; then
  REF="$1"
fi

if [ "$(id -u)" -eq 0 ]; then
  echo "Running as root — switching system to $REF"
  nixos-rebuild switch --flake "$REF"
else
  echo "Not running as root — building the toplevel for $REF"
  nix build "$REF" || {
    echo "Build failed"
    exit 1
  }
  echo "Build complete. To switch as root, run: sudo nixos-rebuild switch --flake '$REF'"
fi
