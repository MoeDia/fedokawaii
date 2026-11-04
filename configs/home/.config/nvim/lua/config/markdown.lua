-- ~/.config/nvim/lua/config/markdown.lua — typing in a Markdown file. Neovim's query hides whole ```
-- lines ("conceal_lines"): treesitter then asked again at every key, line by line, which rows to
-- hide (10 of the 18 ms a key took), and the rows jumped as the cursor reached such a line. A file's
-- highlighter gets the same query without that: the fence's words still vanish, its row stays, a
-- blank one. A hover's float is no file: it keeps neovim's own. (Should neovim change how a
-- highlighter is made: the plain start, the old way, no harm.)
local M = {}

local function query()
  local parts = {}
  for _, file in ipairs(vim.treesitter.query.get_files("markdown", "highlights")) do
    parts[#parts + 1] = table.concat(vim.fn.readfile(file), "\n")
  end
  return (table.concat(parts, "\n"):gsub('%(#set! conceal_lines ""%)', ""))
end

function M.setup()
  local start, text = vim.treesitter.start, nil
  vim.treesitter.start = function(buf, lang)
    local b = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf
    lang = lang or vim.treesitter.language.get_lang(vim.bo[b].filetype)
    if lang ~= "markdown" or vim.bo[b].buftype ~= "" or not vim.api.nvim_buf_is_loaded(b) then return start(buf, lang) end
    text = text or query()
    local ok = pcall(function()
      vim.treesitter.highlighter.new(assert(vim.treesitter.get_parser(b, lang)), { queries = { markdown = text } })
    end)
    if not ok then return start(buf, lang) end
  end
end

return M
