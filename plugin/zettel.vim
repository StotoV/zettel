if !has("python3")
    echo "vim has to be compiled with +python3 to run this"
    finish
endif

" Prevent loading multiple times
if exists("g:loaded_zettel_plugin")
    finish
endif
let g:loaded_zettel_plugin = 1

if !exists("g:zettel_dir")
    let g:zettel_dir = '~/.zettel'
endif

if !exists("g:zettel_random_title_length")
    let g:zettel_random_title_length = 5
endif

if !exists("g:zettel_fzf_fullscreen")
    let g:zettel_fzf_fullscreen = 0
endif

" Expose commands
command! -nargs=1 CreateZettel call s:create_zettel(<f-args>)
command! -nargs=1 DeleteZettel call s:delete_zettel(<f-args>)
command! -nargs=0 SearchZettels call s:search_zettels()

function! s:create_zettel(title)
python3 << EOF
import vim
import string
import random
import os

letters = string.ascii_lowercase
random_id = ''.join(random.choice(letters) for i in range(int(vim.eval('g:zettel_random_title_length'))))
zettel_path = os.path.expanduser(vim.eval('g:zettel_dir') + '/' + random_id + '_' + vim.eval('a:title'))
with open(zettel_path, 'x') as zettel:
    zettel.writelines(vim.eval('a:title') + '\n')
    zettel.writelines('-'*100 + '\n')
    zettel.writelines('\n')
    zettel.writelines('\n')
    zettel.writelines('-'*5 + ' External references ' + '-'*74 + '\n')
    zettel.writelines('\n')
    zettel.writelines('-'*100 + '\n')
    zettel.writelines('*Date:*  ' + '\n')
    zettel.writelines('*Tags:*  ' + '\n')
    zettel.writelines('*Backlinks:*  ')

vim.command('tabnew {}'.format(zettel_path))
EOF
endfunction

function! s:delete_zettel(zettel)
python3 << EOF
import vim
import os

zettel_path = os.path.expanduser(vim.eval('g:zettel_dir') + '/' + vim.eval('a:zettel'))
os.remove(zettel_path)
EOF
endfunction

function! s:search_zettels(zettel)
python3 << EOF
EOF
endfunction

function! s:search_zettels()
    let command = 'ag --smart-case --unrestricted --nogroup -- %s ' .. g:zettel_dir
    let initial_command = printf(command, '.')
    let reload_command = printf(command, '{q}')
    let spec = {'options': ['--phony', '--bind', 'change:reload:'.reload_command]}
    call fzf#vim#grep(initial_command, 0, fzf#vim#with_preview(spec), g:zettel_fzf_fullscreen)
endfunction
