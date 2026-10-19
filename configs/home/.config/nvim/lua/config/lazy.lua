-- ~/.config/nvim/lua/config/lazy.lua — LazyVim's starter file, with two changes: no update
-- checks in the background, and no luarocks (no plugin here needs a rock: lazy.nvim would
-- want luarocks and Lua 5.1 for nothing, and :checkhealth lazy said ERROR for their lack). Plugins move only when you run `update` (it backs up
-- lazy-lock.json first, then `Lazy! sync`) or `:Lazy sync` yourself; lazy-lock.json holds
-- every plugin at the exact commit you have, and `:Lazy restore` goes back to it.
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

require("lazy").setup({
  spec = {
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    { import = "plugins" },
  },
  defaults = {
    lazy = false,
    version = false, -- LazyVim's advice: the newest commit (lazy-lock.json pins what you have)
  },
  install = { colorscheme = { "gruvbox", "habamax" } },
  checker = { enabled = false }, -- no network, no update notices between your updates
  rocks = { enabled = false }, -- no luarocks: no plugin here needs one
  change_detection = { notify = false },
  performance = {
    rtp = {
      disabled_plugins = { "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin" },
    },
  },
})
