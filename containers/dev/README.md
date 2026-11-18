# Dev image

A container image with the toolchains this repo's projects use, built from the
flake's pinned nixpkgs. Published to
`ghcr.io/ultus-net/nixos-base-dev`.

It is a **toolchain image, not a security boundary**. It has full network
access, and it runs as an ordinary container. Confining an agent is the job of
the sandbox described in `documentation/design/2026-11-18-overhaul-design.md`.

## Contents

| Group | Packages |
| --- | --- |
| Base CLI | bash, coreutils, findutils, diffutils, sed, grep, less, git, gh, gnupg, jq, yq, ripgrep, fd, curl, wget, openssh, tmux, neovim |
| Node / TypeScript | nodejs_22, pnpm, bun, typescript-language-server |
| Python | python3, uv, ruff |
| Go | go, gopls |
| Agent CLIs | opencode, claude-code, codex |

Rust, C/C++, and a Nix daemon are deliberately absent. Add them to
`containers/dev/default.nix` if a project needs them, and rebuild.

## Build

```bash
nix build .#dev-image
docker load < result
```

The image is `ghcr.io/ultus-net/nixos-base-dev:latest`.

## Run

Mount the project only. Nothing from the host home is visible.

```bash
podman run --rm -it -v "$PWD:/workspace" ghcr.io/ultus-net/nixos-base-dev:latest
```

Use rootless podman: the container runs as uid 1000, which rootless podman maps
to your own user, so files written to `/workspace` stay yours. With rootful
docker they would be owned by uid 1000 on the host.

An agent CLI stores its credentials in `$HOME`, which is the container's own
home. Nothing persists between `--rm` runs, so log in again per session.

## Updates

CI rebuilds and pushes on every push to `main` that touches `containers/`,
`flake.nix`, or `flake.lock`. Pull requests build the image and run a smoke test
without pushing. The smoke test asserts the loaded reference, the shell, the CA
bundle, and one binary per toolchain, so a package rename fails CI instead of
publishing a broken image. The package also shows up in `nix flake show`, so
`nix build .#dev-image` always matches the pinned inputs.
