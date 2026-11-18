#!/usr/bin/env bash
set -euo pipefail

# Every host entry point and every role must import the Home Manager module,
# directly or through another local import. Without it the deployed system has
# no user environment.
#
# The check looks one hop only: host -> role, or role -> module. Every hop in
# this tree is one hop, so a deeper walk would add code without adding coverage.
# A decoy name does not pass, because the match requires a directory separator
# in front of the module file.

fail=0
HM_REF='(\./|\.\./|[^[:space:]]/)home-manager\.nix'

check_import() {
  local f=$1 imp impPath
  if grep -Eq "$HM_REF" "$f"; then
    echo "OK: $f imports home-manager"
    return 0
  fi

  # Follow local imports one level: a host may reach home-manager through the
  # role it composes.
  while IFS= read -r imp; do
    impPath=$(realpath -m "$(dirname "$f")/$imp")
    if [ -f "$impPath" ] && grep -Eq "$HM_REF" "$impPath"; then
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
