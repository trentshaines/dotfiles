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
    -- The original repository was deleted. Pin its read-only backup so a
    -- future change to the backup cannot silently alter this plugin.
    "prg318/registers.nvim",
    commit = "73a2fa79e99da83df5c9f36cca62c41eb3fd7b27",
    event = "VeryLazy",
    config = true,
    keys = {
      { '"', mode = { "n", "v" } },
      { "<C-R>", mode = "i" },
    },
    cmd = "Registers",
  },
}
