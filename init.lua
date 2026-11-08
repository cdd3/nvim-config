-- Author: CDD3
--    Adapted from:Jiedong Hao (jdhao@hotmail.com)

vim.loader.enable()

local utils = require("utils")

local expected_version = "0.12.6"
utils.is_compatible_version(expected_version)

-- some global settings
require("globals")

-- setting options in nvim
require("options")

-- various autocommands
require("custom-autocmd")

-- all the user-defined mappings
require("mappings")

-- all the plugins installed and their configurations
require("plugin_specs")

-- diagnostic related config
require("diagnostic-conf")

-- colorscheme settings
local color_scheme = require("colorschemes")
return

-- Load a random colorscheme
color_scheme.rand_colorscheme()
