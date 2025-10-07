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

" Common vim settings
set clipboard=unnamed
imap jk <Esc>
imap jj <Esc>