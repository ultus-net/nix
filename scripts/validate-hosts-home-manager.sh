#!/usr/bin/env bash
set -euo pipefail

# Every host entry point and every role must import the Home Manager module,
# directly or through another local import. Without it the deployed system has
# no user environment.

fail=0

check_import() {
  local f=$1 imp impPath
  if grep -Eq "home-manager\.nix" "$f"; then
    echo "OK: $f imports home-manager"
    return 0
  fi

  # Follow local imports one level: a host may reach home-manager through the
  # role it composes.
  while IFS= read -r imp; do
    impPath=$(realpath -m "$(dirname "$f")/$imp")
    if [ -f "$impPath" ] && grep -Eq "home-manager\.nix" "$impPath"; then
      echo "OK: $f imports $imp which imports home-manager"
      return 0
    fi
  done < <(grep -oE '(\./|\../)[^ \t\n]+\.nix' "$f" || true)

  echo "MISSING: $f does not import home-manager (directly or via local imports)" >&2
  return 1
}

for f in hosts/*/default.nix roles/*.nix; do
  check_import "$f" || fail=1
done

if [ "$fail" -ne 0 ]; then
  echo "One or more host files are missing Home Manager import." >&2
  exit 2
fi

echo "All host files import Home Manager."
