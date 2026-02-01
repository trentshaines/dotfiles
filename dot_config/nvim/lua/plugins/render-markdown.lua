-- Configure render-markdown.nvim for proper header rendering
return {
  "MeanderingProgrammer/render-markdown.nvim",
  opts = {
    heading = {
      enabled = true,
      sign = false,
      icons = { "# ", "## ", "### ", "#### ", "##### ", "###### " },
      width = "full", -- full width background highlight
      backgrounds = {
        "RenderMarkdownH1Bg",
        "RenderMarkdownH2Bg",
        "RenderMarkdownH3Bg",
        "RenderMarkdownH4Bg",
        "RenderMarkdownH5Bg",
        "RenderMarkdownH6Bg",
      },
    },
    code = {
      enabled = true,
      width = "full",
      border = "thick",
    },
  },
  ft = { "markdown", "norg", "rmd", "org" },
  config = function(_, opts)
    require("render-markdown").setup(opts)
    vim.api.nvim_create_autocmd("FileType", {
      pattern = { "markdown" },
      callback = function()
        vim.opt_local.conceallevel = 2
      end,
    })
  end,
}
