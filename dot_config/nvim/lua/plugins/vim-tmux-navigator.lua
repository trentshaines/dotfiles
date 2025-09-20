return {
  "christoomey/vim-tmux-navigator",
  lazy = false,
  keys = {
    { "<C-h>", "<cmd>TmuxNavigateLeft<cr>", desc = "Navigate left" },
    { "<C-j>", "<cmd>TmuxNavigateDown<cr>", desc = "Navigate down" },
    { "<C-k>", "<cmd>TmuxNavigateUp<cr>", desc = "Navigate up" },
    { "<C-l>", "<cmd>TmuxNavigateRight<cr>", desc = "Navigate right" },
    { "<C-\\>", "<cmd>TmuxNavigatePrevious<cr>", desc = "Navigate previous" },
  },
  config = function()
    -- Add window swapping keymaps that mirror tmux (prefix + Shift+hjkl)
    -- Using <leader> as the "prefix" equivalent in vim
    vim.keymap.set("n", "<leader>H", "<C-w>H", { desc = "Move window left" })
    vim.keymap.set("n", "<leader>J", "<C-w>J", { desc = "Move window down" })
    vim.keymap.set("n", "<leader>K", "<C-w>K", { desc = "Move window up" })
    vim.keymap.set("n", "<leader>L", "<C-w>L", { desc = "Move window right" })

    -- Also add lowercase for navigation (matching tmux prefix+hjkl fallback)
    vim.keymap.set("n", "<leader>h", "<C-w>h", { desc = "Navigate window left" })
    vim.keymap.set("n", "<leader>j", "<C-w>j", { desc = "Navigate window down" })
    vim.keymap.set("n", "<leader>k", "<C-w>k", { desc = "Navigate window up" })
    vim.keymap.set("n", "<leader>l", "<C-w>l", { desc = "Navigate window right" })
  end,
}