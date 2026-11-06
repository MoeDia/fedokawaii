-- ~/.config/nvim/lua/config/lsp.lua — the language servers: programs that read your code and answer
-- neovim (errors, completion, go to the definition, rename, format). Neovim speaks to them itself;
-- each needs only its command, the files it is for, and what marks a project's folder. Mason
-- installed them (setup.sh MASON_TOOLS), rust-analyzer comes with rustup.
local run = require("config.run")

-- Python's types and names. The project's .venv (uv's) when it has one, else the Python on PATH.
vim.lsp.config("basedpyright", {
  cmd = { "basedpyright-langserver", "--stdio" },
  filetypes = { "python" },
  root_markers = { "pyproject.toml", "uv.lock", ".git" },
  settings = { basedpyright = { analysis = { typeCheckingMode = "standard" } } },
  before_init = function(_, config)
    local py = run.venv_python(config.root_dir)
    if py then config.settings.python = { pythonPath = py } end
  end,
})

-- Python's lint, imports and formatting, beside basedpyright.
vim.lsp.config("ruff", {
  cmd = { "ruff", "server" },
  filetypes = { "python" },
  root_markers = { "pyproject.toml", "ruff.toml", ".ruff.toml", ".git" },
  -- The same way of counting columns as basedpyright: one buffer, two servers, the columns agree.
  capabilities = { general = { positionEncodings = { "utf-16" } } },
  -- K asks basedpyright alone: ruff has nothing to say about what a name is.
  on_attach = function(client) client.server_capabilities.hoverProvider = false end,
})

-- Rust; it checks with clippy on every save, and its lints come as problems.
vim.lsp.config("rust_analyzer", {
  cmd = { "rust-analyzer" },
  filetypes = { "rust" },
  root_markers = { "Cargo.lock", ".git", "Cargo.toml" },
  settings = { ["rust-analyzer"] = { check = { command = "clippy" } } },
})

-- Lua, for this very config: it knows neovim's own vim.* functions.
vim.lsp.config("lua_ls", {
  cmd = { "lua-language-server" },
  filetypes = { "lua" },
  root_markers = { ".luarc.json", ".git" },
  settings = {
    Lua = {
      runtime = { version = "LuaJIT" },
      workspace = { library = { vim.env.VIMRUNTIME }, checkThirdParty = false },
    },
  },
})

-- TOML (Cargo.toml, pyproject.toml).
vim.lsp.config("taplo", {
  cmd = { "taplo", "lsp", "stdio" },
  filetypes = { "toml" },
  root_markers = { ".git" },
})

-- The problems: a square before the message at the line's end, the sign in the margin, the worst
-- first, and a float framed by single lines.
vim.diagnostic.config({
  virtual_text = { prefix = "■", spacing = 2, source = "if_many" },
  float = { border = "single", source = "if_many" },
  severity_sort = true,
})

-- The kinds of file formatted on every save: Python (ruff), Rust (rustfmt), TOML (taplo). Shell and
-- Lua keep the layout you gave them; Space c f still formats them when you ask.
local FORMAT_ON_SAVE = { python = true, rust = true, toml = true }

local group = vim.api.nvim_create_augroup("kawa_lsp", { clear = true })

-- Taking a server's completion also does what it asks for (an import added, a snippet expanded).
vim.api.nvim_create_autocmd("LspAttach", {
  group = group,
  callback = function(ev)
    local client = assert(vim.lsp.get_client_by_id(ev.data.client_id))
    if client:supports_method("textDocument/completion") then vim.lsp.completion.enable(true, client.id, ev.buf) end
  end,
})

-- One format before each save, by the server that can do it. Asked at the save, not as the server
-- attaches: ruff only says it can format a moment after that.
vim.api.nvim_create_autocmd("BufWritePre", {
  group = group,
  callback = function(ev)
    if not FORMAT_ON_SAVE[vim.bo[ev.buf].filetype] then return end
    if #vim.lsp.get_clients({ bufnr = ev.buf, method = "textDocument/formatting" }) == 0 then return end
    vim.lsp.buf.format({ bufnr = ev.buf, timeout_ms = 3000 })
  end,
})

-- All of them on: each starts with its first file, in its project's folder.
vim.lsp.enable({ "basedpyright", "ruff", "rust_analyzer", "lua_ls", "taplo" })
