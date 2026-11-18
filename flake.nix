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
        modules = [ profile ];
      };
    in
    forAllSystems ({ system, pkgs }: {
      # Toolchains the agent sessions need, without a second dependency source.
      packages = {
        dev-image = import ./containers/dev { inherit pkgs; };
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
          yq
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
    }) // {
      nixosConfigurations = {
        # Headless base. Kept as a role-only output so it cannot rot.
        base-server = mkSystem ./roles/base.nix;

        tower = mkSystem ./hosts/tower/default.nix;
        work-laptop = mkSystem ./hosts/work-laptop/default.nix;
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
