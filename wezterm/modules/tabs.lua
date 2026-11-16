local wezterm = require 'wezterm'
local mux = wezterm.mux
local paths = require 'modules.paths'

wezterm.on('gui-startup', function(cmd)
  local args = (cmd and cmd.args) or { 'pwsh.exe', '-NoLogo' }
  local tab, pane, window = mux.spawn_window { args = args, cwd = paths.home }
  tab:set_title('PowerShell')
  pcall(function() window:gui_window():maximize() end)

  -- A second tab is useful for Git without requiring WSL, Bash, or developer CLIs.
  local git_tab = window:spawn_tab {
    args = { 'pwsh.exe', '-NoLogo' },
    cwd = paths.workstation,
  }
  git_tab:set_title('Git')
  tab:activate()
end)
return {}
