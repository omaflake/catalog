# SPDX-License-Identifier: MIT
# Module: zellij – the multiplexer, with Zellij's "Unlock First" keys so that the editor keeps its Ctrl keys. The
# keybinds are written from module.toml's actions (with the recipe's key binding sets over them): in each mode a bind
# per key – `does`, then a switch to `after` (before `does` for the modes that take typed input, as Zellij's presets
# do). A terminal is a plain shell; the session key (Super+Shift+Return by default) opens a terminal window in the
# Zellij session "main" (closing the window keeps it), `zj` attaches to it from any shell, also over SSH.
{ config, lib, settings, omaflake, ... }:

let
  keys = omaflake.keys;
  inherit (omaflake) bindings keyLib;
  toList = x: if builtins.isList x then x else [ x ];
  start = lib.head (builtins.attrNames (lib.filterAttrs (_: m: m.start or false) omaflake.modes));
  typed = [ "renametab" "renamepane" "entersearch" ];
  body = a: e:
    let
      does = lib.optional ((a.does or "") != "") (builtins.replaceStrings [ "{digit}" ] [ (e.digit or "") ] a.does);
      switch = lib.optional (a ? after) ''SwitchToMode "${a.after}"'';
    in
    lib.concatMapStrings (x: x + "; ") (if builtins.elem (a.after or "") typed then switch ++ does else does ++ switch);
  bindsIn = mode: lib.concatLists (lib.mapAttrsToList (_: a:
    lib.optionals (!(a.desktop or false) && builtins.elem mode (toList (a.mode or [ ])))
      (map (e: ''bind "${keyLib.zellij e.key}" { ${body a e}}'') (lib.concatMap keyLib.expand (toList a.key))))
    bindings);
  keybinds = ''
    default_mode "${start}"
    keybinds clear-defaults=true {
    ${lib.concatMapStrings (mode: "    ${mode} {\n" + lib.concatMapStrings (b: "        ${b}\n") (bindsIn mode) + "    }\n")
      (builtins.attrNames omaflake.modes)}}
  '';
  zellij = config.home-manager.users.${settings.user}.programs.zellij.package;
in
{
  # The session key on the desktop
  omaflake.launchers = lib.mkIf (omaflake.has "omaflake/hyprland") [
    { key = keys.session; command = "${config.omaflake.terminal.run} ${lib.getExe zellij} attach --create main"; }
  ];

  home-manager.users.${settings.user} = { osConfig, ... }: {
    programs.zellij = {
      enable = true;
      enableZshIntegration = false; # not in every shell: started on purpose – the session key or `zj`
      settings = {
        default_layout = "compact";
        pane_frames = false;
        simplified_ui = true;
        show_startup_tips = false;
        show_release_notes = false;
        # The look: Zellij's own theme or one from the look's folder (omaflake's platform)
        theme = osConfig.omaflake.lookParts.zellij.theme;
        theme_dir = "/etc/omaflake/look/zellij";
      };
      extraConfig = keybinds;
    };
    programs.zsh.shellAliases.zj = "zellij attach --create main";
  };
}
