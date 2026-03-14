return {
  "sindrets/diffview.nvim",
  cmd = { "DiffviewOpen", "DiffviewFileHistory" },
  keys = {
    { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Diff view (working tree)" },
    { "<leader>gD", "<cmd>DiffviewOpen HEAD~1<cr>", desc = "Diff view (last commit)" },
    { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "File history (current)" },
    { "<leader>gH", "<cmd>DiffviewFileHistory<cr>", desc = "File history (repo)" },
  },
}
