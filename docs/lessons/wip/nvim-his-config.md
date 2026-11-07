---
id: nvim-his-config
title: Your editor's config, line by line
part: 2
minutes: 20
needs: [nvim-never-stuck]
---
## idea
Your editor is a few small Lua files in ~/.config/nvim. Every line has a comment above it saying why it is there. Read it like a book.

init.lua is where neovim starts. It sets the leader, the key that begins your own commands, to Space. Then it names four files in order: options.lua, keymaps.lua, autocmds.lua, lazy.lua.

options.lua is how the editor behaves. A line like vim.o.scrolloff = 4 sets one option: four lines of air above and below the cursor. :help 'scrolloff' explains any option.

keymaps.lua is your keys. map("n", "<C-s>", ...) says: in normal mode, Ctrl+S does this. autocmds.lua is what happens by itself. lua/plugins holds the plugins lazy.nvim loads.

## exercise
Open ~/.config/nvim/init.lua in nvim and read all of it. Then open options.lua: type /scrolloff and Enter to jump to that line. Press n for the next match. Read the lines around it, then leave with :q. Change nothing.

## check
```check
ask: How many lines of air does scrolloff keep above and below the cursor?
answer: 4
proof: grep -q 'vim.o.scrolloff = 4' configs/home/.config/nvim/lua/config/options.lua
```
