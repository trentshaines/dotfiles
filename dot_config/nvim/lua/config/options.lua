-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Force tokyonight colorscheme
vim.g.lazyvim_colorscheme = "tokyonight"

-- Auto-reload files when changed externally
vim.o.autoread = true

-- Check for file changes on these events
vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "CursorHoldI", "FocusGained" }, {
  command = "if mode() != 'c' | checktime | endif",
  pattern = { "*" },
})

-- Disable snacks scroll animations
vim.g.snacks_animate = false

-- Enable spell checking
vim.opt.spell = true
vim.opt.spelllang = "en_us"

-- Enable readable wrapped code globally
vim.opt.wrap = true            -- Enable line wrapping
vim.opt.linebreak = true       -- Break at word boundaries
vim.opt.breakindent = true     -- Maintain indentation on wrapped lines
vim.opt.showbreak = "↪ "       -- Visual indicator for wrapped lines

