#!/bin/sh
# Runs as the only process group inside the agent sandbox. The sandbox has no
# network interface except loopback, so this bridges the allowlisting proxy's
# unix socket to a local TCP port and tells the toolchain to use it.
set -eu

proxy_socket=/run/agent-proxy.sock
local_port=3128

if [ ! -S "$proxy_socket" ]; then
  printf 'agent-sandbox: %s is missing; the session has no egress\n' "$proxy_socket" >&2
  exit 1
fi

@@SOCAT@@ TCP-LISTEN:"$local_port",fork,reuseaddr,bind=127.0.0.1 \
  UNIX-CONNECT:"$proxy_socket" &

proxy="http://127.0.0.1:$local_port"
export http_proxy="$proxy" https_proxy="$proxy" all_proxy="$proxy"
export HTTP_PROXY="$proxy" HTTPS_PROXY="$proxy" ALL_PROXY="$proxy"
export no_proxy=localhost,127.0.0.1,::1 NO_PROXY=localhost,127.0.0.1,::1

cd /workspace || exit 1

if [ "$#" -gt 0 ]; then
  exec "$@"
fi
exec /bin/sh -i
