# SPDX-License-Identifier: MIT
# Module: pandoc
{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.pandoc ];
}
