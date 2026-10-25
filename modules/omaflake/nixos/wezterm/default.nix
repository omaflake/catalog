# Module: wezterm – the terminal. WezTerm instead of kitty: kitty draws no text under virgl (GL context and glyphs,
# omaflake plan B23); WezTerm renders cleanly on the GPU. The look's settings come from /etc/omaflake/look/wezterm.lua
# (omaflake's platform), merged over these.
{ settings, ... }:

{
  omaflake.terminal = {
    open = "wezterm";
    run = "wezterm start --";
  };

  home-manager.users.${settings.user} = { lib, ... }: {
    programs.wezterm = {
      enable = true;
      settings = {
        font = lib.generators.mkLuaInline ''wezterm.font("JetBrainsMono Nerd Font")'';
        font_size = 12;
        window_padding = { left = 10; right = 10; top = 10; bottom = 10; };
        window_background_opacity = 0.95;
        hide_tab_bar_if_only_one_tab = true;
        window_close_confirmation = "NeverPrompt";
        enable_wayland = true;
      };
      # The look's settings over these (a table returned here is merged on top)
      extraConfig = ''
        return dofile("/etc/omaflake/look/wezterm.lua").config
      '';
    };
  };
}
