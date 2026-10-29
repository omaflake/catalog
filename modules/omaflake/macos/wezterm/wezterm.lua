-- SPDX-License-Identifier: MIT
-- WezTerm (omaflake's module macos/wezterm): the guest's look, JetBrains Mono Nerd Font; a window is a plain shell,
-- with Zellij the session key (Cmd + Shift + Enter by default) opens one in Zellij.
-- Written once into ~/.wezterm.lua – edit it freely, omaflake does not overwrite it.
local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- The paravirtual GPU of a macOS VM has Metal but no OpenGL ("failed to create NSOpenGLPixelFormat", plan B78):
-- WebGPU draws with Metal
config.front_end = 'WebGpu'

config.font = wezterm.font 'JetBrainsMono Nerd Font'
config.font_size = 14
config.window_background_opacity = 0.97
config.hide_tab_bar_if_only_one_tab = true
config.window_padding = { left = 10, right = 10, top = 8, bottom = 8 }
-- The session key: a new window in the Zellij session "main" (tabs, panes and detach live there; closing the
-- window keeps it). `zj` in a shell does the same.
local zellij = { '/run/current-system/sw/bin/zellij', 'attach', '--create', 'main' }

-- The guest's look (chosen when the image was built): its colours, and Zellij's theme for a new
-- session. The file comes with the image, so a rebuilt image brings another look while this file stays yours.
local ok, look = pcall(dofile, '/etc/omaflake/look/wezterm.lua')
if ok then
  for k, v in pairs(look.config) do config[k] = v end
  table.insert(zellij, 'options')
  for _, a in ipairs(look.zellij) do table.insert(zellij, a) end
else
  config.color_scheme = 'Builtin Dark'   -- an image without looks (an older omaflake)
end

config.keys = {
@keys@}

return config
