-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap.set

-- Cursor Movement (from LunarVim config)
map("n", "<leader>o", "<C-o>", { desc = "Jump back" })
map("n", "<leader>i", "<C-i>", { desc = "Jump forward" })

-- H/L for beginning/end of line
map({ "n", "v", "o" }, "H", "^", { desc = "Beginning of line" })
map({ "n", "v", "o" }, "L", "$", { desc = "End of line" })

-- Buffer navigation with number keys (1-9)
for i = 1, 9 do
  map("n", "<leader>" .. i, function()
    require("bufferline").go_to(i, true)
  end, { desc = "Go to buffer " .. i })
end

-- Window resizing with C-w + hjkl (since C-hjkl is used for navigation)
map("n", "<C-w>h", "<cmd>vertical resize -2<cr>", { desc = "Decrease window width" })
map("n", "<C-w>j", "<cmd>resize -2<cr>", { desc = "Decrease window height" })
map("n", "<C-w>k", "<cmd>resize +2<cr>", { desc = "Increase window height" })
map("n", "<C-w>l", "<cmd>vertical resize +2<cr>", { desc = "Increase window width" })

-- Large resize with C-w + Shift + HJKL
map("n", "<C-w>H", "<cmd>vertical resize -10<cr>", { desc = "Decrease window width (large)" })
map("n", "<C-w>J", "<cmd>resize -10<cr>", { desc = "Decrease window height (large)" })
map("n", "<C-w>K", "<cmd>resize +10<cr>", { desc = "Increase window height (large)" })
map("n", "<C-w>L", "<cmd>vertical resize +10<cr>", { desc = "Increase window width (large)" })

-- Spell checking keymaps
map("n", "zc", "1z=", { desc = "Auto-correct with first suggestion" })
map("n", "zv", "z=", { desc = "List spelling suggestions" })

-- Parrot AI keymaps
map("v", "<leader>Cr", ":PrtRewrite<cr>", { desc = "AI Rewrite" })
map("v", "<leader>Cc", ":PrtComplete<cr>", { desc = "AI Complete" })
map("v", "<leader>Ci", ":PrtImplement<cr>", { desc = "AI Implement" })
map("n", "<leader>Cm", "<cmd>PrtModel<cr>", { desc = "AI Model Select" })

-- Copy file path and content to clipboard
map("n", "<leader>yp", function()
  local path = vim.fn.expand("%")
  vim.fn.setreg("+", path)
  vim.notify('Copied relative path: ' .. path, vim.log.levels.INFO)
end, { desc = "Copy relative file path" })

map("n", "<leader>yP", function()
  local path = vim.fn.expand("%:p")
  vim.fn.setreg("+", path)
  vim.notify('Copied absolute path: ' .. path, vim.log.levels.INFO)
end, { desc = "Copy absolute file path" })

map("n", "<leader>yf", function()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local content = table.concat(lines, "\n")
  vim.fn.setreg("+", content)
  vim.notify('Copied file content (' .. #lines .. ' lines)', vim.log.levels.INFO)
end, { desc = "Copy file content" })
