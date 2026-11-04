-- ~/.config/nvim/lua/config/parsers.lua — treesitter's parsers as lua/plugins/lean.lua lists them:
-- the missing compiled, the others taken out, and it waits. The installer's and the update's step
-- (setup.sh: nvim --headless '+Lazy! load nvim-treesitter' '+lua require("config.parsers").sync()')
local M = {}

function M.sync()
  local ts = require("nvim-treesitter")
  local want = LazyVim.opts("nvim-treesitter").ensure_installed
  local drop = vim.tbl_filter(function(lang) return not vim.tbl_contains(want, lang) end, ts.get_installed("parsers"))
  if #drop > 0 then ts.uninstall(drop):wait(60000) end
  ts.install(want):wait(600000)
end

return M
