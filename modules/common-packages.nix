{ config, pkgs, lib, ... }:
let
  cfg = config.commonPackages;
in {
  # Options for the common-packages module: an enable toggle and a list of
  # extra package values from `pkgs` to include in the system packages.
  options.commonPackages = {
    enable = lib.mkEnableOption "Enable a small set of desktop-agnostic common packages";
    packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      description = "Additional packages (package values from pkgs) to include in system-wide packages.";
    };
  };

  # When enabled, compose the systemPackages list from any user-provided
  # packages plus a small pre-curated set of useful CLI tools and helpers.
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; (cfg.packages or []) ++ [
      # System monitoring
      htop
      btop
      bottom       # Alternative system monitor
      fastfetch    # System information
      
      # Terminal multiplexer & utilities
      tmux
      
      # Disk tools
      ncdu         # NCurses disk usage analyzer
      
      # Archive & compression (basic formats)
      unzip zip
      gzip bzip2 xz
      p7zip
      
      # Network & system tools
      rsync
      openssh
      curl wget
      httpie       # Better curl for APIs
      
      # Debugging & inspection
      lsof
      strace
      file
      lnav         # Log navigator: SQL, timeline and filters over log files
      
      # Version control
      git gh
      git-lfs      # Large file support (moved from development.nix for consistency)
      
      # Modern CLI replacements
      ripgrep      # Better grep
      fd           # Better find
      sd           # Better sed
      eza          # Better ls
      bat          # Better cat
      delta        # Better diff
      
      # Data processing
      jq yq-go     # JSON/YAML processors
      jless        # TUI JSON viewer, for documents jq output buries
      
      # Task runner
      just
      watchexec    # Rerun a command when files change
      
      # Shell prompt
      starship
      
      # Development helpers
      direnv nix-direnv
      hyperfine    # Benchmarking
      
      # Security
      age
      gnupg
      gitleaks     # Scan a tree for committed secrets
      
      # Enhanced CLI Tools
      fzf          # Fuzzy finder (essential for productivity)
      zoxide       # Smarter cd command
      tree         # Directory tree viewer
      tealdeer     # tldr pages (quick command help)
      trash-cli    # Safe rm alternative (moves to trash)
      glow         # Markdown renderer for terminal
      
      # Nix maintenance: rebuild progress, generation diffs, store inspection
      nix-output-monitor
      nvd
      nix-tree
      nh           # Rebuild wrapper: prints the closure diff before it switches
      nix-search-tv # Fuzzy package search over its own cache
    ];

    # Helpful aliases for config management
    environment.shellAliases = {
      deploy-cfg = "deploy-config";  # Shorter alias
      nixos-edit = "cd ~/Documents/nix && $EDITOR .";  # Quick edit
    };
  };
}
