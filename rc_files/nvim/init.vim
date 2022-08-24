"                         _
"      ___  ___ ___ _  __(_)_ _
"     / _ \/ -_) _ \ |/ / /  ' \
"    /_//_/\__/\___/___/_/_/_/_/
"                   ** init.vim

" GENERAL ---------------------------------------------------------------- {{{
    filetype on             " Enable type file detection.
    filetype indent on      " Load an indent file for the detected file type.
    filetype plugin on      " Enable plugins and load plugin for the detected file type.

    set cursorcolumn        " Highlight cursor line underneath the cursor vertically.
    set cursorline          " Highlight cursor line underneath the cursor horizontally.
    set expandtab           " Use space characters instead of tabs.
    set history=1000        " Set the commands to save in history default number is 20.
    set hlsearch            " Use highlighting when doing a search.
    set ignorecase          " Ignore capital letters during search.
    set incsearch           " While searching though a file incrementally highlight matching characters as you type.
    set nobackup            " Do not save backup files.
    set nocompatible        " Disable compatibility with vi which can cause unexpected issues.
    set nowrap              " Do not wrap lines
    set number              " Add numbers to each line on the left-hand side.
    set scrolloff=10        " Do not let cursor scroll below or above N number of lines when scrolling.
    set shiftwidth=4        " Set shift width to 4 spaces.
    set showcmd             " Show partial command you type in the last line of the screen.
    set showmatch           " Show matching words during a search.
    set showmode            " Show the mode you are on the last line.
    set smartcase           " Override the ignorecase option if searching for capital letters.
    set tabstop=4           " Set tab width to 4 columns.
    set wildmenu            " Enable auto completion menu after pressing TAB.
    set wildignore=*.docx,*.jpg,*.png,*.gif,*.pdf,*.pyc,*.exe,*.flv,*.img,*.xlsx
    set wildmode=list:longest

    syntax on               " Turn syntax highlighting on.
" }}}
" PLUGINS ---------------------------------------------------------------- {{{
    " bootstrap plugins
    let plug_install = 0
    let autoload_plug_path = stdpath('config') . '/autoload/plug.vim'
    if !filereadable(autoload_plug_path)
        silent exe '!curl -fL --create-dirs -o ' . autoload_plug_path .
         \ ' https://raw.github.com/junegunn/vim-plug/master/plug.vim'
        execute 'source ' . fnameescape(autoload_plug_path)
        let plug_install = 1
    endif
    unlet autoload_plug_path

    " nvim plugins
    call plug#begin(stdpath('config') . '/plugins')
        " Asynchronous Lint Engine
        Plug 'dense-analysis/ale'

        " NerdTree Blade
        Plug 'preservim/nerdtree' |
         \ Plug 'Xuyuanp/nerdtree-git-plugin' |
         \ Plug 'ryanoasis/vim-devicons'

        " Auto Completion
        Plug 'neoclide/coc.nvim', {'branch': 'release'}

        " Color Theme
        Plug 'sainnhe/sonokai'

        " Sensible VIm settings
        Plug 'tpope/vim-sensible'

        " Status Line
        Plug 'vim-airline/vim-airline' |
         \ Plug 'vim-airline/vim-airline-themes'

        " GitHub Copilot
        Plug 'github/copilot.vim'

        " Cisco Config Highlighting
        Plug 'momota/cisco.vim'
    call plug#end()

    " install plugins
    if plug_install
        PlugInstall --sync
    endif
    unlet plug_install

" }}}
" MAPPINGS --------------------------------------------------------------- {{{
    " nnoremap - Allows you to map keys in normal mode.
    " inoremap - Allows you to map keys in insert mode.
    " vnoremap - Allows you to map keys in visual mode.
" }}}
" VIMSCRIPT -------------------------------------------------------------- {{{
    " This will enable code folding.
    augroup filetype_vim
        autocmd!
        autocmd FileType vim setlocal foldmethod=marker
    augroup END

    " If the current file type is HTML, set indentation to 2 spaces.
    autocmd Filetype html setlocal tabstop=2 shiftwidth=2 expandtab

    " Start NERDTree when Vim starts with a directory argument.
    autocmd StdinReadPre * let s:std_in=1
    autocmd VimEnter * if argc() == 1 && isdirectory(argv()[0]) && !exists('s:std_in') |
        \ execute 'NERDTree' argv()[0] | wincmd p | enew | execute 'cd '.argv()[0] | endif

    au BufRead,BufNewFile *.yaml set filetype=yaml.ansible
" }}}
" COLOR THEME ------------------------------------------------------------ {{{
    " Important!!
    if has('termguicolors')
        set termguicolors
    endif

    " The configuration options should be placed before `colorscheme sonokai`.
    let g:sonokai_style = 'shusia'
    let g:sonokai_better_performance = 1

    colorscheme sonokai
" }}}
" PLUGIN: AIRLINE -------------------------------------------------------- {{{
    " air-line
    let g:airline_powerline_fonts = 1

    if !exists('g:airline_symbols')
        let g:airline_symbols = {}
    endif

    " unicode symbols
    let g:airline_left_sep = '»'
    let g:airline_left_sep = '▶'
    let g:airline_right_sep = '«'
    let g:airline_right_sep = '◀'
    let g:airline_symbols.linenr = '␊'
    let g:airline_symbols.linenr = '␤'
    let g:airline_symbols.linenr = '¶'
    let g:airline_symbols.branch = '⎇'
    let g:airline_symbols.paste = 'ρ'
    let g:airline_symbols.paste = 'Þ'
    let g:airline_symbols.paste = '∥'
    let g:airline_symbols.whitespace = 'Ξ'

    " airline symbols
    let g:airline_left_sep = ''
    let g:airline_left_alt_sep = ''
    let g:airline_right_sep = ''
    let g:airline_right_alt_sep = ''
    let g:airline_symbols.branch = ''
    let g:airline_symbols.readonly = ''
    let g:airline_symbols.linenr = ''

    let g:airline_theme='base16_flat'
" }}}
" PLUGIN: ALE ------------------------------------------------------------ {{{

    highlight clear ALEErrorSign
    highlight clear ALEWarningSign
    hi link ALEErrorSign    GitGutterDelete
    hi link ALEWarningSign  Todo

    " Remaps
    nmap <silent> <C-K> <Plug>(ale_previous_wrap)
    nmap <silent> <C-J> <Plug>(ale_next_wrap)

    " Dissabled linters (since COC takes care of these)
    let g:ale_linters = {
     \  'css':        [],
     \  'javascript': [],
     \  'typescript': [],
     \  'json':       [],
     \  'scss':       [],
     \  'yaml':       []
     \ }

    " Autofixing
    let g:ale_fixers = {
     \ '*': ['trim_whitespace', 'remove_trailing_lines'],
     \ 'javascript': ['eslint'],
     \ 'typescript': ['eslint', 'tslint'],
     \ 'ruby': ['rubocop'],
     \ 'markdown': ['prettier'],
     \ 'scss': ['stylelint'],
     \ 'elixir': ['mix_format']
     \ }

    let g:ale_fix_on_save = 1

    " Airline integration
    let g:airline#extensions#ale#enabled = 1
    let g:ale_statusline_format = ['⚠ %d', '⚠ %d', '']
    let g:ale_echo_msg_error_str = '⚠'
    let g:ale_echo_msg_warning_str = '⚐'
" }}}
" PLUGIN: COC ------------------------------------------------------------ {{{
    let g:coc_global_extensions = [
     \ 'coc-cmake', 'coc-highlight', 'coc-html', 'coc-json', 'coc-markdownlint', 'coc-pairs',
     \ 'coc-perl', 'coc-phpls', 'coc-pyright', 'coc-sh', 'coc-spell-checker', '@yaegassy/coc-ansible'
     \ ]

     " \ 'coc-json', 'coc-pairs', 'coc-eslint',  'coc-tsserver',
     " \ 'coc-html', 'coc-css', 'coc-solargraph', 'coc-yaml', 'coc-emmet',
     " \ 'coc-lists', 'coc-snippets', 'coc-git', 'coc-elixir', 'coc-marketplace',
     " \ 'coc-webpack', 'coc-lua', 'coc-vimlsp', 'coc-docker', 'coc-tslint',
     " \ 'coc-cmake', 'coc-highlight', 'coc-markdownlint', 'coc-perl', 'coc-pairs'

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

    let g:airline#extensions#coc#enabled = 1
    let airline#extensions#coc#stl_format_err = '%E{[%e(#%fe)] }'
    let airline#extensions#coc#stl_format_warn = '%W{[%w(#%fw)]} '

    " highlight clear CocErrorSign
    " highlight clear CocWarningSign
    " hi link CocErrorSign GitGutterDelete
    " hi link CocWarningSign  WarningMsg

    " if hidden is not set, TextEdit might fail.
    " set hidden

    " Some servers have issues with backup files, see #649
    set nobackup
    set nowritebackup

    " don't give |ins-completion-menu| messages.
    set shortmess+=c

    " You will have bad experience for diagnostic messages when it's default 4000.
    set updatetime=300

    " always show signcolumns
    set signcolumn=yes

    " Use CR for trigger completion with characters ahead and navigate.
    inoremap <silent><expr> <CR> coc#pum#visible() ? coc#pum#confirm() : "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"
    inoremap <silent><expr> <C-x><C-z> coc#pum#visible() ? coc#pum#stop() : "\<C-x>\<C-z>"

    " remap for complete to use tab and <cr>
    inoremap <silent><expr> <TAB>
        \ coc#pum#visible() ? coc#pum#next(1):
        \ <SID>check_back_space() ? "\<Tab>" :
        \ coc#refresh()
    inoremap <expr><S-TAB> coc#pum#visible() ? coc#pum#prev(1) : "\<C-h>"
    inoremap <silent><expr> <c-space> coc#refresh()

    hi CocSearch ctermfg=12 guifg=#18A3FF
    hi CocMenuSel ctermbg=109 guibg=#13354A
" }}}
