local wezterm = require 'wezterm'
local mux = wezterm.mux

local helpers = require 'modules.helpers'
local paths = require 'modules.paths'
local spawn = require 'modules.spawn'

wezterm.on('gui-startup', function(cmd)
  local startup = spawn.pwsh_spawn(paths.home)

  if cmd and cmd.args then
    startup.args = cmd.args
  end

  local system_tab, system_pane, window = mux.spawn_window(startup)
  system_tab:set_title 'system'

  system_pane:split {
    direction = 'Right',
    size = 0.28,
    cwd = paths.home,
    args = spawn.pwsh_spawn(paths.home, helpers.system_helper_cmd).args,
  }

  local coding_tab, coding_pane = window:spawn_tab(spawn.pwsh_spawn(paths.workstation))
  coding_pane = spawn.mux_tab_primary_pane(coding_tab, coding_pane)
  coding_tab:set_title 'coding'
  if coding_pane then
    coding_pane:split {
      direction = 'Right',
      size = 0.34,
      cwd = paths.workstation,
      args = spawn.pwsh_spawn(paths.workstation, helpers.coding_helper_cmd).args,
    }
  end

  local git_tab, git_pane = window:spawn_tab(spawn.git_bash_spawn(paths.dotfiles, helpers.git_top_helper_cmd))
  git_pane = spawn.mux_tab_primary_pane(git_tab, git_pane)
  git_tab:set_title 'git'
  if git_pane then
    git_pane:split {
      direction = 'Right',
      size = 0.37,
      cwd = paths.dotfiles,
      args = spawn.pwsh_spawn(paths.dotfiles, helpers.git_right_panel_cmd).args,
    }
    local git_live_pane = git_pane:split {
      direction = 'Bottom',
      size = 0.35,
      cwd = paths.dotfiles,
      args = spawn.git_bash_spawn(paths.dotfiles).args,
    }
    if git_live_pane then
      pcall(function()
        git_live_pane:send_text(helpers.git_live_view_cmd .. '\n')
      end)
    end
  end

  local wsl_tab, wsl_pane, wsl_fb = spawn.spawn_tab_or_fallback(
    window,
    spawn.wsl_spawn(paths.workstation),
    'wsl',
    'WSL is not available or the distro failed to start.'
  )
  if wsl_tab and wsl_pane and not wsl_fb then
    local ok_wsl_split, split_err = pcall(function()
      wsl_pane:split {
        direction = 'Right',
        size = 0.30,
        args = spawn.wsl_helper_spawn().args,
      }
    end)
    if not ok_wsl_split then
      wezterm.log_error('WSL helper pane split failed: ' .. tostring(split_err))
    end
  end

  local claude_tab, claude_pane, claude_fb = spawn.spawn_tab_or_fallback(
    window,
    spawn.wsl_command_spawn(paths.workstation, 'claude'),
    'claude',
    'Install WSL to use Claude CLI in this tab.'
  )
  if claude_tab and claude_pane and not claude_fb then
    local ok_claude_split, claude_split_err = pcall(function()
      claude_pane:split {
        direction = 'Right',
        size = 0.32,
        cwd = paths.workstation,
        args = spawn.pwsh_spawn(paths.workstation, helpers.claude_helper_cmd).args,
      }
    end)
    if not ok_claude_split then
      wezterm.log_error('Claude helper pane split failed: ' .. tostring(claude_split_err))
    end
  end

  local codex_tab, codex_pane, codex_fb = spawn.spawn_tab_or_fallback(
    window,
    spawn.wsl_command_spawn(paths.workstation, 'codex'),
    'codex',
    'Install WSL to use Codex CLI in this tab.'
  )
  if codex_tab and codex_pane and not codex_fb then
    local ok_codex_split, codex_split_err = pcall(function()
      codex_pane:split {
        direction = 'Right',
        size = 0.32,
        cwd = paths.workstation,
        args = spawn.pwsh_spawn(paths.workstation, helpers.codex_helper_cmd).args,
      }
    end)
    if not ok_codex_split then
      wezterm.log_error('Codex helper pane split failed: ' .. tostring(codex_split_err))
    end
  end

  local grok_tab, grok_pane, grok_fb = spawn.spawn_tab_or_fallback(
    window,
    spawn.wsl_command_spawn(paths.workstation, 'grok'),
    'grok',
    'Install WSL to use Grok CLI in this tab.'
  )
  if grok_tab and grok_pane and not grok_fb then
    local ok_grok_split, grok_split_err = pcall(function()
      grok_pane:split {
        direction = 'Right',
        size = 0.32,
        cwd = paths.workstation,
        args = spawn.pwsh_spawn(paths.workstation, helpers.grok_helper_cmd).args,
      }
    end)
    if not ok_grok_split then
      wezterm.log_error('Grok helper pane split failed: ' .. tostring(grok_split_err))
    end
  end

  system_tab:activate()
  window:gui_window():maximize()
end)

return {}
