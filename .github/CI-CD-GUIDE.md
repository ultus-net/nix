# CI/CD Pipeline Guide

Three workflows run on this repository:

| Workflow | Trigger | What it proves |
| --- | --- | --- |
| `ci.yml` | pull request, push to `main` | the tree evaluates, builds and boots |
| `dev-image.yml` | changes to the dev image, `main` | the OCI image builds and runs |

## `ci.yml`

Three jobs, all required on `main`:

1. **Branch name** - the pull request head branch starts with `feature/`,
   `fix/`, `chore/`, `docs/`, `experiment/`, `hotfix/` or `refactor/`.
2. **Flake check** - `nix flake check -L`. That runs:
   - `checks.<system>.layering`: `scripts/check-layering.py` and its
     `--self-test`, so a role or module that imports `hosts/` fails the build.
   - `checks.<system>.no-initial-password`: greps for `initialHashedPassword`
     outside `hosts/example/`.
   - `checks.<system>.agent-sandbox-proxy`: the proxy's allowlist, address
     filter and dialer, from `tests/agent-sandbox-proxy.py`.
   - `checks.<system>.<host>`: one `nixosTest` per host.
3. **Build** - `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`
   for `base-server`, `tower` and `work-laptop`.

### Host tests

Each test boots the real host module in QEMU:

- The root filesystem and swap are replaced with QEMU's disk, and the
  bootloader is disabled, because a test machine has neither.
- The tower test forces `modesetting` instead of the NVIDIA driver, which QEMU
  cannot provide.
- The test waits for `multi-user.target` and `sshd.service`, asserts
  `firewall.service` is active, then checks one host-specific service:
  `docker.service` on tower, `tlp.service` enabled on work-laptop.

`nixosTest` needs KVM. The workflow sets
`system-features = nixos-test benchmark big-parallel kvm`.

### Running the same checks locally

```bash
nix flake check -L
nix build .#nixosConfigurations.tower.config.system.build.toplevel
```

`nix flake check` boots three VMs, so it is slow and needs `/dev/kvm`. For a
quick signal, evaluate instead:

```bash
nix eval .#nixosConfigurations.tower.config.system.build.toplevel.drvPath
```

## `dev-image.yml`

Builds `packages.dev-image` with `dockerTools`, loads it, asserts the image
reference from the `docker load` output, and smoke-tests the shell, the CA
bundle and one binary per toolchain. It pushes to
`ghcr.io/ultus-net/nix-dev` only on `main`.

## What CI does not cover

- Hardware that QEMU cannot model: the games disk, the NVIDIA GPU, the
  DisplayLink dock.
- Real `nixos-rebuild switch` on a host. That is the owner's first rebuild
  after merge.
