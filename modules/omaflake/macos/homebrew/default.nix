# SPDX-License-Identifier: MIT
# Module: homebrew (macOS) – Homebrew for what Nix does not have; installed declaratively, taps stay changeable
{ lib, settings, nix-homebrew, ... }:

{
  imports = [ nix-homebrew.darwinModules.nix-homebrew ];

  nix-homebrew = {
    enable = true;
    user = settings.macUser;
    enableRosetta = false;
    mutableTaps = true;
  };
  environment.systemPath = lib.mkAfter [ "/opt/homebrew/bin" ];
}
