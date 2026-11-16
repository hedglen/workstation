local wezterm = require 'wezterm'
local config = wezterm.config_builder()
require('modules.theme').apply(config)
require 'modules.tabs'
return config
