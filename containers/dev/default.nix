{ pkgs }:

let
  # Toolchains come from the flake's nixpkgs, so the image and the hosts share
  # one dependency source.
  tools = with pkgs; [
    # base CLI
    bashInteractive
    coreutils
    findutils
    diffutils
    gnused
    gnugrep
    less
    which
    cacert
    git
    gh
    gnupg
    jq
    yq-go
    ripgrep
    fd
    curl
    wget
    openssh
    tmux
    neovim

    # node / typescript
    nodejs_22
    pnpm
    bun
    typescript-language-server

    # python
    python3
    uv
    ruff

    # go
    go
    gopls

    # agent CLIs
    opencode
    claude-code
    codex
  ];

  # A layered image has no root pass, so the account database is written
  # directly instead of via useradd.
  accounts = [
    (pkgs.writeTextDir "etc/passwd" ''
      root:x:0:0:root user:/root:/bin/bash
      dev:x:1000:1000:dev:/home/dev:/bin/bash
      nobody:x:65534:65534:nobody:/var/empty:/bin/sh
    '')
    (pkgs.writeTextDir "etc/group" ''
      root:x:0:
      dev:x:1000:
      nobody:x:65534:
    '')
    (pkgs.writeTextDir "etc/shadow" ''
      root:!x:::::::
      dev:!:::::::
    '')
  ];
in
pkgs.dockerTools.buildLayeredImage {
  name = "ghcr.io/ultus-net/nix-dev";
  tag = "latest";

  # A layered image takes `contents`, not `copyToRoot`. buildEnv merges the
  # packages into the /bin, /etc and /share links the config below refers to.
  contents = pkgs.buildEnv {
    name = "nix-dev-root";
    paths = tools ++ accounts;
    pathsToLink = [ "/bin" "/etc" "/share" ];
  };

  # Writable home and workspace, owned by the image user. Nothing from the host
  # home is mounted.
  fakeRootCommands = ''
    mkdir -p home/dev workspace tmp
    chown 1000:1000 home/dev workspace
    chmod 1777 tmp
  '';

  config = {
    User = "1000:1000";
    WorkingDir = "/workspace";
    Cmd = [ "/bin/bash" ];
    Env = [
      "HOME=/home/dev"
      "PATH=/bin"
      "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
    ];
    Labels = {
      "org.opencontainers.image.title" = "nix dev image";
      "org.opencontainers.image.description" =
        "Dev toolchains (Node, Python, Go) and agent CLIs, built from the nix flake";
      "org.opencontainers.image.source" = "https://github.com/ultus-net/nix";
      "org.opencontainers.image.licenses" = "MIT";
    };
  };
}
