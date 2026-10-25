# Module: vscode (macOS) – VS Code with extensions from Nix (other modules add theirs with
# `omaflake.vscode.extensions` and `omaflake.vscode.settings`); its settings.json is written once and then belongs to
# the user. VS Code is not free software; allowed here only for it.
{ config, lib, pkgs, settings, ... }:

let
  cfg = config.omaflake.vscode;
  # "de_DE.UTF-8" → "de-DE" for the spelling and grammar checker
  language = builtins.replaceStrings [ "_" ] [ "-" ] (builtins.head (lib.splitString "." settings.locale));
  vscode = pkgs.vscode-with-extensions.override {
    vscodeExtensions = with pkgs.vscode-extensions; [
      ltex-plus.vscode-ltex-plus   # spelling and grammar (LanguageTool) for LaTeX, Markdown, Typst
      eamodio.gitlens
      jnoortheen.nix-ide
    ] ++ cfg.extensions;
  };
in
{
  options.omaflake.vscode = {
    extensions = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "VS Code extensions other modules add.";
    };
    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Settings other modules add to the first settings.json.";
    };
  };

  config = {
    nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "vscode" "vscode-with-extensions" ];
    environment.systemPackages = [ vscode ];
    system.defaults.dock.persistent-apps = lib.mkAfter [ "/Applications/Nix Apps/Visual Studio Code.app" ];
    omaflake.homeFiles."Library/Application Support/Code/User/settings.json" = pkgs.writeText "settings.json" (builtins.toJSON ({
      "editor.fontFamily" = "'JetBrainsMono Nerd Font', Menlo, monospace";
      "editor.fontSize" = 14;
      "editor.wordWrap" = "on";
      "workbench.colorTheme" = "Default Dark Modern";
      "ltex.language" = language;
      "ltex.ltex-ls.path" = "${pkgs.ltex-ls-plus}";
      "ltex.enabled" = [ "latex" "markdown" "typst" "bibtex" ];
      "update.mode" = "none";             # Nix updates VS Code
      "extensions.autoUpdate" = false;
      "telemetry.telemetryLevel" = "off";
    } // cfg.settings));
  };
}
