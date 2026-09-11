" 1. 插件管理
call plug#begin('~/.vim/plugged')
Plug 'preservim/nerdtree'                        " 文件树插件
Plug 'dag/vim-fish'                              " Fish 脚本支持
Plug 'neoclide/coc.nvim', {'branch': 'release'}  " 自动补全
Plug 'tpope/vim-fugitive'                        " Git 集成
Plug 'Chiel92/vim-autoformat'                    " 自动格式化
Plug 'honza/vim-snippets'                        " 代码片段
Plug 'SirVer/ultisnips'                          " 动态片段引擎
Plug 'morhetz/gruvbox'                           " Gruvbox 主题
call plug#end()

" 2. 系统与编码设置
set encoding=utf-8
set fileencodings=utf-8,gbk,gb18030
set termencoding=utf-8
set number                                       " 显示行号
set relativenumber                               " 显示相对行号
set tabstop=2                                    " Tab 宽度
set shiftwidth=2                                 " 缩进宽度
set expandtab                                    " Tab 转空格
set softtabstop=2
set autoindent
set smartindent
set cursorline                                   " 高亮当前行
set wrap
set showmatch
set matchtime=2
set incsearch
set ignorecase
set smartcase
set hlsearch
syntax on
set undofile                                     " 持久化撤销
set mouse=a                                      " 启用鼠标

" 容器环境兼容剪贴板处理 (无 GUI 时防报错)
if has('clipboard')
    set clipboard=unnamedplus
endif

" 3. 主题设置
set background=dark
colorscheme gruvbox                              " 使用 Gruvbox 主题

" 4. 快捷键
map <C-n> :NERDTreeToggle<CR>
map <C-s> :w<CR>
map <C-q> :q<CR>
map <C-w>v :vsplit<CR>
map <C-w>s :split<CR>

" 5. Fish Shell 专项配置 (仅在打开 .fish 文件时生效)
autocmd FileType fish compiler fish
autocmd FileType fish setlocal textwidth=79 foldmethod=expr foldlevelstart=1 foldminlines=1

if &shell =~# 'fish$'
    set shell=sh
endif

" 6. 持久化撤销目录
silent !mkdir -p ~/.cache/vim/undo
set undodir=~/.cache/vim/undo
