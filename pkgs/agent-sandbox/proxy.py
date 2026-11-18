#!/usr/bin/env python3
"""Allowlisting CONNECT proxy for the agent sandbox.

The sandbox has no network interface except loopback. Its only route out is a
unix socket bridged to TCP inside the container, so this proxy is the single
place where egress is decided.

The rules are deliberately narrow:

- Only ``CONNECT`` is accepted. There is no plain-HTTP forwarding, so the proxy
  cannot be used as an origin server or to smuggle a request body.
- The host name must match the allowlist, either exactly or through a ``*.``
  suffix entry. A literal IP address is refused even when it is the address of
  an allowed name, so the proxy cannot be used as an address-forwarder.
- Only the ports in ``--ports`` are reachable, which keeps SSH and other
  nothing-to-do-with-the-API ports out of reach.
- The proxy resolves the name itself. The sandbox has no resolver, so DNS
  tunnelling has no channel.
"""

import argparse
import asyncio
import ipaddress
import os
import re
import signal
import sys

HOSTNAME = re.compile(r"^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$")
MAX_HEADER = 8192


def log(message: str) -> None:
    print(message, file=sys.stderr, flush=True)


class Allowlist:
    def __init__(self, path: str) -> None:
        self.exact: set[str] = set()
        self.suffixes: list[str] = []
        with open(path, encoding="utf-8") as handle:
            for raw in handle:
                entry = raw.split("#", 1)[0].strip().lower().rstrip(".")
                if not entry:
                    continue
                if entry.startswith("*."):
                    self.suffixes.append(entry[2:])
                else:
                    self.exact.add(entry)

    def allows(self, host: str) -> bool:
        if host in self.exact:
            return True
        for suffix in self.suffixes:
            if host == suffix or host.endswith("." + suffix):
                return True
        return False


def is_ip_literal(host: str) -> bool:
    try:
        ipaddress.ip_address(host)
    except ValueError:
        return False
    return True


async def relay(reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
    try:
        while True:
            chunk = await reader.read(65536)
            if not chunk:
                break
            writer.write(chunk)
            await writer.drain()
    except (ConnectionError, asyncio.IncompleteReadError):
        pass
    finally:
        try:
            writer.write_eof()
        except (OSError, RuntimeError):
            pass


async def refuse(writer: asyncio.StreamWriter, status: str) -> None:
    writer.write(f"HTTP/1.1 {status}\r\nConnection: close\r\n\r\n".encode())
    await writer.drain()


def make_handler(allow: Allowlist, ports: set[int]):
    async def handle(reader: asyncio.StreamReader, writer: asyncio.StreamWriter):
        peer = "unknown"
        try:
            request = await asyncio.wait_for(reader.readline(), timeout=10)
            parts = request.decode("latin-1").strip().split()
            if len(parts) != 3 or parts[0] != "CONNECT":
                await refuse(writer, "405 Method Not Allowed")
                return
            host, _, port_text = parts[1].partition(":")
            host = host.strip("[]").lower().rstrip(".")
            peer = f"{host}:{port_text}"
            if not port_text.isdigit():
                await refuse(writer, "400 Bad Request")
                return
            port = int(port_text)
            if (
                not HOSTNAME.match(host)
                or is_ip_literal(host)
                or not allow.allows(host)
                or port not in ports
            ):
                log(f"deny {peer}")
                await refuse(writer, "403 Forbidden")
                return
            while True:
                line = await asyncio.wait_for(reader.readline(), timeout=10)
                if line in (b"\r\n", b"\n", b""):
                    break
            upstream_reader, upstream_writer = await asyncio.wait_for(
                asyncio.open_connection(host, port), timeout=15
            )
            log(f"allow {peer}")
            writer.write(b"HTTP/1.1 200 Connection Established\r\n\r\n")
            await writer.drain()
            await asyncio.gather(
                relay(reader, upstream_writer),
                relay(upstream_reader, writer),
            )
            upstream_writer.close()
        except (TimeoutError, OSError) as error:
            log(f"error {peer}: {error}")
            try:
                await refuse(writer, "502 Bad Gateway")
            except OSError:
                pass
        finally:
            writer.close()
            try:
                await writer.wait_closed()
            except OSError:
                pass

    return handle


async def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--socket", required=True, help="unix socket to listen on")
    parser.add_argument("--allowlist", required=True, help="host allowlist file")
    parser.add_argument(
        "--ports",
        default="443",
        help="comma-separated ports a CONNECT may target (default: 443)",
    )
    args = parser.parse_args()

    ports = {int(item) for item in args.ports.split(",") if item}
    allow = Allowlist(args.allowlist)

    if os.path.exists(args.socket):
        os.unlink(args.socket)
    server = await asyncio.start_unix_server(make_handler(allow, ports), path=args.socket)
    os.chmod(args.socket, 0o666)

    loop = asyncio.get_running_loop()
    for sig in (signal.SIGTERM, signal.SIGINT):
        loop.add_signal_handler(sig, server.close)

    log(f"listening on {args.socket}")
    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    asyncio.run(main())
