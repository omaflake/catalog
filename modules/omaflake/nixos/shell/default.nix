# SPDX-License-Identifier: MIT
# Module: shell – zsh (the platform's login shell) with suggestions, highlighting and aliases, Starship, fzf and the
# terminal tools; the prompt, bat and fzf in the guest look's colours.
{ config, lib, pkgs, settings, ... }:

let
  d = config.omaflake.lookColors;
in
{
  home-manager.users.${settings.user} = lib.mkMerge [
    {
      home.packages = with pkgs; [ ripgrep fd bat eza fzf jq btop fastfetch ];

      programs.zsh = {
        enable = true;
        autosuggestion.enable = true;
        syntaxHighlighting.enable = true;
        shellAliases = {
          ls = "eza --icons";
          ll = "eza -la --icons";
          cat = "bat";
        };
      };
      programs.starship.enable = true;
      programs.fzf.enable = true;
    }

    (lib.mkIf (d != null && d.prompt != null) {
      programs.starship.settings = {
        character = {
          success_symbol = "[❯](bold #${d.prompt.ok})";
          error_symbol = "[❯](bold #${d.prompt.error})";
        };
        directory.style = "bold #${d.prompt.directory}";
      };
      # bat and fzf in the terminal's colours, which the look sets
      home.sessionVariables.BAT_THEME = "ansi";
      programs.fzf.colors = { "bg+" = "-1"; bg = "-1"; };
    })
  ];
}
