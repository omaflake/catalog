# Module: zellij – the multiplexer, with Zellij's "Unlock First" keys (unlock-first.kdl) so that the editor keeps its
# Ctrl keys. A terminal is a plain shell; the session key (Super+Shift+Return by default) opens a terminal window in
# the Zellij session "main" (closing the window keeps it), `zj` attaches to it from any shell, also over SSH.
{ config, lib, settings, omaflake, ... }:

let
  keys = omaflake.keys;
  z = omaflake.keyLib.zellij;
  # The preset with the recipe's keys for unlocking, locking and quitting
  preset = builtins.replaceStrings
    [ ''bind "Ctrl g" { SwitchToMode "Normal"; }'' ''bind "Ctrl g" { SwitchToMode "Locked"; }'' ''bind "Ctrl q" { Quit; }'' ]
    [ ''bind "${z keys.unlock}" { SwitchToMode "Normal"; }'' ''bind "${z keys.lock}" { SwitchToMode "Locked"; }''
      ''bind "${z keys.quit}" { Quit; }'' ]
    (builtins.readFile ./unlock-first.kdl);
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
      extraConfig = preset;
    };
    programs.zsh.shellAliases.zj = "zellij attach --create main";
  };
}
