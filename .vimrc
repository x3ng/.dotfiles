" global settings
"" basic config
set nocompatible
set encoding=utf-8
syntax enable
syntax on
filetype plugin indent on

"" interface
set number
set relativenumber
set cursorline
set showcmd
set showmode
set ruler
""" end line space
highlight ExtraWhitespace ctermbg=red guibg=red
autocmd BufWinEnter * match ExtraWhitespace /\s\+$/
autocmd InsertEnter * match ExtraWhitespace /\s\+\%#\@<!$/
autocmd InsertLeave * match ExtraWhitespace /\s\+$/
autocmd BufWinLeave * call clearmatches()

"" indent
set tabstop=4
set softtabstop=4
set shiftwidth=4
set expandtab
set autoindent
set smartindent
set cindent

"" experience
""" roll
set scrolloff=5
set sidescrolloff=5
""" search
set hlsearch
set incsearch
set ignorecase
set smartcase
""" fold
set foldmethod=indent
set foldlevel=99
""" undo
set undofile
set undodir=~/.vim/undo/
call mkdir(&undodir, 'p')
set undolevels=10000

"" language
autocmd FileType python setlocal tabstop=4 softtabstop=4 shiftwidth=4 expandtab
autocmd FileType c,cpp setlocal tabstop=4 softtabstop=4 shiftwidth=4 expandtab
""" filetype define
autocmd BufNewFile,BufRead *.cc,*.hh set filetype=cpp

"" global keymap
""" insert mode keymap
inoremap <C-h> <Left>
inoremap <C-j> <Down>
inoremap <C-k> <Up>
inoremap <C-l> <Right>
inoremap <C-a> <ESC>^i
inoremap <C-e> <ESC>$a
inoremap <C-s> :w<CR>
""" normal mode keymap
nnoremap <silent> <leader>2 :setlocal tabstop=2 softtabstop=2 shiftwidth=2 expandtab \| echomsg "2 spaces indent"<CR>
nnoremap <silent> <leader>4 :setlocal tabstop=4 softtabstop=4 shiftwidth=4 expandtab \| echomsg "4 spaces indent"<CR>

" vim plug
"" install plug
if empty(glob('~/.vim/autoload/plug.vim'))
    function! InstallPlug()
        " check curl
        if !executable('curl')
            echoerr "Error: curl is not installed"
            return
        endif
        " vim plug config
        let plug_dir = expand('~/.vim/autoload')
        call mkdir(plug_dir, 'p')
        let plug_path = plug_dir . '/plug.vim'
        let plug_url = 'https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
        let cmd = 'curl -sfL ' . shellescape(plug_url) . ' -o ' . shellescape(plug_path)
        " install
        execute 'silent !' . cmd
        " check result
        if v:shell_error == 0 && filereadable(plug_path)
            echo "vim-plug installed successfully!"
            source $MYVIMRC
        else
            echoerr "Error: Failed to install vim-plug"
        endif
    endfunction
    " call function
    call InstallPlug()
else
    call plug#begin('~/.vim/plugged')
        Plug 'preservim/nerdtree'
        " lsp
        Plug 'prabirshrestha/vim-lsp'
        Plug 'mattn/vim-lsp-settings'
        " completion ui
        Plug 'prabirshrestha/asyncomplete.vim'
        Plug 'prabirshrestha/asyncomplete-lsp.vim'
        " theme
        Plug 'morhetz/gruvbox'
    call plug#end()
endif

"" nerdtree
""" nerdtree keymap
nnoremap <leader>n :NERDTreeToggle<CR>
nnoremap <leader>f :NERDTreeFind<CR>
nnoremap <leader>tc :NERDTreeClose<CR>
nnoremap <leader>tr :NERDTree $PROJECT_ROOT<CR>

"" lsp
""" vim lsp
let g:lsp_log_file = expand('~/.vim/logs/lsp.log')
call mkdir(expand('~/.vim/logs'), 'p')
let g:lsp_auto_enable = 1
let g:lsp_diagnostics_enable = 1
let g:lsp_diagnostics_echo_cursor = 1
let g:lsp_diagnostics_signs_enabled = 1
let g:lsp_diagnostics_virtual_text_enabled = 0
let g:lsp_diagnostics_float_cursor = 0
let g:lsp_diagnostics_highlights_enabled = 1
""" completion ui
let g:asyncomplete_auto_popup = 0
let g:asyncomplete_popup_max_width = 80
let g:asyncomplete_popup_max_height =  20
let g:asyncomplete_min_chars = 2
""" lsp keymap
nmap <silent> gd <plug>(lsp-definition)
nmap <silent> gy <plug>(lsp-type-definition)
nmap <silent> gi <plug>(lsp-implementation)
nmap <silent> gr <plug>(lsp-references)
nmap <silent> gh <plug>(lsp-hover)
nmap <silent> ge <plug>(lsp-diagnostics-next)
nmap <silent> gE <plug>(lsp-diagnostics-prev)
nmap <silent> <leader>b <C-o>
nnoremap <silent> <leader>f :call lsp#formatting#format()<CR>

inoremap <silent> <leader>f <ESC>:call lsp#formatting#format()<CR>a
inoremap <silent> <C-space> <C-x><C-o>

"" theme
""" theme config
set termguicolors
set background=dark
let g:gruvbox_contrast_light = "soft"
let g:gruvbox_contrast_dark = "hard"
colorscheme gruvbox
