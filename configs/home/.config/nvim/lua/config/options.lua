-- ~/.config/nvim/lua/config/options.lua — read by LazyVim after its own options: ours win.
-- The clipboard: copies (y) to the desktop's, deletes kept in the editor, p the newest copy
-- wherever it was made (config/clipboard.lua: why)
require("config.clipboard").setup()
