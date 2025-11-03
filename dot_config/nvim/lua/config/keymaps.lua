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

-- Window resizing with C-w + hjkl (border-centric like tmux)
map("n", "<C-w>h", "<cmd>vertical resize -2<cr>", { desc = "Move border left" })
map("n", "<C-w>j", "<cmd>resize +2<cr>", { desc = "Move border down" })
map("n", "<C-w>k", "<cmd>resize -2<cr>", { desc = "Move border up" })
map("n", "<C-w>l", "<cmd>vertical resize +2<cr>", { desc = "Move border right" })

-- Large resize with C-w + Shift + HJKL (border-centric)
map("n", "<C-w>H", "<cmd>vertical resize -10<cr>", { desc = "Move border left (large)" })
map("n", "<C-w>J", "<cmd>resize +10<cr>", { desc = "Move border down (large)" })
map("n", "<C-w>K", "<cmd>resize -10<cr>", { desc = "Move border up (large)" })
map("n", "<C-w>L", "<cmd>vertical resize +10<cr>", { desc = "Move border right (large)" })
