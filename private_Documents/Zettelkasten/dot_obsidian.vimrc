" Unmap Space first so it can be used in mappings
unmap <Space>

" Navigate to link under cursor
exmap followlink obcommand editor:follow-link
nmap gd :followlink<cr>
nmap gf :followlink<cr>

" Follow links with Enter
nmap <cr> :followlink<cr>

" Navigate back and forward
exmap back obcommand app:go-back
nmap <C-o> :back<cr>
exmap forward obcommand app:go-forward
nmap <C-i> :forward<cr>

" Open symbols in current file (Quick Switcher++)
exmap symbols obcommand darlal-switcher-plus:switcher-plus:open-symbols
nmap gs :symbols<cr>



" Then use Space directly in your mappings
exmap completeTask obcommand editor:toggle-checklist-status
nmap <Space>. kmzj:completeTask<CR>ddGp`z


" Common vim settings
set clipboard=unnamed
imap jk <Esc>
imap jj <Esc>

" H and L for start/end of line
nmap H ^
nmap L $
