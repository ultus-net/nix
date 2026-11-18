{ config, lib, pkgs, ... }:
{
  options.pince = {
    enable = lib.mkEnableOption "PINCE, the GDB front-end for reverse engineering";
  };

  config = lib.mkIf config.pince.enable {
    # nixpkgs packages PINCE. This tree used to carry its own copy with a
    # hand-maintained patch set, which stopped building when upstream dropped
    # the pinned tag; the package in nixpkgs tracks upstream instead.
    environment.systemPackages = [ pkgs.pince ];
  };
}
