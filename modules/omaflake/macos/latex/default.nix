# Module: latex (macOS) – TeX Live (scheme-full: latexmk, biber, chktex, latexindent, all packages) and texlab. With
# Neovim: vimtex (\ll compiles, \lv shows the PDF in Preview); with VS Code: LaTeX Workshop (latexmk, PDF in a tab,
# SyncTeX, building on save). Other modules' options are set only when the recipe has them (lib.optionalAttrs on
# `omaflake.has`, which is decided from the recipe, not from the configuration).
{ lib, pkgs, omaflake, ... }:

{
  config = lib.mkMerge [
    {
      environment.systemPackages = with pkgs; [
        texliveFull
        texlab       # LaTeX language server (editors besides VS Code)
      ];
    }
    (lib.optionalAttrs (omaflake.has "omaflake/neovim") {
      omaflake.homeLinks.".local/share/nvim/site/pack/omaflake/start/vimtex" = pkgs.vimPlugins.vimtex;
      omaflake.neovim.init = ''
        -- latex: vimtex (\ll compiles, \lv shows the PDF in Preview)
        vim.g.vimtex_view_method = 'general'
        vim.g.vimtex_view_general_viewer = 'open'
      '';
    })
    (lib.optionalAttrs (omaflake.has "omaflake/vscode") {
      omaflake.vscode.extensions = [ pkgs.vscode-extensions.james-yu.latex-workshop ];
      omaflake.vscode.settings = {
        "latex-workshop.latex.recipe.default" = "latexmk (latexmkrc)";
        "latex-workshop.view.pdf.viewer" = "tab";
        "latex-workshop.latex.autoBuild.run" = "onSave";
      };
    })
  ];
}
