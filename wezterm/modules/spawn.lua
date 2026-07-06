local wezterm = require 'wezterm'

local paths = require 'modules.paths'
local distro = require 'modules.distro'

local M = {}

function M.pwsh_spawn(cwd, cmd)
  local spawn = { cwd = cwd }

  if cmd then
    spawn.args = { 'pwsh.exe', '-NoLogo', '-NoExit', '-Command', cmd }
  end

  return spawn
end

function M.bash_quote(value)
  return "'" .. value:gsub("'", "'\\''") .. "'"
end

function M.bash_path(path)
  local drive, rest = path:match '^([A-Za-z]):\\(.*)$'

  if drive then
    return '/' .. drive:lower() .. '/' .. rest:gsub('\\', '/')
  end

  return path:gsub('\\', '/')
end

function M.wsl_path(path)
  local drive, rest = path:match '^([A-Za-z]):\\(.*)$'

  if drive then
    return '/mnt/' .. drive:lower() .. '/' .. rest:gsub('\\', '/')
  end

  return path:gsub('\\', '/')
end

function M.git_bash_spawn(cwd, cmd)
  local bash_cmd = 'cd ' .. M.bash_quote(M.bash_path(cwd))

  if cmd then
    bash_cmd = bash_cmd .. ' && ' .. cmd
  end

  return {
    cwd = cwd,
    args = { distro.git_bash, '--login', '-i', '-c', bash_cmd .. '\nexec bash -il' },
  }
end

function M.wsl_spawn(cwd)
  local shell_cmd = ''

  if cwd then
    shell_cmd = 'cd ' .. M.bash_quote(M.wsl_path(cwd)) .. ' && '
  end

  return {
    args = {
      'wsl.exe',
      '-d',
      distro.wsl_distro,
      'bash',
      '-lc',
      shell_cmd .. 'if command -v zsh >/dev/null 2>&1; then exec zsh -il; else exec bash -il; fi',
    },
  }
end

function M.wsl_command_spawn(cwd, cmd)
  local run_cmd = cmd
  if cwd then
    run_cmd = 'cd ' .. M.bash_quote(M.wsl_path(cwd)) .. ' && ' .. cmd
  end

  return {
    args = {
      'wsl.exe',
      '-d',
      distro.wsl_distro,
      'bash',
      '-lc',
      'if command -v zsh >/dev/null 2>&1; then exec zsh -ilc '
        .. M.bash_quote(run_cmd)
        .. '; else exec bash -ilc '
        .. M.bash_quote(run_cmd)
        .. '; fi',
    },
  }
end

function M.wsl_helper_spawn()
  local helper_win = paths.workstation .. '\\wezterm\\wsl-helper.sh'
  local fh = io.open(helper_win, 'r')
  if fh then
    fh:close()
    local helper_script = M.wsl_path(helper_win)
    return {
      args = { 'wsl.exe', '-d', distro.wsl_distro, 'bash', helper_script },
    }
  end
  wezterm.log_error('wsl-helper.sh missing at ' .. helper_win)
  return {
    args = {
      'wsl.exe',
      '-d',
      distro.wsl_distro,
      'bash',
      '-lc',
      'echo "wsl-helper.sh missing in wezterm/"; exec zsh -il',
    },
  }
end

function M.mux_tab_primary_pane(tab, pane)
  if pane then
    return pane
  end
  if not tab then
    return nil
  end
  local ok, panes = pcall(function()
    return tab:panes()
  end)
  if ok and type(panes) == 'table' and #panes >= 1 then
    return panes[1]
  end
  return nil
end

function M.spawn_tab_or_fallback(window, spawn_tbl, title, fallback_note)
  local ok, tab, pane = pcall(function()
    return window:spawn_tab(spawn_tbl)
  end)
  if ok and tab then
    pane = M.mux_tab_primary_pane(tab, pane)
    tab:set_title(title)
    return tab, pane, false
  end
  wezterm.log_error('WezTerm spawn_tab failed (' .. title .. '): ' .. tostring(tab))
  local ok2, tab2, pane2 = pcall(function()
    return window:spawn_tab(M.pwsh_spawn(paths.workstation))
  end)
  if ok2 and tab2 then
    pane2 = M.mux_tab_primary_pane(tab2, pane2)
    tab2:set_title(title .. ' (no WSL)')
    if pane2 and fallback_note then
      pcall(function()
        pane2:send_text(
          "Write-Host "
            .. "'"
            .. fallback_note
            .. "' -ForegroundColor Yellow; Write-Host 'Install WSL: wsl --install -d Ubuntu' -ForegroundColor DarkGray\r\n"
        )
      end)
    end
    return tab2, pane2, true
  end
  wezterm.log_error('WezTerm fallback spawn failed (' .. title .. ')')
  return nil, nil, false
end

return M
