#!/usr/bin/env bash
# Fails when a real host carries a committed password hash. hosts/example keeps
# the documented shape of the option and is not exported.
#
# The needle is assembled from two pieces, so this file never matches itself.
set -euo pipefail

root="${1:-.}"
needle="$(printf '%s%s' \
  'initialHashed' \
  'Password')"

# Hidden directories are skipped: no tracked file lives in one, and a local Nix
# store under the worktree would otherwise be scanned.
mapfile -t files < <(find "$root" -name '*.nix' -not -path '*/.*' -print)
if [ "${#files[@]}" -eq 0 ]; then
  exit 0
fi

matches="$(grep -n "$needle" "${files[@]}" | grep -v '/hosts/example/' || true)"
if [ -n "$matches" ]; then
  printf '%s\n' "$matches" >&2
  printf 'check-no-password-hash: %s outside hosts/example\n' "$needle" >&2
  exit 1
fi
