#!/usr/bin/env python3
"""Unit checks for the sandbox proxy's allowlist, address filter and dialer.

These decide every egress from an agent session, so they are checked without a
network: load the proxy, exercise the matching and classification rules, then
dial a listener the test itself owns. That dial proves the dialer uses the
address it was handed rather than resolving a name again.

Run directly: python3 tests/agent-sandbox-proxy.py
"""

import asyncio
import importlib.util
import pathlib
import socket
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / "pkgs" / "agent-sandbox" / "proxy.py"

spec = importlib.util.spec_from_file_location("agent_sandbox_proxy", SOURCE)
proxy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(proxy)

ALLOWLIST = """
# Exact names and one wildcard entry.
github.com
*.github.com
*.githubusercontent.com
cache.nixos.org
"""


def load_allowlist():
    with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False) as handle:
        handle.write(ALLOWLIST)
        path = handle.name
    return proxy.Allowlist(path)


def check_allowlist():
    allow = load_allowlist()
    allowed = [
        "github.com",
        "api.github.com",
        "github.com",  # the bare name of a `*.` entry
        "objects.githubusercontent.com",
        "cache.nixos.org",
    ]
    refused = [
        "github.com.evil.example",
        "evilgithub.com",
        "notgithub.com",
        "api.anthropic.com",
        "cache.nixos.org.evil.example",
    ]
    for host in allowed:
        assert allow.allows(host), f"expected allowed: {host}"
    for host in refused:
        assert not allow.allows(host), f"expected refused: {host}"


def check_ip_literals():
    for host in ["1.1.1.1", "127.0.0.1", "::1", "2606:4700::1111"]:
        assert proxy.is_ip_literal(host), f"expected IP literal: {host}"
    for host in ["github.com", "api.anthropic.com"]:
        assert not proxy.is_ip_literal(host), f"expected a name: {host}"


def check_address_classification():
    unusable = [
        "127.0.0.1",
        "192.168.1.10",
        "10.0.0.5",
        "100.64.0.1",  # carrier-grade NAT
        "169.254.169.254",  # cloud metadata
        "198.18.0.1",  # benchmarking range
        "192.0.2.1",  # documentation range
        "0.0.0.0",
        "::1",
        "fd00::1",
        "fe80::1",
        "::",
        "::ffff:169.254.169.254",  # IPv4-mapped link-local
        "::ffff:192.168.1.1",
        "224.0.0.1",  # multicast, which `is_global` reports as global
        "ff02::1",
    ]
    usable = [
        "93.184.216.34",
        "1.1.1.1",
        "2606:4700::1111",
        "::ffff:8.8.8.8",
        "64:ff9b::1.2.3.4",  # NAT64
    ]
    for address in unusable:
        assert not proxy.is_usable(address), f"expected unusable: {address}"
    for address in usable:
        assert proxy.is_usable(address), f"expected usable: {address}"
    for text in ["github.com", "", "not-an-address"]:
        assert not proxy.is_usable(text), f"expected unusable text: {text}"


def check_address_filter():
    infos = [
        (socket.AF_INET, socket.SOCK_STREAM, 6, "", ("93.184.216.34", 443)),
        (socket.AF_INET, socket.SOCK_STREAM, 6, "", ("127.0.0.1", 443)),
        (socket.AF_INET, socket.SOCK_STREAM, 6, "", ("192.168.1.10", 443)),
        (socket.AF_INET, socket.SOCK_STREAM, 6, "", ("169.254.169.254", 443)),
        (socket.AF_INET, socket.SOCK_STREAM, 6, "", ("224.0.0.1", 443)),
        (socket.AF_INET6, socket.SOCK_STREAM, 6, "", ("::1", 443, 0, 0)),
        (socket.AF_INET6, socket.SOCK_STREAM, 6, "", ("fd00::1", 443, 0, 0)),
        (socket.AF_INET6, socket.SOCK_STREAM, 6, "", ("2606:4700::1111", 443, 0, 0)),
    ]
    kept = [sockaddr[0] for _family, sockaddr in proxy.global_addresses(infos, "github.com")]
    assert kept == ["93.184.216.34", "2606:4700::1111"], kept


async def check_dial():
    """Dial a listener the test owns, so the given address is the address used."""
    listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    listener.bind(("127.0.0.1", 0))
    listener.listen(1)
    listener.setblocking(False)
    sockaddr = listener.getsockname()

    async def serve():
        loop = asyncio.get_running_loop()
        conn, _peer = await loop.sock_accept(listener)
        try:
            await loop.sock_sendall(conn, b"pong")
        finally:
            conn.close()

    server = asyncio.ensure_future(serve())
    try:
        reader, writer = await proxy.dial(socket.AF_INET, sockaddr)
        assert await reader.readexactly(4) == b"pong"
        writer.close()
        await writer.wait_closed()
        await server
    finally:
        listener.close()


def main():
    check_allowlist()
    check_ip_literals()
    check_address_classification()
    check_address_filter()
    asyncio.run(check_dial())
    print("agent-sandbox proxy: allowlist, address filter and dialer pass")
    return 0


if __name__ == "__main__":
    sys.exit(main())
