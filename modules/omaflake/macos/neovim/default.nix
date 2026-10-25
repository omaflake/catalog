# Module: neovim (macOS) – Neovim as the default editor; ~/.config/nvim/init.lua is written once (the look, a few
# options, what other modules add with `omaflake.neovim.init`) and then belongs to the user.
{ config, lib, pkgs, ... }:

{
  options.omaflake.neovim.init = lib.mkOption {
    type = lib.types.lines;
    default = "";
    description = "Lua other modules add to the first init.lua (e.g. latex: vimtex).";
  };

  config = {
    environment.systemPackages = [ pkgs.neovim ];
    environment.variables.EDITOR = "nvim";
    omaflake.homeFiles.".config/nvim/init.lua" = pkgs.writeText "init.lua" (''
      -- Neovim (omaflake's module macos/neovim). Edit freely – written once, omaflake does not overwrite it.
      -- The guest's look: colours from the image (/etc/omaflake/look/nvim.lua)
      pcall(dofile, '/etc/omaflake/look/nvim.lua')
      vim.opt.number = true
      vim.opt.wrap = true
    '' + config.omaflake.neovim.init);
  };
}
