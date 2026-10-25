# Module: shell (macOS) – terminal tools from Nix
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [ git neovim ripgrep fd jq htop ];
}
