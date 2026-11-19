#!/usr/bin/env bash
set -euo pipefail

# Point a host at a different desktop role, then rebuild that host.
# Usage: ./scripts/switch-desktop.sh <desktop> [host]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

DESKTOPS=(kde xfce hyprland dux)

show_usage() {
  echo "Usage: $0 <desktop> [host]"
  echo ""
  echo "Available desktops:"
  for desktop in "${DESKTOPS[@]}"; do
    echo "  - $desktop"
  done
  echo ""
  echo "Available hosts:"
  for host_file in "$REPO_ROOT"/hosts/*/default.nix; do
    echo "  - $(basename "$(dirname "$host_file")")"
  done
  echo ""
  echo "Example: $0 hyprland tower"
  exit 1
}

[ "$#" -ge 1 ] || show_usage

DESKTOP="$1"
HOST="${2:-$(hostname -s)}"

if [[ ! " ${DESKTOPS[*]} " =~ " ${DESKTOP} " ]]; then
  echo "Error: unknown desktop '$DESKTOP'"
  show_usage
fi

ROLE_PATH="$REPO_ROOT/roles/${DESKTOP}.nix"
HOST_FILE="$REPO_ROOT/hosts/${HOST}/default.nix"

[ -f "$ROLE_PATH" ] || { echo "Error: role not found at $ROLE_PATH"; exit 1; }
[ -f "$HOST_FILE" ] || { echo "Error: host not found at $HOST_FILE"; show_usage; }

CURRENT_ROLE="$(grep -oE '\.\./\.\./roles/[a-z]+\.nix' "$HOST_FILE" | head -1 || true)"
NEW_ROLE="../../roles/${DESKTOP}.nix"

if [ "$CURRENT_ROLE" = "$NEW_ROLE" ]; then
  echo "$HOST already imports $NEW_ROLE; nothing to change."
  exit 0
fi

TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT

if [ -n "$CURRENT_ROLE" ]; then
  awk -v old="$CURRENT_ROLE" -v new="$NEW_ROLE" '
    !done && index($0, old) { sub(old, new); done = 1 } { print }
  ' "$HOST_FILE" > "$TMP_FILE"
else
  awk -v new="    $NEW_ROLE" '
    !done && /\.\.\/\.\.\/modules\/base\.nix/ { print; print new; done = 1; next } { print }
  ' "$HOST_FILE" > "$TMP_FILE"
fi

echo "Host $HOST: ${CURRENT_ROLE:-no desktop role} -> $NEW_ROLE"
echo ""
diff -u "$HOST_FILE" "$TMP_FILE" || true
echo ""
read -p "Apply and rebuild $HOST? (y/N) " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi

cp "$TMP_FILE" "$HOST_FILE"

if [ "$EUID" -ne 0 ]; then
  SUDO="sudo"
else
  SUDO=""
fi

$SUDO nixos-rebuild switch --flake "$REPO_ROOT#${HOST}"

echo ""
echo "Switched $HOST to $DESKTOP."
echo "Log out and back in, and pick the session in the display manager."
echo "Roll back with: sudo nixos-rebuild --rollback switch"
