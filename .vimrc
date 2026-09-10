" dna5rm portable Vim config - dark TUI / IDE feel (Pi, x86, Termux)
" Mouse, syntax, NERDTree sidebar, airline status/tab line, coc LSP, ALE.
"
" Quick keys
"   F1            cheat sheet popup (click X, q, or Esc to close)
"   F10           File / Edit / View / Tools menu (TUI bar)
"   Ctrl-s        save
"   F2            NERDTree sidebar toggle
"   C-h / C-l     move to left / right split   (C-w j/k also work)
"   C-J / C-K     ALE next / previous issue
"   gd gr gi      coc definition / references / implementation, K hover
"   C-space       coc trigger completion       Tab / S-Tab cycle popup
"   \n \p         next / previous buffer
"   \h            clear search highlight       \N toggle relative numbers
"   \w \q         write / quit
"
" Plugins: :PlugInstall after a fresh ~/.vim wipe.

" COMPAT FIRST ------------------------------------------------------------ {{{
set nocompatible

set encoding=utf-8
filetype plugin indent on
syntax on
" }}}
" OPTIONS ----------------------------------------------------------------- {{{
" Look and feel
set number
set relativenumber
set cursorline
set nowrap
set scrolloff=10
set showmatch
set showcmd
set showmode
set hidden
set title
set confirm
set noerrorbells
set belloff=all
set background=dark
set history=1000
set nobackup
set nowritebackup
set foldlevelstart=99

" Search
set hlsearch
set incsearch
set ignorecase
set smartcase

" Indent: 4 by default; yaml/html drop to 2 below
set autoindent
set expandtab
set tabstop=4
set softtabstop=4
set shiftwidth=4

" Splits and signs
set splitbelow
set splitright
set laststatus=2
if exists('+signcolumn')
    set signcolumn=auto
endif

" Mouse: GNU screen/tmux need xterm2; SGR there eats clicks.
if has('mouse')
    set mouse=a
    if exists('+ttymouse')
        if &term =~# 'screen' || &term =~# 'tmux'
            set ttymouse=xterm2
        elseif has('mouse_sgr')
            set ttymouse=sgr
        endif
    endif
endif
set ttimeout
set ttimeoutlen=50
" Truecolor only when the outer terminal actually advertises it.
" screen-256color without COLORTERM=truecolor + termguicolors = washed-out blue.
let s:truecolor = ($COLORTERM =~# 'truecolor' || $COLORTERM =~# '24bit')
if has('termguicolors') && s:truecolor
    set termguicolors
else
    set notermguicolors
endif

" Clipboard when the build supports it (Termux often has none)
if has('clipboard')
    set clipboard=unnamedplus
endif

" Wildmenu
if exists('+wildmenu')
    set wildmenu
    set wildmode=longest:full,full
    set wildignore=*.docx,*.jpg,*.jpeg,*.png,*.gif,*.pdf,*.pyc,*.o,*.so,*.swp,*.zip,*.exe,*.flv,*.img,*.xlsx,.git
    if exists('+wildoptions')
        set wildoptions=pum
    endif
endif

" coc startup tuning
set updatetime=300
set shortmess+=c

" Persistent undo
if has('persistent_undo')
    set undofile
    if !isdirectory(expand('~/.vim/undo'))
        call mkdir(expand('~/.vim/undo'), 'p')
    endif
    set undodir=~/.vim/undo//
endif

" Show stray whitespace (plain ASCII only)
set list
set listchars=tab:>-,trail:.,extends:>,precedes:<,nbsp:.
" }}}
" PLUGINS ----------------------------------------------------------------- {{{
" Fetch vim-plug once if missing. Install plugins with :PlugInstall.
let s:plug_vim = expand('~/.vim/autoload/plug.vim')
if !filereadable(s:plug_vim) && executable('curl')
    silent execute '!curl -fsSL --create-dirs --connect-timeout 8 --max-time 30 -o ' . shellescape(s:plug_vim) . ' https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
endif

if filereadable(s:plug_vim)
    call plug#begin()

    Plug 'dense-analysis/ale'
    Plug 'preservim/nerdtree'
    if executable('node')
        Plug 'neoclide/coc.nvim', {'branch': 'release'}
    endif
    Plug 'sainnhe/sonokai'
    Plug 'vim-airline/vim-airline'
    Plug 'momota/cisco.vim'
    Plug 'skywind3000/vim-quickui'

    call plug#end()
endif
" }}}
" AIRLINE ----------------------------------------------------------------- {{{
let g:airline_powerline_fonts = 1
let g:airline_theme = 'sonokai'
let g:airline#extensions#ale#enabled = 1
let g:airline#extensions#coc#enabled = 1
let g:airline#extensions#coc#stl_format_err = '%E{[%e(#%fe)] }'
let g:airline#extensions#coc#stl_format_warn = '%W{[%w(#%fw)]} '
" Buffer list across the top
let g:airline#extensions#tabline#enabled = 1
" }}}
" NERDTREE ---------------------------------------------------------------- {{{
let g:NERDTreeWinSize = 25
nnoremap <silent> <F2> :call <SID>file_tree()<CR>

function! s:file_tree() abort
    if exists(':NERDTreeToggle')
        NERDTreeToggle
    else
        Lexplore
    endif
endfunction

augroup vimrc_nerdtree
    autocmd!
    autocmd StdinReadPre * let s:std_in=1
    autocmd VimEnter * nested call s:open_tree_on_start()
    autocmd BufEnter * if winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree() | quit | endif
augroup END

function! s:open_tree_on_start() abort
    if exists('s:std_in')
        return
    endif
    if argc() == 1 && isdirectory(argv()[0]) && exists(':NERDTree')
        execute 'NERDTree' argv()[0]
        wincmd p
        enew
        execute 'cd '.argv()[0]
        return
    endif
    if exists(':NERDTree')
        NERDTree
        wincmd p
    endif
endfunction
" }}}
" COC --------------------------------------------------------------------- {{{
" Needs node on PATH. Skip entirely otherwise (no startup warning).
let g:coc_disable_startup_warning = 1
let g:coc_start_at_startup = executable('node')

if executable('node')
    let g:coc_global_extensions = [
     \ 'coc-pyright',
     \ 'coc-json',
     \ 'coc-sh',
     \ 'coc-yaml',
     \ '@yaegassy/coc-ansible',
     \ 'coc-pairs',
     \ ]

    let g:coc_filetype_map = {
     \ 'yaml.ansible': 'ansible',
     \ }

    let g:coc_user_config = {
     \ "diagnostic.errorSign": '⚠',
     \ "diagnostic.warningSign": '⚐',
     \ "diagnostic.infoSign": '⚐',
     \ "diagnostic.hintSign": '⚐',
     \ "diagnostic.signOffset": 100,
     \ "coc.preferences.enableFloatHighlight": v:false,
     \ }

    if exists('*coc#pum#visible')
        function! s:check_back_space() abort
            let col = col('.') - 1
            return !col || getline('.')[col - 1] =~# '\s'
        endfunction

        inoremap <silent><expr> <CR> coc#pum#visible() ? coc#pum#confirm() : "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"
        inoremap <silent><expr> <C-x><C-z> coc#pum#visible() ? coc#pum#stop() : "\<C-x>\<C-z>"
        inoremap <silent><expr> <TAB>
            \ coc#pum#visible() ? coc#pum#next(1):
            \ <SID>check_back_space() ? "\<Tab>" :
            \ coc#refresh()
        inoremap <expr><S-TAB> coc#pum#visible() ? coc#pum#prev(1) : "\<C-h>"
        inoremap <silent><expr> <c-space> coc#refresh()

        nmap <silent> gd <Plug>(coc-definition)
        nmap <silent> gr <Plug>(coc-references)
        nmap <silent> gi <Plug>(coc-implementation)
        nnoremap <silent> K :call CocAction('doHover')<CR>
        nmap <silent> <Leader>rn <Plug>(coc-rename)
    endif

    hi CocSearch ctermfg=12 guifg=#18A3FF
    hi CocMenuSel ctermbg=109 guibg=#13354A
endif
" }}}
" ALE --------------------------------------------------------------------- {{{
" Lint off: coc owns diagnostics. ALE only trims whitespace on save.
let g:ale_disable_lsp = 1
let g:ale_linters_explicit = 1
let g:ale_linters = {
 \ 'css':          [],
 \ 'javascript':   [],
 \ 'typescript':   [],
 \ 'json':         [],
 \ 'scss':         [],
 \ 'yaml':         [],
 \ 'python':       [],
 \ 'sh':           [],
 \ 'ansible':      [],
 \ 'yaml.ansible': [],
 \ }

" On save only trim whitespace / blank lines - never rubocop, mix or eslint
let g:ale_fix_on_save = 1
let g:ale_fixers = {
 \ '*': ['trim_whitespace', 'remove_trailing_lines'],
 \ }

" Signs in the gutter only; no whole-line highlighting (coc handles that)
let g:ale_set_highlights = 0

nmap <silent> <C-K> <Plug>(ale_previous_wrap)
nmap <silent> <C-J> <Plug>(ale_next_wrap)
" }}}
" MAPPINGS ---------------------------------------------------------------- {{{
" F1 is stock :help (full window, no close button). Replace with a popup.
function! s:help_filter(id, key) abort
    if a:key ==# "\<Esc>" || a:key ==# 'q' || a:key ==# "\<F1>"
        call popup_close(a:id)
        return 1
    endif
    return 0
endfunction

function! s:tui_help() abort
    let l:lines = [
        \ 'click the X, or press q / Esc / F1 to close',
        \ '',
        \ 'F10           File / Edit / View menu (click or arrows)',
        \ 'Ctrl-s        save file',
        \ 'F2            file tree on/off',
        \ 'click a file  open it from the tree',
        \ 'Ctrl-h / l    left / right split',
        \ 'gd  gr  K     definition / refs / hover (coc)',
        \ 'Tab / Enter   complete in the popup',
        \ '\n \p         next / prev buffer',
        \ '\h            clear search highlight',
        \ ':help topic   full help (then q to leave)',
        \ ':PlugInstall  download / update plugins',
        \ ]
    if has('popupwin')
        call popup_create(l:lines, {
            \ 'title': ' vim ',
            \ 'padding': [1, 2, 1, 2],
            \ 'border': [],
            \ 'close': 'button',
            \ 'filter': function('s:help_filter'),
            \ 'mapping': 0,
            \ 'minwidth': 46,
            \ })
    else
        echo join(l:lines, ' | ')
    endif
endfunction

nnoremap <silent> <F1> :call <SID>tui_help()<CR>
inoremap <silent> <F1> <C-o>:call <SID>tui_help()<CR>
vnoremap <silent> <F1> <Esc>:call <SID>tui_help()<CR>

" Ctrl-s save (do not use mswin.vim: Ctrl-a is GNU screen's prefix)
nnoremap <silent> <C-s> :write<CR>
inoremap <silent> <C-s> <C-o>:write<CR>
vnoremap <silent> <C-s> <C-c>:write<CR>

function! s:tui_menu() abort
    if empty(globpath(&rtp, 'autoload/quickui/menu.vim'))
        echo 'vim-quickui not on runtimepath — :PlugInstall then restart'
        return
    endif
    call s:setup_quickui()
    call quickui#menu#open()
endfunction
nnoremap <silent> <F10> :call <SID>tui_menu()<CR>
inoremap <silent> <F10> <C-o>:call <SID>tui_menu()<CR>
nnoremap <silent> <Leader>m :call <SID>tui_menu()<CR>

function! s:setup_quickui() abort
    if empty(globpath(&rtp, 'autoload/quickui/menu.vim'))
        return
    endif
    call quickui#menu#reset()
    call quickui#menu#install('&File', [
                \ [ "&New", 'enew' ],
                \ [ "&Open tree\tF2", 'NERDTreeToggle' ],
                \ [ "&Save\tCtrl-s", 'write' ],
                \ [ "Save &As...", 'execute "saveas " . input("Save as: ", expand("%:p"))' ],
                \ [ "--", '' ],
                \ [ "&Close buffer", 'bdelete' ],
                \ [ "&Quit", 'confirm qa' ],
                \ ])
    call quickui#menu#install('&Edit', [
                \ [ "&Undo", 'undo' ],
                \ [ "&Redo", 'redo' ],
                \ [ "--", '' ],
                \ [ "Cu&t", 'normal! d' ],
                \ [ "&Copy", 'normal! y' ],
                \ [ "&Paste", 'normal! p' ],
                \ [ "--", '' ],
                \ [ "&Find...", 'let @/ = input("Find: ") | set hlsearch | normal! n' ],
                \ [ "Find &Next", 'normal! n' ],
                \ ])
    call quickui#menu#install('&View', [
                \ [ "&File tree\tF2", 'NERDTreeToggle' ],
                \ [ "&Line numbers", 'set number! relativenumber!' ],
                \ [ "&Wrap", 'set wrap!' ],
                \ [ "Clear &highlight", 'nohlsearch' ],
                \ ])
    call quickui#menu#install('&Tools', [
                \ [ "&Command...", 'execute input(":", "", "command")' ],
                \ [ "Plug&Install", 'PlugInstall' ],
                \ [ "Coc &Restart", 'if exists(":CocRestart") | CocRestart | endif' ],
                \ ])
    call quickui#menu#install('&Help', [
                \ [ "&Keys\tF1", 'call <SID>tui_help()' ],
                \ [ "&Vim help...", 'execute "help " . input("help: ")' ],
                \ ])
    let g:quickui_show_tip = 1
    let g:quickui_border_style = 2
endfunction
autocmd VimEnter * call s:setup_quickui()

" If you still open :help, make that window TUI-closable too
augroup vimrc_help
    autocmd!
    autocmd FileType help setlocal nobuflisted
    autocmd FileType help nnoremap <buffer> <silent> q :helpclose<CR>
    autocmd FileType help nnoremap <buffer> <silent> <Esc> :helpclose<CR>
    autocmd FileType help nnoremap <buffer> <silent> <2-LeftMouse> :helpclose<CR>
augroup END

" Splits (C-J / C-K belong to ALE above)
nnoremap <silent> <C-h> <C-w>h
nnoremap <silent> <C-l> <C-w>l

" Buffers and tabs
nnoremap <silent> <Leader>n :bnext<CR>
nnoremap <silent> <Leader>p :bprevious<CR>
nnoremap <silent> <Leader>bd :bdelete<CR>

" Search and display
nnoremap <silent> <Leader>h :nohlsearch<CR>
nnoremap <silent> <Leader>N :set relativenumber!<CR>

" Files
nnoremap <silent> <Leader>w :write<CR>
nnoremap <silent> <Leader>q :quit<CR>
" }}}
" FILETYPES --------------------------------------------------------------- {{{
augroup vimrc_filetypes
    autocmd!
    autocmd FileType vim setlocal foldmethod=marker
    autocmd FileType html,yaml setlocal tabstop=2 shiftwidth=2 softtabstop=2 expandtab
    autocmd BufRead,BufNewFile *.cisco setlocal filetype=cisco
augroup END
" yaml stays plain yaml; opt in per file with :set filetype=yaml.ansible
" Other extensions: open the file, then :set filetype=cisco
" }}}
" COLOR THEME ------------------------------------------------------------- {{{
" Guarded: a missing colorscheme plugin must not abort startup
set background=dark
let g:sonokai_style = 'shusia'
let g:sonokai_better_performance = 1
let g:sonokai_disable_italic_comment = 1
silent! colorscheme sonokai
if !exists('g:colors_name') || g:colors_name !=# 'sonokai'
    silent! colorscheme habamax
    set background=dark
endif
highlight Normal ctermbg=NONE guibg=NONE
" }}}
" vim: set foldmethod=marker: