return {
  "rest-nvim/rest.nvim",
  dependencies = { "nvim-treesitter/nvim-treesitter" },
  keys = {
    { "<leader>rr", "<cmd>Rest run<cr>", desc = "Run request under cursor" },
    { "<leader>rl", "<cmd>Rest run last<cr>", desc = "Re-run last request" },
  },
}
