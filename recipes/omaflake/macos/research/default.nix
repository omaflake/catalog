# Recipe: research (macOS) – writing and working in the terminal: everything of minimal, plus TeX Live (full, from Nix),
# VS Code set up for LaTeX and Typst, WezTerm with Zellij, Typst, pandoc, lazygit and Homebrew.
# User files (WezTerm, VS Code settings, neovim with vimtex) are written once and then belong to the user.
{ config, lib, pkgs, settings, nix-homebrew, ... }:

let
  user = settings.macUser;
  home = "/Users/${user}";
  # "de_DE.UTF-8" → "de-DE" for the spelling and grammar checker
  language = builtins.replaceStrings [ "_" ] [ "-" ] (builtins.head (lib.splitString "." settings.locale));

  vscode = pkgs.vscode-with-extensions.override {
    vscodeExtensions = with pkgs.vscode-extensions; [
      james-yu.latex-workshop      # LaTeX: build with latexmk, PDF preview, SyncTeX
      ltex-plus.vscode-ltex-plus   # spelling and grammar (LanguageTool) for LaTeX, Markdown, Typst
      myriad-dreamin.tinymist      # Typst
      eamodio.gitlens
      jnoortheen.nix-ide
    ];
  };

  vscodeSettings = pkgs.writeText "settings.json" (builtins.toJSON {
    "editor.fontFamily" = "'JetBrainsMono Nerd Font', Menlo, monospace";
    "editor.fontSize" = 14;
    "editor.wordWrap" = "on";
    "workbench.colorTheme" = "Default Dark Modern";
    "latex-workshop.latex.recipe.default" = "latexmk (latexmkrc)";
    "latex-workshop.view.pdf.viewer" = "tab";
    "latex-workshop.latex.autoBuild.run" = "onSave";
    "ltex.language" = language;
    "ltex.ltex-ls.path" = "${pkgs.ltex-ls-plus}";
    "ltex.enabled" = [ "latex" "markdown" "typst" "bibtex" ];
    "update.mode" = "none";             # Nix updates VS Code
    "extensions.autoUpdate" = false;
    "telemetry.telemetryLevel" = "off";
  });

  nvimInit = pkgs.writeText "init.lua" ''
    -- neovim in macos/research: vimtex (\ll compiles, \lv shows the PDF in Preview). Edit freely.
    -- The guest's look: colours from the image (/etc/omaflake/look/nvim.lua; nothing there in older images)
    pcall(dofile, '/etc/omaflake/look/nvim.lua')
    vim.g.vimtex_view_method = 'general'
    vim.g.vimtex_view_general_viewer = 'open'
    vim.opt.number = true
    vim.opt.wrap = true
  '';
in
{
  imports = [ ../minimal nix-homebrew.darwinModules.nix-homebrew ];

  networking.hostName = lib.mkForce "research";

  # VS Code is not free software; allowed here only for it
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "vscode" "vscode-with-extensions" ];

  environment.systemPackages = [ vscode ] ++ (with pkgs; [
    texliveFull                # TeX Live scheme-full: latexmk, biber, chktex, latexindent, all packages
    texlab                     # LaTeX language server (editors besides VS Code)
    typst tinymist
    wezterm zellij
    pandoc lazygit
  ]);
  # The Zellij session "main" from any shell (WezTerm's Cmd + Shift + Enter opens a window in it)
  environment.shellAliases.zj = "zellij attach --create main";

  fonts.packages = [ pkgs.nerd-fonts.jetbrains-mono ];

  # Homebrew for what Nix does not have; installed declaratively, taps stay changeable
  nix-homebrew = {
    enable = true;
    inherit user;
    enableRosetta = false;
    mutableTaps = true;
  };
  environment.systemPath = lib.mkAfter [ "/opt/homebrew/bin" ];

  system.defaults.dock.persistent-apps = lib.mkAfter [
    "/Applications/Nix Apps/WezTerm.app"
    "/Applications/Nix Apps/Visual Studio Code.app"
  ];

  # The user's starting configuration – only where there is none yet. Everything is created *as the user*: with
  # `install -d` as root, the folders on the way (~/Library/Application Support/Code, ~/.config, ~/.local) became
  # root's and VS Code could not write its data (plan B77).
  system.activationScripts.postActivation.text = lib.mkAfter ''
    asUser() { /usr/bin/sudo -u ${user} -H "$@"; }
    # Images built before the fix: give back what an earlier activation created as root
    for d in "${home}/Library/Application Support/Code" "${home}/.config" "${home}/.local"; do
      if [ -e "$d" ] && [ "$(/usr/bin/stat -f %Su "$d")" = root ]; then /usr/sbin/chown -R ${user}:staff "$d"; fi
    done
    put() { # source, target
      if [ ! -e "$2" ]; then
        asUser /bin/mkdir -p "$(dirname "$2")"
        asUser /bin/cp "$1" "$2"
        asUser /bin/chmod 644 "$2"
      fi
    }
    put ${./wezterm.lua} "${home}/.wezterm.lua"
    put ${vscodeSettings} "${home}/Library/Application Support/Code/User/settings.json"
    put ${nvimInit} "${home}/.config/nvim/init.lua"
    vimtex="${home}/.local/share/nvim/site/pack/omaflake/start/vimtex"
    if [ ! -e "$vimtex" ]; then
      asUser /bin/mkdir -p "$(dirname "$vimtex")"
      asUser /bin/ln -s ${pkgs.vimPlugins.vimtex} "$vimtex"
    fi
  '';
}
