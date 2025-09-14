-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap.set

-- Cursor Movement (from LunarVim config)
map("n", "<leader>o", "<C-o>", { desc = "Jump back" })
map("n", "<leader>i", "<C-i>", { desc = "Jump forward" })

-- Buffer navigation with number keys (1-9)
for i = 1, 9 do
  map("n", "<leader>" .. i, function()
    require("bufferline").go_to(i, true)
  end, { desc = "Go to buffer " .. i })
end
