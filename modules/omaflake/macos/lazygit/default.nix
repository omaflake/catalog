# SPDX-License-Identifier: MIT
# Module: lazygit (macOS)
{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.lazygit ];
}
