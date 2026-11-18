# Home Manager

User-level config: packages, dotfiles, application settings. One profile,
`home/hunter.nix`, wired two ways.

| Wiring | Entry point | Used by |
| --- | --- | --- |
| NixOS module | `modules/home-manager.nix`, imported by every role | the three hosts |
| Standalone | `homeConfigurations."hunter@x86_64-linux"` | a machine that is not NixOS |

The NixOS module sets `home-manager.users.hunter` and rebuilds with the system,
so a `nixos-rebuild switch` covers both. Standalone is for a macOS or foreign
Linux box:

```bash
home-manager switch --flake .#hunter@x86_64-linux
```

Both paths read the same `home/hunter.nix`, so the two cannot drift into
different shells.

## What the profile sets

- **Shell.** bash with starship, `direnv`, `fzf`, `zoxide`, and aliases onto
  `eza` and `bat`.
- **Git.** delta as the pager, `user.name` and `user.email`, the aliases worth
  having.
- **Editors.** Neovim with LSP and treesitter, VS Code with its extension set
  and settings.
- **Languages.** the LSPs for TypeScript, Python, Rust, Nix and Markdown.
- **XDG.** user directories declared, so a fresh home has `Documents`,
  `Downloads` and the rest without a manual `xdg-user-dirs-update`.
- **Wallpapers.** symlinks the system set into `~/.wallpapers`.

The desktop itself is not here. A role owns the session; Home Manager owns what
runs inside it.

## Generations

```bash
home-manager generations                       # what exists
home-manager build --flake .#hunter@x86_64-linux   # build without switching
```

The NixOS path has no separate generation: the system generation is the HM
generation, so `nixos-rebuild switch --rollback` reverts both. Standalone keeps
its own; `/nix/store/<generation>/activate` switches back to one.

To see the closure change before switching:

```bash
nixos-rebuild build --flake .#tower
nix store diff-closures /run/current-system ./result
```

## Two failure modes

**`Collision between ...`** means a file is declared twice, usually the same
package in `environment.systemPackages` and again in `home.packages`. Remove one.

**A change that does not appear** means the build ran without the switch, or the
session predates the switch. `home-manager switch` for standalone, a fresh login
for a shell change.

## Options

`home-manager option <term>` searches locally.
<https://nix-community.github.io/home-manager/options.xhtml> is the reference.

`programs.<shell>.initExtra` and `initContent` are the same slot under two names
across HM releases. This tree uses whichever the pinned `home-manager` input
accepts; an evaluation error naming one of them means the pin moved and the
attribute should follow it, not that both should be set.
