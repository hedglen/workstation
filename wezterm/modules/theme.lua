local wezterm = require 'wezterm'

local distro = require 'modules.distro'
local paths = require 'modules.paths'
local spawn = require 'modules.spawn'

local act = wezterm.action

local M = {}

function M.apply(config)
  config.default_prog = { 'pwsh.exe', '-NoLogo' }
  config.default_cwd = paths.home

  config.color_schemes = {
    ['Neon Dark (hedg)'] = {
      foreground = '#E4E4E4',
      background = '#0E0E0E',
      cursor_fg = '#0E0E0E',
      cursor_bg = '#FF66EE',
      cursor_border = '#FF66EE',
      selection_fg = '#E4E4E4',
      selection_bg = '#3D2560',
      ansi = {
        '#252525',
        '#FF6B8A',
        '#00E8B5',
        '#FFD447',
        '#64B5FF',
        '#E954FF',
        '#00E8FF',
        '#C8C8D0',
      },
      brights = {
        '#4A4A55',
        '#FF99AA',
        '#5CFFB8',
        '#FFE566',
        '#A8D4FF',
        '#F4A4FF',
        '#66F9FF',
        '#FFFFFF',
      },
    },
  }
  config.color_scheme = 'Neon Dark (hedg)'

  config.font = wezterm.font_with_fallback {
    'JetBrainsMono Nerd Font',
    'CaskaydiaCove Nerd Font',
    'Consolas',
  }
  config.font_size = 12.5
  config.harfbuzz_features = { 'calt=0', 'clig=0', 'liga=0' }

  config.window_background_opacity = 1.0
  config.text_background_opacity = 1.0
  config.window_decorations = 'TITLE | RESIZE'
  config.integrated_title_button_style = 'Windows'
  config.window_close_confirmation = 'NeverPrompt'

  config.default_cursor_style = 'BlinkingBar'
  config.cursor_blink_rate = 500

  config.scrollback_lines = 100000
  config.enable_scroll_bar = false

  config.inactive_pane_hsb = { saturation = 0.85, brightness = 0.85 }

  config.initial_cols = 140
  config.initial_rows = 35

  config.window_padding = {
    left = 10,
    right = 10,
    top = 8,
    bottom = 8,
  }

  config.use_fancy_tab_bar = true
  config.hide_tab_bar_if_only_one_tab = false
  config.tab_bar_at_bottom = false
  config.tab_max_width = 32

  config.launch_menu = {
    {
      label = 'pwsh - home',
      args = { 'pwsh.exe', '-NoLogo' },
      cwd = paths.home,
    },
    {
      label = 'pwsh - workstation',
      args = { 'pwsh.exe', '-NoLogo' },
      cwd = paths.workstation,
    },
    {
      label = 'pwsh - workstation',
      args = { 'pwsh.exe', '-NoLogo' },
      cwd = paths.workstation,
    },
    {
      label = 'pwsh - projects',
      args = { 'pwsh.exe', '-NoLogo' },
      cwd = paths.projects,
    },
    {
      label = 'pwsh - scripts',
      args = { 'pwsh.exe', '-NoLogo' },
      cwd = paths.workstation .. '\\scripts',
    },
    {
      label = 'wsl - ubuntu zsh',
      args = {
        'wsl.exe',
        '-d',
        distro.wsl_distro,
        'bash',
        '-lc',
        'cd '
          .. spawn.bash_quote(spawn.wsl_path(paths.workstation))
          .. ' && if command -v zsh >/dev/null 2>&1; then exec zsh -il; else exec bash -il; fi',
      },
    },
  }

  config.keys = {
    { key = 'p', mods = 'CTRL|SHIFT', action = act.ShowLauncherArgs { flags = 'FUZZY|LAUNCH_MENU_ITEMS' } },
    { key = 'c', mods = 'CTRL|SHIFT', action = act.CopyTo 'Clipboard' },
    { key = 'v', mods = 'CTRL|SHIFT', action = act.PasteFrom 'Clipboard' },
    { key = 'f', mods = 'CTRL|SHIFT', action = act.Search { CaseInSensitiveString = '' } },
    { key = 'k', mods = 'CTRL|SHIFT', action = act.ClearScrollback 'ScrollbackOnly' },
    { key = 't', mods = 'CTRL|SHIFT', action = act.SpawnTab 'CurrentPaneDomain' },
    { key = '1', mods = 'ALT', action = act.ActivateTab(0) },
    { key = '2', mods = 'ALT', action = act.ActivateTab(1) },
    { key = '3', mods = 'ALT', action = act.ActivateTab(2) },
    { key = '4', mods = 'ALT', action = act.ActivateTab(3) },
    { key = '5', mods = 'ALT', action = act.ActivateTab(4) },
    { key = '6', mods = 'ALT', action = act.ActivateTab(5) },
    { key = '7', mods = 'ALT', action = act.ActivateTab(6) },
    { key = 'Tab', mods = 'CTRL', action = act.ActivateTabRelative(1) },
    { key = '\\', mods = 'ALT', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
    { key = '-', mods = 'ALT', action = act.SplitVertical { domain = 'CurrentPaneDomain' } },
    { key = 'h', mods = 'ALT', action = act.ActivatePaneDirection 'Left' },
    { key = 'l', mods = 'ALT', action = act.ActivatePaneDirection 'Right' },
    { key = 'k', mods = 'ALT', action = act.ActivatePaneDirection 'Up' },
    { key = 'j', mods = 'ALT', action = act.ActivatePaneDirection 'Down' },
    { key = 'z', mods = 'ALT', action = act.TogglePaneZoomState },
    { key = 'LeftArrow', mods = 'ALT|SHIFT', action = act.AdjustPaneSize { 'Left', 5 } },
    { key = 'RightArrow', mods = 'ALT|SHIFT', action = act.AdjustPaneSize { 'Right', 5 } },
    { key = 'UpArrow', mods = 'ALT|SHIFT', action = act.AdjustPaneSize { 'Up', 2 } },
    { key = 'DownArrow', mods = 'ALT|SHIFT', action = act.AdjustPaneSize { 'Down', 2 } },
    { key = 'q', mods = 'CTRL|SHIFT', action = act.QuitApplication },
    { key = 'w', mods = 'CTRL|SHIFT', action = act.CloseCurrentTab { confirm = true } },
    { key = 'x', mods = 'CTRL|SHIFT', action = act.CloseCurrentPane { confirm = true } },
  }

  config.mouse_bindings = {
    {
      event = { Down = { streak = 1, button = 'Right' } },
      mods = 'NONE',
      action = wezterm.action_callback(function(window, pane)
        local sel = window:get_selection_text_for_pane(pane)
        if sel and sel ~= '' then
          window:perform_action(act.CopyTo 'Clipboard', pane)
          window:perform_action(act.ClearSelection, pane)
        else
          window:perform_action(act.PasteFrom 'Clipboard', pane)
        end
      end),
    },
  }
end

return M
