# Agent sandbox

`machines.agentSandbox` runs an agent session in a transient container. The
point is to bound what a coding agent can reach on this machine, not to run
untrusted code safely: the container shares the host kernel.

## What it isolates

| Boundary | How |
| --- | --- |
| Filesystem | Root is a read-only store tree. Only the chosen project is mounted read-write, at `/workspace`. The agent home is a tmpfs, gone when the session ends. |
| Users | `--private-users=<uid>:1` maps exactly one uid. Inside, the container's root *is* the invoking user on the host, so files it writes in the project are owned by that user. Every other host uid is unmapped and appears as nobody. |
| Processes | Private PID, mount, IPC, UTS and network namespaces. `ps` inside shows only the session. |
| Network | `--private-network`: loopback only. There is no veth, no NAT, and therefore no route to the internet. |
| Egress | One unix socket, bind-mounted from the host, bridged to `127.0.0.1:3128` inside. The host side is an allowlisting `CONNECT` proxy. |
| Nix | `/nix/store` is mounted read-only and `/nix/var/nix/daemon-socket` is not mounted, so the session cannot build or fetch. The toolchain is the closure in `machines.agentSandbox.tools`. |
| Resources | `MemoryMax`, `CPUQuota` and `TasksMax` on the session scope, so a runaway loop cannot take the desktop down. |

The proxy accepts `CONNECT` only, only on the ports in
`machines.agentSandbox.allowedPorts` (443 by default), and only for names on
`machines.agentSandbox.allowedHosts`. A literal IP is refused even when it
belongs to an allowed name, and the proxy resolves names itself, so there is no
resolver inside to tunnel DNS through.

It resolves each name once, drops every address that is not globally routable
and unicast, and dials one of the addresses it kept. An allowed name cannot
point the session at a LAN host, at loopback, at a link-local address, or at a
multicast group. The dial takes the resolved address, so no second lookup can
change where the connection goes.

A `*.example.com` entry covers `example.com` itself as well as its subdomains.
Matching is on label boundaries, so `evil-example.com` and
`example.com.evil.example` do not match it.

## What it does not do

- It is a container, not a VM. A kernel bug or a container escape reaches the
  host as the invoking uid. Moving the same workload into a libvirt VM is the
  next step if that matters.
- It does not hide the project. The agent can read and write everything under
  the directory passed to `run`, including `.git`. Point it at a checkout, not
  at the home directory.
- It does not store a credential. Each session completes the agent's device
  flow itself, inside the tmpfs home, and the token dies with the tmpfs.
- It does not survive a restart. Nothing is persisted outside the project.

## Usage

```bash
agent-sandbox run ~/Projects/some-checkout          # interactive shell
agent-sandbox run ~/Projects/some-checkout -- claude
agent-sandbox list
agent-sandbox stop --all
```

`run` needs root and must be started from the account that owns the project:

```bash
sudo agent-sandbox run ~/Projects/some-checkout
```

The caller's uid comes from `SUDO_UID`. That uid is the one mapped inside, so
the agent's writes in the project are owned by that user. Refused values: a
missing `SUDO_UID`, a project path of `/`, and a path under `/nix`.

## Adding a host to the allowlist

Add the name to `machines.agentSandbox.allowedHosts` in the module and record
the reason in a comment beside it. The current list is the agent vendor APIs,
GitHub, `cache.nixos.org`, and the npm, PyPI and Go registries.

A name that needs a non-443 port needs `allowedPorts` too. Prefer a specific
host over a `*.` wildcard.

## Adding a tool

The store is read-only and the daemon socket is absent, so a tool that is not in
`machines.agentSandbox.tools` does not exist inside. Add the package to that
list and switch the host.

## First-run checks

These are the owner's checks on a real machine. They are written as a
falsifiable list because none of them can run in CI: booting a container needs
privileges the test harness does not have.

```bash
# Inside the session:
curl https://example.com                  # must fail (not on the allowlist)
curl https://github.com                   # must succeed
curl https://1.1.1.1                      # must fail (IP literal)
getent hosts example.com                  # must fail (no resolver)
ls /home/hunter                            # must fail (not mounted)
cat /nix/var/nix/daemon-socket/socket     # must fail (not mounted)
nix build nixpkgs#hello                   # must fail (no daemon, read-only store)
touch /tmp/leak && exit                   # then check /tmp/leak is gone on the host
ps -ef                                    # must show only the session
```

Then, from a second terminal, start a second session and confirm
`agent-sandbox list` shows two entries and `machinectl terminate` of one leaves
the other running.

If `curl https://github.com` fails, the likely cause is that nspawn did not
bring `lo` up or the proxy socket is missing. The entry script exits non-zero
with a message naming the missing socket.
