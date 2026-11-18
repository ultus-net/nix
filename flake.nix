{
  description = "NixOS hosts composed from roles: KDE, Hyprland and XFCE";

  inputs = {
    # Pin nixpkgs to nixpkgs-unstable for the latest packages and fixes
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # Stable channel used for a few specific packages (e.g. google-chrome)
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.05";

    flake-utils.url = "github:numtide/flake-utils";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    devshell.url = "github:numtide/devshell";
  };

  outputs = { self, nixpkgs, nixpkgs-stable, flake-utils, home-manager, devshell }:
    let
      # Standalone home-manager configurations (not tied to NixOS)
      mkHomeConfiguration = system: username: homeDirectory: home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
        
        modules = [
          ./home/${username}.nix
          {
            home = {
              inherit username homeDirectory;
              stateVersion = "24.11";
            };
          }
        ];
      };
    in
    (flake-utils.lib.eachDefaultSystem (system:
      let
        # Stable package set for a few hand-picked packages
        stablePkgs = import nixpkgs-stable {
          inherit system;
          config.allowUnfree = true;
        };

        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true; # for fonts, VS Code, etc.
          };
          overlays = [ 
            devshell.overlays.default 
            # Prefer a stable google-chrome build from nixos-24.05
            (final: prev: {
              google-chrome = stablePkgs.google-chrome;
            })
          ];
        };
      in {
        # A developer shell with common tools similar to Universal Blue QoL
        devShells.default = pkgs.devshell.mkShell {
          name = "nix";
          packages = with pkgs; [
            # shells & core
            bashInteractive
            gnupg
            git
            gh
            direnv
            nix-direnv
            jq yq
            ripgrep fd
            sd
            eza
            delta
            starship

            # networking & ops
            curl wget
            httpie
            # iproute2 is Linux-specific; include only on linux systems
            # (avoid evaluating this package on unsupported host platforms)
          ] ++ pkgs.lib.optionals (builtins.match ".*-linux" system != null) [ iproute2 ] ++ [

            # editors
            neovim

            # language toolchains (lightweight)
            python3
            nodejs_22
            pnpm
            bun
            go
            rustup

            # containers
            docker
            docker-compose

            # formatters/linters
            shfmt shellcheck
            black ruff
            prettier
            eslint_d
            stylua

            # build tools
            cmake
            pkg-config
            just
          ];
          env = [
            {
              name = "DEVSHELL_ENABLE_DIRenv";
              value = "1";
            }
          ];
          commands = [
            {
              name = "setup-dev";
              help = "Initialize direnv + allow, and install rust toolchain";
              command = ''
                if [ -f .envrc ]; then echo "Found .envrc"; else echo "use nix" > .envrc; fi
                direnv allow . || true
                rustup default stable || true
              '';
            }
          ];
        };

        # Dev toolchains (Node, Python, Go) plus agent CLIs in one image. Built
        # from this flake's nixpkgs, so there is no second dependency source.
        # It is a toolchain image, not a security boundary.
        packages.dev-image = import ./containers/dev { inherit pkgs; };
      })
    ) // {
      # NixOS system configurations
      nixosConfigurations = let
          system = "x86_64-linux";
          mkSystem = profile: nixpkgs.lib.nixosSystem {
            inherit system;
            specialArgs = { inputs = self.inputs; };
            modules = [ profile ];
          };
        in {
          # Headless/Server base configuration (no desktop environment)
          base-server = mkSystem ./roles/base.nix;

          # Real machine configurations
          tower = mkSystem ./hosts/tower/default.nix;
          work-laptop = mkSystem ./hosts/work-laptop/default.nix;

          # KDE Plasma 6 - Feature-rich Qt desktop
          kde-workstation = mkSystem ./roles/kde.nix;

          # XFCE - Lightweight, traditional desktop
          xfce-workstation = mkSystem ./roles/xfce.nix;

          # Hyprland - Omarchy-style Wayland desktop
          hyprland-workstation = mkSystem ./roles/hyprland.nix;
        };

      # Out-of-system content like templates
      templates = {
        homeManager = {
          path = ./templates/home;
          description = "Example Home Manager config for the home/ profiles";
        };
      };

      # Standalone Home Manager configurations (for non-NixOS systems)
      homeConfigurations = {
        # Example: hunter@x86_64-linux
        "hunter@x86_64-linux" = mkHomeConfiguration "x86_64-linux" "hunter" "/home/hunter";

        # Add more users as needed:
        # "youruser@x86_64-linux" = mkHomeConfiguration "x86_64-linux" "youruser" "/home/youruser";
        # "youruser@aarch64-linux" = mkHomeConfiguration "aarch64-linux" "youruser" "/home/youruser";
        # "youruser@x86_64-darwin" = mkHomeConfiguration "x86_64-darwin" "youruser" "/Users/youruser";
      };
    };
  }
