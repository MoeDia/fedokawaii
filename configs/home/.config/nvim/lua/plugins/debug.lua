-- ~/.config/nvim/lua/plugins/debug.lua — the debugger: nvim-dap speaks to debugpy (Python) and
-- codelldb (Rust), nvim-dap-ui draws its panels. All of it loads with the first Space d key.
local run = require("config.run")

return {
  {
    "mfussenegger/nvim-dap",
    dependencies = { { "rcarriga/nvim-dap-ui", dependencies = { "nvim-neotest/nvim-nio" } } },
    keys = {
      { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "breakpoint, on or off" },
      { "<leader>dc", function() require("dap").continue() end, desc = "run, or go on to the next breakpoint" },
      { "<leader>dn", function() require("dap").step_over() end, desc = "the next line" },
      { "<leader>di", function() require("dap").step_into() end, desc = "step into the call" },
      { "<leader>do", function() require("dap").step_out() end, desc = "step out of this function" },
      { "<leader>du", function() require("dapui").toggle() end, desc = "the panels, open or hide" },
      { "<leader>dt", function() require("dap").terminate() end, desc = "end it" },
    },
    config = function()
      local dap, ui = require("dap"), require("dapui")
      ui.setup()
      -- The panels open with a run and close with its end.
      dap.listeners.after.event_initialized.kawa = function() ui.open() end
      dap.listeners.before.event_terminated.kawa = function() ui.close() end
      dap.listeners.before.event_exited.kawa = function() ui.close() end

      -- Python: debugpy runs this file, with the project's Python.
      dap.adapters.python = { type = "executable", command = "debugpy-adapter" }
      dap.configurations.python = {
        {
          type = "python",
          request = "launch",
          name = "this file",
          program = "${file}",
          console = "integratedTerminal",
          pythonPath = function() return run.venv_python(require("config.root").get()) or "python3" end,
        },
      }

      -- Rust: codelldb runs the program you name (cargo build made it, under target/debug/).
      dap.adapters.codelldb = {
        type = "server",
        port = "${port}",
        executable = { command = "codelldb", args = { "--port", "${port}" } },
      }
      dap.configurations.rust = {
        {
          type = "codelldb",
          request = "launch",
          name = "a program of this project",
          program = function() return vim.fn.input("program: ", require("config.root").get() .. "/target/debug/", "file") end,
          cwd = "${workspaceFolder}",
        },
      }
    end,
  },
}
