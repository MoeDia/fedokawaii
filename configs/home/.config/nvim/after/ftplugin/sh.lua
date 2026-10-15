-- ~/.config/nvim/after/ftplugin/sh.lua — added on top of the LazyVim starter.
-- Shell scripts keep their own layout: LazyVim formats on save with shfmt, which would
-- re-indent and re-align them (this desktop's own scripts among them). <leader>cf still
-- formats one when you ask, and <leader>uF turns formatting on save back on for that buffer.
vim.b.autoformat = false
