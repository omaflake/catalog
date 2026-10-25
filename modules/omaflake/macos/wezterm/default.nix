# Module: wezterm (macOS) – WezTerm with JetBrains Mono, in the Dock; ~/.wezterm.lua is written once and then belongs
# to the user. With Zellij its session key opens a window in Zellij's session "main".
{ lib, pkgs, omaflake, ... }:

let
  session = omaflake.allKeys."omaflake/zellij".session or null;
  key = k: let w = omaflake.keyLib.wezterm k; in
    "  { key = '${w.key}', mods = '${builtins.replaceStrings [ "SUPER" ] [ "CMD" ] w.mods}', action = wezterm.action.SpawnCommandInNewWindow { args = zellij } },\n";
  config = pkgs.writeText "wezterm.lua" (builtins.replaceStrings [ "@keys@" ]
    [ (lib.optionalString (omaflake.has "omaflake/zellij" && session != null) (key session)) ]
    (builtins.readFile ./wezterm.lua));
in
{
  environment.systemPackages = [ pkgs.wezterm ];
  fonts.packages = [ pkgs.nerd-fonts.jetbrains-mono ];
  # Before the other modules' apps (lib.mkAfter)
  system.defaults.dock.persistent-apps = lib.mkOrder 1400 [ "/Applications/Nix Apps/WezTerm.app" ];
  omaflake.homeFiles.".wezterm.lua" = config;
}
