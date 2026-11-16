local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- When --config-file points outside ~/.config/wezterm, WezTerm does not
-- automatically search that file's sibling modules/ directory.
local source = debug.getinfo(1, 'S').source
local file = source:sub(1, 1) == '@' and source:sub(2) or source
local dir = file:match('^(.*)[/\\]') or '.'
package.path = dir .. '/?.lua;' .. dir .. '/?/init.lua;' .. package.path

require('modules.theme').apply(config)
require 'modules.tabs'
return config
