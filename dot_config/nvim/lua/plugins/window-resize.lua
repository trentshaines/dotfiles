-- Window resize keymaps
return {
  "nvim-lua/plenary.nvim",
  init = function()
    -- Set up resize keymaps after LazyVim loads
    vim.api.nvim_create_autocmd("VimEnter", {
      callback = function()
        -- Window resizing with C-w + hjkl (border-centric like tmux)
        vim.keymap.set("n", "<C-w>h", "<cmd>vertical resize -2<cr>", { desc = "Move border left" })
        vim.keymap.set("n", "<C-w>j", "<cmd>resize +2<cr>", { desc = "Move border down" })
        vim.keymap.set("n", "<C-w>k", "<cmd>resize -2<cr>", { desc = "Move border up" })
        vim.keymap.set("n", "<C-w>l", "<cmd>vertical resize +2<cr>", { desc = "Move border right" })

        -- Large resize with C-w + Shift + HJKL (border-centric)
        vim.keymap.set("n", "<C-w>H", "<cmd>vertical resize -10<cr>", { desc = "Move border left (large)" })
        vim.keymap.set("n", "<C-w>J", "<cmd>resize +10<cr>", { desc = "Move border down (large)" })
        vim.keymap.set("n", "<C-w>K", "<cmd>resize -10<cr>", { desc = "Move border up (large)" })
        vim.keymap.set("n", "<C-w>L", "<cmd>vertical resize +10<cr>", { desc = "Move border right (large)" })
      end,
    })
  end,
}