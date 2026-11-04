-- ~/.config/nvim/lua/config/lazy.lua — LazyVim's starter file, with these changes: no update checks
-- and no watching of these files (no network, no timer), and no luarocks (no plugin here needs a
-- rock: lazy.nvim would want luarocks and Lua 5.1 for nothing, and :checkhealth lazy said ERROR for
-- their lack). Plugins move only when the desktop's own lazy-lock.json moves (it is shipped with
-- this file, every plugin at the exact commit it was tested at): the update puts them there with
-- `Lazy! restore` and leaves them. lua/plugins/lean.lua says what was taken off and why.
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Python's language server: basedpyright (pyright, with a project's .venv found by itself — the
-- one `uv venv` / `uv sync` makes), ruff beside it for lint, imports and formatting
vim.g.lazyvim_python_lsp = "basedpyright"
vim.g.lazyvim_python_ruff = "ruff"
-- no remote-plugin providers: nothing here is written in Python, Ruby, Perl or Node for neovim's
-- old plugin host — and the Python one alone cost a python3 start at the first .py file opened
-- (:checkhealth says each is disabled, not missing)
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_node_provider = 0

require("lazy").setup({
  spec = {
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    -- Python and Rust (handbook §43): their servers, formatting on save, tests, the debugger,
    -- Cargo.toml's crates — each loads with its first file of that kind (lua/plugins/dev.lua)
    { import = "lazyvim.plugins.extras.lang.python" },
    { import = "lazyvim.plugins.extras.lang.rust" },
    { import = "lazyvim.plugins.extras.lang.toml" },
    { import = "lazyvim.plugins.extras.dap.core" },
    { import = "lazyvim.plugins.extras.test.core" },
    { import = "plugins" },
  },
  defaults = {
    lazy = false,
    version = false, -- LazyVim's advice: commits, not releases (lazy-lock.json pins them)
  },
  install = { colorscheme = { "gruvbox", "habamax" } },
  checker = { enabled = false }, -- no network, no update notices between your updates
  rocks = { enabled = false }, -- no luarocks: no plugin here needs one
  change_detection = { enabled = false }, -- no timer looking at these files every second
  performance = {
    rtp = {
      -- (never tutor: the Learn book's first exercise is `nvim +Tutor`; netrw: snacks' tree opens
      -- folders; rplugin: no remote-plugin providers, above)
      disabled_plugins = { "gzip", "netrwPlugin", "rplugin", "tarPlugin", "tohtml", "zipPlugin" },
    },
  },
})
