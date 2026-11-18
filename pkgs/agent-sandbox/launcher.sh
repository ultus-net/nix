#!/usr/bin/env bash
# Launcher for the agent sandbox, installed into the system profile by
# modules/agent-sandbox.nix. The @@NAME@@ tokens are substituted at build time,
# so nothing here is read from the project directory it mounts.
set -euo pipefail

readonly USAGE='Usage:
  agent-sandbox run <project-dir> [-- <command>...]
  agent-sandbox list
  agent-sandbox stop <name>|--all

run   Start a session with <project-dir> mounted at /workspace. Needs sudo from
      the account that owns the project. The session writes only that directory
      and its own tmpfs home; both are discarded when it ends.
list  Show running sessions.
stop  End one session, or every session with --all.'

die() {
  printf 'agent-sandbox: %s\n' "$*" >&2
  exit 1
}

need_root() {
  [ "$(id -u)" -eq 0 ] || die 'start a session through sudo, from your own account'
}

caller_uid() {
  local uid="${SUDO_UID:-}"
  case "$uid" in
    '' | *[!0-9]*) die 'SUDO_UID is unset or not numeric; start through sudo' ;;
  esac
  printf '%s' "$uid"
}

cmd_run() {
  need_root
  [ "$#" -ge 1 ] || die "$USAGE"

  local project
  project="$(realpath -e -- "$1")" || die "no such directory: $1"
  shift
  [ "${1:-}" = '--' ] && shift
  [ -d "$project" ] || die "not a directory: $project"
  [ "$project" != '/' ] || die 'refusing to mount the host root'
  case "$project" in
    /nix | /nix/*) die 'refusing to mount /nix' ;;
  esac

  local uid name
  uid="$(caller_uid)"
  name="agent-$RANDOM"
  printf 'agent-sandbox: %s on %s\n' "$name" "$project" >&2

  exec @@NSPAWN@@ --quiet \
    --machine="$name" \
    --directory=@@ROOTFS@@ \
    --private-users="$uid:1" \
    --private-network \
    --resolv-conf=off \
    --bind="$project:/workspace" \
    --bind-ro=/nix/store \
    --bind="@@SOCKET@@:/run/agent-proxy.sock" \
    --tmpfs=/tmp:mode=1777 \
    --tmpfs=/home/agent:size=@@HOMESIZE@@,mode=0700 \
    --setenv=HOME=/home/agent \
    --setenv=PATH=@@TOOLENV@@/bin:/bin \
    --setenv=SSL_CERT_FILE=@@CACERT@@ \
    --setenv=TERM="${TERM:-xterm-256color}" \
    --property=MemoryMax=@@MEMORYMAX@@ \
    --property=CPUQuota=@@CPUQUOTA@@ \
    --property=TasksMax=@@TASKSMAX@@ \
    -- /bin/sh @@ENTRY@@ "$@"
}

cmd_list() {
  need_root
  @@MACHINECTL@@ list --no-legend --no-pager | awk '$1 ~ /^agent-/'
}

cmd_stop() {
  need_root
  local target="${1:-}"
  [ -n "$target" ] || die "$USAGE"

  if [ "$target" = '--all' ]; then
    local sessions
    mapfile -t sessions < <(@@MACHINECTL@@ list --no-legend --no-pager |
      awk '$1 ~ /^agent-/ { print $1 }')
    [ "${#sessions[@]}" -gt 0 ] || {
      printf 'agent-sandbox: no sessions\n'
      return 0
    }
    local session
    for session in "${sessions[@]}"; do
      printf 'agent-sandbox: stopping %s\n' "$session"
      @@MACHINECTL@@ terminate "$session"
    done
    return 0
  fi

  case "$target" in
    agent-*) @@MACHINECTL@@ terminate "$target" ;;
    *) die "not an agent session: $target" ;;
  esac
}

case "${1:-}" in
  run)
    shift
    cmd_run "$@"
    ;;
  list) cmd_list ;;
  stop)
    shift
    cmd_stop "$@"
    ;;
  -h | --help | '') printf '%s\n' "$USAGE" ;;
  *) die "unknown command: $1" ;;
esac
