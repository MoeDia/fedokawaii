-- ~/.config/nvim/after/ftplugin/rust.lua — Rust's Space r keys, in Rust files alone: cargo, in a
-- terminal under the code.
local run = require("config.run")
local function map(key, args, desc) vim.keymap.set("n", key, run.cmd(args), { buffer = true, desc = desc }) end

map("<leader>rf", { "cargo", "run" }, "cargo run")
map("<leader>rc", { "cargo", "check" }, "cargo check")
map("<leader>rt", { "cargo", "test" }, "cargo test")
map("<leader>rl", { "cargo", "clippy" }, "cargo clippy")
