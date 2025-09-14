-- Plugins migrated from LunarVim config
return {
  -- nvim-surround for surrounding text objects
  {
    "kylechui/nvim-surround",
    version = "*",
    event = "VeryLazy",
    opts = {},
  },

  -- registers.nvim for viewing registers
  {
    "tversteeg/registers.nvim",
    event = "VeryLazy",
    config = true,
    keys = {
      { '"', mode = { "n", "v" } },
      { "<C-R>", mode = "i" },
    },
    cmd = "Registers",
  },
}