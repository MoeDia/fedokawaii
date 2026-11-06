-- ~/.config/nvim/lua/config/run.lua — two small helpers for running your code (after/ftplugin/,
-- lua/plugins/repl.lua, lua/plugins/debug.lua).
local M = {}

-- The project's own Python, when `uv venv` or `uv sync` made one; else nothing.
function M.venv_python(root)
  local py = root and (root .. "/.venv/bin/python")
  return py and vim.uv.fs_stat(py) and py or nil
end

-- A key's action: a command's output in a terminal under the code, left open to read (q closes it).
function M.cmd(cmd)
  return function()
    Snacks.terminal.open(cmd, {
      cwd = require("config.root").get(),
      interactive = false,
      auto_close = false,
      win = { position = "bottom", height = 0.3 },
    })
  end
end

return M
