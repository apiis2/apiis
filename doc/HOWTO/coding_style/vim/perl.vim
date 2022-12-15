""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" $Id: perl.vim,v 1.1 2006/11/13 13:55:08 heli Exp $
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" file ~/.vim/after/ftplugin/perl.vim
"
" The = in command mode filters the highlighted text through perltidy:
set equalprg=/usr/bin/perltidy

" some settings for folding:
if version >= 500
    let perl_include_pod = 1
    let perl_want_scope_in_variables = 1
    let perl_extended_vars = 1
    let perl_string_as_statement = 1
endif
if version >= 600
    let perl_fold = 1
    let perl_fold_blocks = 1
endif

" open all folds except POD:
au BufWinEnter * let&fdl=&fdn|exe 'silent!g/^=cut/norm!zc' |1

" replace all tabs with 4 spaces (if expandtab is on):
" au BufWinEnter * retab! 4

" Read project-specific vimrc file:
autocmd BufRead,BufNewFile $APIIS_HOME/* so $APIIS_HOME/etc/vimrc

