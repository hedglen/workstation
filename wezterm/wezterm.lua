local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- Resolve modules alongside this config, including when using --config-file
-- to test a separate checkout. WezTerm exposes its loaded config directory.
local dir = wezterm.config_dir
package.path = dir .. '/?.lua;' .. dir .. '/?/init.lua;' .. package.path

require('modules.theme').apply(config)
require 'modules.tabs'
return config
