# SPDX-License-Identifier: MIT
# Module: pandoc (macOS)
{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.pandoc ];
}
