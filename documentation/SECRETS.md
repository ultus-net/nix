# Secrets

This repository holds none. There is no committed key, token, password hash or
credential file, and `scripts/check-no-password-hash.sh` keeps the one that used
to exist from coming back.

That is the design, not an accident: the repository is public, and a public
repository is a permanent record. Anything secret lives outside it.

## What is deliberately not a secret here

| Thing | Why it needs nothing |
| --- | --- |
| Login password | the account ships locked, set with `passwd` on the console |
| SSH access | a public key in `hosts/<name>/default.nix`, which is not secret |
| Agent credentials | per-session device flow in `agent-sandbox`, no long-lived token |
| Nix cache | public binary caches, no credential |
| Registry pushes | the workflow's own `GITHUB_TOKEN` |

The agent case is the one worth stating. A session gets no stored credential;
the tool inside asks for a device-code login each time, so a container that is
thrown away holds nothing reusable. There is no token in the store, in the
project bind, or in the tmpfs home that survives the session.

## When one is actually needed

Two options, both fine. The question is which one the secret's consumer can
handle.

### sops-nix

Encrypts a file with `age` or GPG, decrypts on activation into `/run/secrets/`.
A `LoadCredential` or an `EnvironmentFile` then points at that path.

```nix
inputs.sops-nix.url = "github:Mic92/sops-nix";

sops = {
  defaultSopsFile = ./secrets/common.yaml;
  age.keyFile = "/var/lib/sops-nix/key.txt";
  secrets.api_key.owner = "hunter";
};
```

The encrypted file is safe to commit; the private key is not, and it lives on the
host under `/var/lib/`. `sops updatekeys` after adding a host.

### agenix

Same shape, `age` only, one file per secret, decrypted by a systemd unit.

```nix
age.secrets.api_key.file = ./secrets/api_key.age;
age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
```

agenix reuses the host's SSH host key as the identity, which removes a key
distribution step and means a rebuilt host cannot read a secret it was not
provisioned for.

## Which

| Criterion | sops-nix | agenix |
| --- | --- | --- |
| One file, many secrets | yes | one file per secret |
| Nested structure (YAML/JSON) | yes | no |
| Identity | separate age key | the host's SSH host key |
| Rotation | `sops updatekeys` | re-key each file |

`sops-nix` for anything structured or rotated often. `agenix` for a handful of
flat values where the host-key identity is the appealing part.

## Where it would go

A new input breaks the current shape: `flake.nix` carries two inputs, and a
third one is a decision, not a detail. Record it before adding it.

The module belongs under `modules/`, guarded by an option, and it must not read
anything under `hosts/`:

```nix
options.machines.secrets.enable = lib.mkEnableOption "sops decryption on this host";
```

The host sets the enable flag and anything host-specific, such as which key the
host holds. That keeps the layering gate satisfied and keeps the decryption
policy out of the shared defaults.

## The rule that does not bend

- Never commit a secret, a private key, or a decrypted copy.
- Never widen `safe.directory`, `NIX_CONFIG` or a `LoadCredential` path to *.
- Never put a credential in the Nix store, even temporarily: the store is
  world-readable and every path in it is written to `/nix/store` permanently.
