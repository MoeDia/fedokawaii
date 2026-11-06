-- ~/.config/nvim/lua/config/root.lua — the project's folder: the nearest .git above this file, else
-- the folder neovim was started in. Remembered per buffer: the status line asks at every key.
local M = {}

function M.get()
  -- (false: looked, and there is none)
  if vim.b.kawa_root == nil then vim.b.kawa_root = vim.fs.root(0, ".git") or false end
  return vim.b.kawa_root or vim.uv.cwd()
end

return M
