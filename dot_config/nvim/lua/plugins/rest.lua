return {
  "rest-nvim/rest.nvim",
  -- The upstream rockspec currently fails while installing its
  -- tree-sitter-http build backend. Install those Lua dependencies as
  -- regular plugins instead; the http parser is managed in treesitter.lua.
  build = false,
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "j-hui/fidget.nvim",
    "nvim-neotest/nvim-nio",
    {
      "manoelcampos/xml2lua",
      config = function(plugin)
        package.path = package.path .. ";" .. plugin.dir .. "/?.lua"
      end,
    },
    {
      "lunarmodules/lua-mimetypes",
      config = function(plugin)
        package.path = package.path .. ";" .. plugin.dir .. "/?.lua"
      end,
    },
  },
  keys = {
    { "<leader>rr", "<cmd>Rest run<cr>", desc = "Run request under cursor" },
    { "<leader>rl", "<cmd>Rest run last<cr>", desc = "Re-run last request" },
  },
  opts = {},
}
