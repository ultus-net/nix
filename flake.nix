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

        # GRUB installs its EFI binaries to `boot.loader.efi.efiSysMountPoint`,
        # which defaults to /boot. work-laptop keeps /boot on btrfs, where the
        # firmware cannot read them, so the loader choice and the ESP mount are
        # asserted here. The host test cannot see either: it disables both
        # loaders and replaces the filesystems with a single ext4 root.
        work-laptop-boot =
          assert self.nixosConfigurations.work-laptop.config.boot.loader.grub.enable;
          assert !self.nixosConfigurations.work-laptop.config.boot.loader.systemd-boot.enable;
          assert self.nixosConfigurations.work-laptop.config.boot.loader.efi.efiSysMountPoint
            == (self.nixosConfigurations.work-laptop.config.fileSystems."/boot/efi".mountPoint or null);
          pkgs.runCommand "check-work-laptop-boot" { } ''
            touch $out
          '';

        # The four EliteDesk dev servers differ only in `networking.hostName`
        # and share the `elitedesk-800-g4` host test. A wrapper that loses its
        # override falls back to the shared name, which surfaces later as
        # duplicate SSH and Cockpit entries instead of a failed build.
        dev-hostnames =
          assert self.nixosConfigurations.dev-01.config.networking.hostName == "dev-01";
          assert self.nixosConfigurations.dev-02.config.networking.hostName == "dev-02";
          assert self.nixosConfigurations.dev-03.config.networking.hostName == "dev-03";
          assert self.nixosConfigurations.dev-04.config.networking.hostName == "dev-04";
          pkgs.runCommand "check-dev-hostnames" { } ''
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

        # HP EliteDesk 800 G4 Mini. Serves as a desktop test rig and a dev
        # server; `scripts/switch-desktop.sh` swaps its role import.
        elitedesk-800-g4 = mkSystem ./hosts/elitedesk-800-g4/default.nix;

        # The four EliteDesk dev servers share that host directory and differ
        # only in name, so each unit is its own output.
        dev-01 = mkSystem ./hosts/dev-01/default.nix;
        dev-02 = mkSystem ./hosts/dev-02/default.nix;
        dev-03 = mkSystem ./hosts/dev-03/default.nix;
        dev-04 = mkSystem ./hosts/dev-04/default.nix;

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
