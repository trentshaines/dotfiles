return {
  "williamboman/mason.nvim",
  opts = {
    ensure_installed = {
      -- Tools
      "ast-grep",

      -- Formatters
      "clang-format",
      "shfmt",
      "stylua",

      -- LSP Servers
      "clangd",
      "lua-language-server",
      "pyright",
    },
  },
}