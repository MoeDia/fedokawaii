-- ~/.config/nvim/lua/config/prefetch.lua — treesitter's parsers, fetched by the installer and the
-- update, and it waits: nvim --headless '+Lazy! load nvim-treesitter' '+lua require("config.prefetch").sync()'
local M = {}

-- One parser for each kind of file written here; add a name and the next update builds it.
local PARSERS = {
  "bash", "c", "diff", "json", "lua", "luadoc", "luap", "markdown", "markdown_inline", "printf",
  "python", "query", "regex", "ron", "rust", "toml", "vim", "vimdoc", "yaml",
}

function M.sync()
  local ts = require("nvim-treesitter")
  -- Those no longer on the list go.
  local drop = vim.tbl_filter(function(lang) return not vim.tbl_contains(PARSERS, lang) end, ts.get_installed("parsers"))
  if #drop > 0 then ts.uninstall(drop):wait(60000) end
  -- Those missing are built; it waits up to ten minutes.
  ts.install(PARSERS):wait(600000)
end

return M
