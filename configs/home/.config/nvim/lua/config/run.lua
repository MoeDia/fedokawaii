-- ~/.config/nvim/lua/config/run.lua — two small helpers for running your code (after/ftplugin/,
-- lua/plugins/repl.lua, lua/plugins/debug.lua).
local M = {}

-- The project's own Python, when `uv venv` or `uv sync` made one; else nothing.
function M.venv_python(root)
  local py = root and (root .. "/.venv/bin/python")
  return py and vim.uv.fs_stat(py) and py or nil
end

-- Code under ~/dojo runs inside the dojo box (`dojo run`: it sees only ~/dojo, 120 s at most);
-- anything else runs as it is.
local function boxed(cmd, cwd)
  local dojo = vim.fn.expand("~/dojo")
  if cwd == dojo or vim.startswith(cwd, dojo .. "/") then
    return vim.list_extend({ "dojo", "run", "--" }, cmd)
  end
  return cmd
end

-- A key's action: a command's output in a terminal under the code, left open to read (q closes it).
function M.cmd(cmd)
  return function()
    local cwd = require("config.root").get()
    Snacks.terminal.open(boxed(cmd, cwd), {
      cwd = cwd,
      interactive = false,
      auto_close = false,
      win = { position = "bottom", height = 0.3 },
    })
  end
end

return M
