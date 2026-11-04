-- ~/.config/nvim/lua/config/prefetch.lua — what the plugins would otherwise fetch from the network at
-- their first use, fetched now, and it waits: treesitter's parsers as lua/plugins/lean.lua lists them
-- (the others taken out), and blink.cmp's matching library (its first insert said "Downloading"). The
-- installer's and the update's step: nvim --headless '+Lazy! load nvim-treesitter' '+lua require("config.prefetch").sync()'
local M = {}

function M.sync()
  local ts = require("nvim-treesitter")
  local want = LazyVim.opts("nvim-treesitter").ensure_installed
  local drop = vim.tbl_filter(function(lang) return not vim.tbl_contains(want, lang) end, ts.get_installed("parsers"))
  if #drop > 0 then ts.uninstall(drop):wait(60000) end
  ts.install(want):wait(600000)

  require("lazy").load({ plugins = { "blink.cmp" } })
  local done = false
  require("blink.cmp.fuzzy.download").ensure_downloaded(function() done = true end)
  vim.wait(120000, function() return done end, 100)
end

return M
