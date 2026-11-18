nixpkgs: systems: f:
let
  lib = nixpkgs.lib;

  perSystem = system:
    f {
      inherit system;
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    };

  # Flake outputs are nested by output name, then by system:
  # { devShells.default } becomes { devShells.x86_64-linux.default }.
  nest = system: attrs: lib.mapAttrs (name: value: { ${system} = value; }) attrs;
in
lib.foldl'
  (outputs: system: lib.recursiveUpdate outputs (nest system (perSystem system)))
  { }
  systems
