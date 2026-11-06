-- ~/.config/nvim/init.lua — where neovim starts: this file, then each file it names, in this order.
-- Space is the leader, the key that starts your own commands; it must be set before any key uses it.
vim.g.mapleader = " "
-- Backslash is the second leader, for the keys of one kind of file (nothing here uses it yet).
vim.g.maplocalleader = "\\"
-- How the editor behaves: lua/config/options.lua.
require("config.options")
-- Your keys: lua/config/keymaps.lua.
require("config.keymaps")
-- What happens by itself when something happens: lua/config/autocmds.lua.
require("config.autocmds")
-- The plugins: lua/config/lazy.lua, and it reads lua/plugins/.
require("config.lazy")
