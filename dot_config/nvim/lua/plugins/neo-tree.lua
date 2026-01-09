return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = {
      filesystem = {
        filtered_items = {
          visible = true, -- Show filtered items (they appear dimmed)
          hide_dotfiles = false, -- Show dotfiles
          hide_gitignored = false, -- Show git ignored files
          hide_hidden = false, -- Show hidden files on Windows
        },
      },
    },
  },
}
