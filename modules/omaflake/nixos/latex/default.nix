# SPDX-License-Identifier: MIT
# Module: latex – TeX Live (full: latexmk, biber, chktex, latexindent, every package) and texlab. With Neovim: vimtex
# with latexmk compiling on every save (Space l l starts it and opens the PDF, Space l v jumps to the cursor's place
# in the PDF – vimtex's own keys); with zathura: SyncTeX, Ctrl+click in the PDF jumps back to the line.
{ lib, pkgs, settings, omaflake, ... }:

{
  environment.systemPackages = with pkgs; [
    texliveFull
    texlab       # LaTeX language server
  ];

  home-manager.users.${settings.user} = lib.mkMerge [
    (lib.mkIf (omaflake.has "omaflake/zathura") {
      programs.zathura.options.synctex = true;
    })
    (lib.mkIf (omaflake.has "omaflake/neovim") {
      programs.neovim = {
        plugins = [ pkgs.vimPlugins.vimtex ];
        initLua = lib.mkAfter ''
          -- latex: vimtex compiles on every save; the PDF in ${if omaflake.has "omaflake/zathura" then "zathura" else "the PDF viewer"}
          vim.g.vimtex_view_method = "${if omaflake.has "omaflake/zathura" then "zathura" else "general"}"
          vim.g.vimtex_compiler_latexmk = { continuous = 1 }
          vim.g.vimtex_quickfix_open_on_warning = 0
          vim.lsp.enable("texlab")
        '';
      };
    })
  ];
}
