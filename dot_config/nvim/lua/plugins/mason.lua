return {
  "mason-org/mason.nvim",
  opts = {
    ensure_installed = {
      -- Tools
      "ast-grep",

      -- Formatters
      "clang-format",
      "shfmt",
      "stylua",
      "prettier", -- or "prettierd" for faster formatting

      -- Linters
      "eslint_d", -- faster than eslint-lsp

      -- LSP Servers
      "clangd",
      "lua-language-server",
      "pyright",
      "typescript-language-server", -- for JS/TS
    },
  },
}