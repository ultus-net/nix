{
  description = "NixOS hosts composed from roles: KDE, Hyprland and XFCE";

  inputs = {
    # One nixpkgs. Unstable only; the lock file pins the exact revision.
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager }:
    let
      inherit (nixpkgs) lib;
      systems = [ "x86_64-linux" ];

      forAllSystems = import ./lib/forAllSystems.nix nixpkgs systems;

      mkHomeConfiguration = username: homeDirectory:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            system = "x86_64-linux";
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

      mkSystem = profile: lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inputs = self.inputs; };
        modules = [
          { nixpkgs.config.allowUnfree = true; }
          profile
        ];
      };
    in
    forAllSystems ({ system, pkgs }: {
      # Toolchains the agent sessions need, without a second dependency source.
      packages = {
        dev-image = import ./containers/dev { inherit pkgs; };

        # Not in nixpkgs. Pinned to an upstream commit in pkgs/luciole.
        luciole = pkgs.callPackage ./pkgs/luciole { };
      };

      devShells.default = pkgs.mkShell {
        name = "nix";
        packages = with pkgs; [
          # shells and core
          bashInteractive
          gnupg
          git
          gh
          direnv
          nix-direnv
          jq
          yq-go
          ripgrep
          fd
          sd
          eza
          delta
          starship

          # networking and ops
          curl
          wget
          httpie
        ] ++ lib.optionals (lib.hasSuffix "-linux" system) [ iproute2 ] ++ [
          # editors
          neovim

          # language toolchains
          python3
          nodejs_22
          pnpm
          bun
          go
          rustup

          # containers
          docker
          docker-compose

          # formatters and linters
          shfmt
          shellcheck
          black
          ruff
          prettier
          eslint_d
          stylua

          # build tools
          cmake
          pkg-config
          just
        ];
      };

      formatter = pkgs.nixfmt-rfc-style;

      checks = {
        # The layering gate and its self-test.
        layering = pkgs.runCommand "check-layering" {
          nativeBuildInputs = [ pkgs.python3 ];
        } ''
          cd ${self}
          python3 scripts/check-layering.py
          python3 scripts/check-layering.py --self-test
          touch $out
        '';

        # No committed password hashes on a real host. hosts/example documents
        # the shape and is not exported.
        no-initial-password = pkgs.runCommand "check-no-initial-password" { } ''
          cd ${self}
          ${pkgs.bash}/bin/bash scripts/check-no-password-hash.sh .
          touch $out
        '';

        # The sandbox proxy decides every egress from an agent session, so its
        # allowlist matching and its refusal of non-global addresses are
        # exercised without a network.
        agent-sandbox-proxy = pkgs.runCommand "check-agent-sandbox-proxy" {
          nativeBuildInputs = [ pkgs.python3 ];
        } ''
          cd ${self}
          python3 tests/agent-sandbox-proxy.py
          touch $out
        '';
      } // import ./tests/hosts.nix { inherit self pkgs; };
    }) // {
      nixosConfigurations = {
        # Headless base. Kept as a role-only output so it cannot rot.
        base-server = mkSystem ./roles/base.nix;

        tower = mkSystem ./hosts/tower/default.nix;
        work-laptop = mkSystem ./hosts/work-laptop/default.nix;

        # VM-only preview of the Dux Shell desktop. Not installed on hardware.
        dux-vm = mkSystem ./hosts/dux-vm/default.nix;

        # VM-only preview of the Noctalia desktop. Not installed on hardware.
        noctalia-vm = mkSystem ./hosts/noctalia-vm/default.nix;
      };

      templates = {
        homeManager = {
          path = ./templates/home;
          description = "Example Home Manager config for the home/ profiles";
        };
      };

      homeConfigurations = {
        "hunter@x86_64-linux" = mkHomeConfiguration "hunter" "/home/hunter";
      };
    };
}
