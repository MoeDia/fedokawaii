-- apps.sh: what LazyVim's first interactive start would fetch, awaited (nvim --headless).
-- The tree-sitter parsers its nvim-treesitter spec asks for (ensure_installed), then quit.
local ok, ts = pcall(require, "nvim-treesitter")
if not ok then
  io.stdout:write("no nvim-treesitter: " .. tostring(ts) .. "\n")
  vim.cmd("cquit 1")
end
local plugin = require("lazy.core.config").spec.plugins["nvim-treesitter"]
local opts = require("lazy.core.plugin").values(plugin, "opts", false) or {}
local want = opts.ensure_installed or {}
io.stdout:write("parsers wanted: " .. table.concat(want, " ") .. "\n")
local task = ts.install(want, { summary = true })
local done = task:wait(900000)
io.stdout:write("install done: " .. tostring(done) .. "\n")
io.stdout:write("installed: " .. table.concat(ts.get_installed(), " ") .. "\n")
vim.cmd("qa")
