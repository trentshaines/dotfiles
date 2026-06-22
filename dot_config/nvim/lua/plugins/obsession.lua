return {
  {
    "tpope/vim-obsession",
    lazy = false,
    config = function()
      local group = vim.api.nvim_create_augroup("tmux_resurrect_obsession", { clear = true })

      local function project_like(cwd)
        if vim.fn.filereadable(cwd .. "/Session.vim") == 1 then
          return true
        end

        return vim.fs.root(cwd, {
          ".git",
          "Cargo.toml",
          "flake.nix",
          "go.mod",
          "Makefile",
          "package.json",
          "pyproject.toml",
        }) ~= nil
      end

      local function start_obsession()
        if vim.env.TMUX == nil or vim.env.TMUX == "" then
          return
        end
        if vim.fn.exists(":Obsess") == 0 then
          return
        end

        local cwd = vim.fn.getcwd()
        if cwd == vim.env.HOME or vim.fn.filewritable(cwd) ~= 2 or not project_like(cwd) then
          return
        end

        vim.cmd("silent! Obsess " .. vim.fn.fnameescape(cwd .. "/Session.vim"))
      end

      vim.api.nvim_create_autocmd("VimEnter", {
        group = group,
        callback = function()
          vim.schedule(start_obsession)
        end,
      })

      vim.api.nvim_create_autocmd("DirChanged", {
        group = group,
        callback = function()
          vim.schedule(start_obsession)
        end,
      })

      vim.schedule(start_obsession)
    end,
  },
}
