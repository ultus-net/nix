# One of four identical EliteDesk 800 G4 Mini dev servers. The hardware and the
# services live in the shared host, so only the name differs and a unit is
# installed with `nixos-install --flake .#dev-03`.
{ lib, ... }:

{
  imports = [ ../elitedesk-800-g4/default.nix ];

  # The shared host sets a name too, so this has to win.
  networking.hostName = lib.mkForce "dev-03";
}
