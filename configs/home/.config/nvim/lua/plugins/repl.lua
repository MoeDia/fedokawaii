-- ~/.config/nvim/lua/plugins/repl.lua — iron.nvim: a REPL under the code, Jupyter-like, for Python.
-- Its keys: after/ftplugin/python.lua. It loads with the first of them.
local run = require("config.run")

return {
  {
    "Vigemus/iron.nvim",
    lazy = true,
    cmd = { "IronRepl", "IronRestart", "IronFocus", "IronHide" },
    config = function()
      -- The project's IPython when its .venv has one, else its Python, else the system's.
      local function repl()
        local root = require("config.root").get()
        local ipython = root .. "/.venv/bin/ipython"
        if vim.uv.fs_stat(ipython) then return { ipython, "--no-autoindent" } end
        return { run.venv_python(root) or "python3", "-q" }
      end
      require("iron.core").setup({
        config = {
          repl_definition = {
            python = {
              command = repl,
              -- Pasted whole, so Python takes an indented block as one.
              format = require("iron.fts.common").bracketed_paste_python,
              -- A "# %%" line starts a cell.
              block_dividers = { "# %%", "#%%" },
            },
          },
          -- Twelve rows under the code.
          repl_open_cmd = "botright 12split",
        },
        highlight = { italic = false },
      })
    end,
  },
}
