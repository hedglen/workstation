local wezterm = require 'wezterm'
local act = wezterm.action
local paths = require 'modules.paths'
local M = {}
function M.apply(config)
  config.default_prog = { 'pwsh.exe', '-NoLogo' }
  config.default_cwd = paths.home
  config.color_schemes = {
    ['Neon Dark (hedg)'] = {
      foreground = '#E4E4E4', background = '#0E0E0E',
      cursor_fg = '#0E0E0E', cursor_bg = '#FF66EE', cursor_border = '#FF66EE',
      selection_fg = '#E4E4E4', selection_bg = '#3D2560',
      ansi = { '#252525', '#FF6B8A', '#00E8B5', '#FFD447', '#64B5FF', '#E954FF', '#00E8FF', '#C8C8D0' },
      brights = { '#4A4A55', '#FF99AA', '#5CFFB8', '#FFE566', '#A8D4FF', '#F4A4FF', '#66F9FF', '#FFFFFF' },
    },
  }
  config.color_scheme = 'Neon Dark (hedg)'
  config.font = wezterm.font_with_fallback { 'JetBrainsMono Nerd Font', 'Consolas' }
  config.font_size = 12.5
  config.harfbuzz_features = { 'calt=0', 'clig=0', 'liga=0' }
  config.window_background_opacity = 1.0
  config.window_decorations = 'TITLE | RESIZE'
  config.window_close_confirmation = 'NeverPrompt'
  config.default_cursor_style = 'BlinkingBar'
  config.cursor_blink_rate = 500
  config.scrollback_lines = 100000
  config.initial_cols = 140
  config.initial_rows = 35
  config.window_padding = { left = 10, right = 10, top = 8, bottom = 8 }
  config.use_fancy_tab_bar = true
  config.hide_tab_bar_if_only_one_tab = false
  config.tab_max_width = 32
  config.launch_menu = {
    { label = 'PowerShell - home', args = { 'pwsh.exe', '-NoLogo' }, cwd = paths.home },
    { label = 'PowerShell - workstation', args = { 'pwsh.exe', '-NoLogo' }, cwd = paths.workstation },
  }
  config.keys = {
    { key = 'p', mods = 'CTRL|SHIFT', action = act.ShowLauncherArgs { flags = 'FUZZY|LAUNCH_MENU_ITEMS' } },
    { key = 'c', mods = 'CTRL|SHIFT', action = act.CopyTo 'Clipboard' },
    { key = 'v', mods = 'CTRL|SHIFT', action = act.PasteFrom 'Clipboard' },
    { key = 'f', mods = 'CTRL|SHIFT', action = act.Search { CaseInSensitiveString = '' } },
    { key = 't', mods = 'CTRL|SHIFT', action = act.SpawnTab 'CurrentPaneDomain' },
    { key = 'Tab', mods = 'CTRL', action = act.ActivateTabRelative(1) },
    { key = '\\', mods = 'ALT', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
    { key = '-', mods = 'ALT', action = act.SplitVertical { domain = 'CurrentPaneDomain' } },
    { key = 'h', mods = 'ALT', action = act.ActivatePaneDirection 'Left' },
    { key = 'l', mods = 'ALT', action = act.ActivatePaneDirection 'Right' },
    { key = 'k', mods = 'ALT', action = act.ActivatePaneDirection 'Up' },
    { key = 'j', mods = 'ALT', action = act.ActivatePaneDirection 'Down' },
    { key = 'z', mods = 'ALT', action = act.TogglePaneZoomState },
    { key = 'w', mods = 'CTRL|SHIFT', action = act.CloseCurrentTab { confirm = true } },
  }
end
return M
