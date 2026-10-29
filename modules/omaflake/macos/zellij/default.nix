# SPDX-License-Identifier: MIT
# Module: zellij (macOS) – the multiplexer; `zj` attaches to the session "main" from any shell (WezTerm opens a window
# in it with the session key)
{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.zellij ];
  environment.shellAliases.zj = "zellij attach --create main";
}
