return {
  "nvim-lualine/lualine.nvim",
  opts = function(_, opts)
    -- Custom colors for mode section
    local colors = {
      normal = "#89b4fa",   -- Blue for NORMAL mode
      insert = "#ffffd7",   -- Light yellow/cream for INSERT mode (from starship)
      visual = "#cba6f7",   -- Purple for VISUAL mode
      replace = "#f38ba8",  -- Red for REPLACE mode
      command = "#f9e2af",  -- Yellow for COMMAND mode
      bg = "#000000",       -- Black text (matching starship)
      fg = "#cdd6f4",       -- Foreground/text color
    }

    -- Custom theme with your colors
    local custom_theme = {
      normal = {
        a = { bg = colors.normal, fg = colors.bg, gui = "bold" },
        b = { bg = "#313244", fg = colors.fg },
        c = { bg = "#181825", fg = colors.fg },
      },
      insert = {
        a = { bg = colors.insert, fg = colors.bg, gui = "bold" },
      },
      visual = {
        a = { bg = colors.visual, fg = colors.bg, gui = "bold" },
      },
      replace = {
        a = { bg = colors.replace, fg = colors.bg, gui = "bold" },
      },
      command = {
        a = { bg = colors.command, fg = colors.bg, gui = "bold" },
      },
    }

    opts.options = opts.options or {}
    opts.options.theme = custom_theme

    return opts
  end,
}
