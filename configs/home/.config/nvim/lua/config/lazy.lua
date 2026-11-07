-- ~/.config/nvim/lua/config/lazy.lua — lazy.nvim, the plugin manager. It reads lua/plugins/ and
-- loads each plugin when that plugin's file says. Plugins move only when the desktop's own
-- lazy-lock.json moves: the update puts them at its commits with `Lazy! restore` and leaves them.
-- The folder lazy.nvim itself lives in.
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
-- Not there yet (a first start): fetch it.
if not vim.uv.fs_stat(lazypath) then
  -- Its own repository, its newest stable state; the lock then puts it at the tested commit.
  vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", "https://github.com/folke/lazy.nvim.git", lazypath })
end
-- Neovim now looks for Lua modules in that folder too.
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  -- Every file in lua/plugins/ describes a plugin, or more than one.
  spec = { { import = "plugins" } },
  -- A plugin at the commit in the lock, not at a release: the lock alone decides.
  defaults = { version = false },
  -- A first start that has to install plugins already shows them in our colours.
  install = { colorscheme = { "kawa" } },
  -- No looking for new versions: no network, no notices between your updates.
  checker = { enabled = false },
  -- No luarocks: none of these plugins needs one, and :checkhealth would complain of its lack.
  rocks = { enabled = false },
  -- No timer watching these files every second: a change counts at the next start.
  change_detection = { enabled = false },
  performance = {
    rtp = {
      -- What neovim brings and nothing here uses: opening archives (gzip, tar, zip), netrw (snacks'
      -- tree opens folders), the old remote plugins, :TOhtml. (Never tutor: the first lesson.)
      disabled_plugins = { "gzip", "netrwPlugin", "rplugin", "tarPlugin", "tohtml", "zipPlugin" },
    },
  },
})
