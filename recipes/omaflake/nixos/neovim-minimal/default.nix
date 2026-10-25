# Recipe: neovim-minimal – base and desktop with the neovim line (Neovim, Zellij), nothing else
{ ... }:

{
  networking.hostName = "neovim-minimal";
  omaflake.editor = "neovim";
}
