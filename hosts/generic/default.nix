# Any other machine: uses its own hardware scan from /etc/nixos.
# Reads outside the flake, so rebuilds need --impure:
#   sudo nixos-rebuild switch --flake .#generic --impure
# Add GPU drivers or other hardware tweaks for that machine here.

{ ... }:

{
  imports = [ /etc/nixos/hardware-configuration.nix ];
}
