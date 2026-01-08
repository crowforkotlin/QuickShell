#!/bin/bash

echo ">>> 开始部署全能型 Vim 配置 (Gruvbox + 智能文件识别)..."

# 1. 下载 vim-plug
if [ ! -f ~/.vim/autoload/plug.vim ]; then
    echo "1. 下载插件管理器..."
    curl -fLo ~/.vim/autoload/plug.vim --create-dirs -k https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
else
    echo "1. 插件管理器已存在。"
fi

# 2. 写入 .vimrc
echo "2. 生成配置文件 (已增加 KDL/Niri 支持)..."
cat << 'EOF' > ~/.vimrc
" ====================================================================
" 0. 自动安装插件
" ====================================================================
if empty(glob('~/.vim/plugged'))
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin('~/.vim/plugged')
    " 兼容性最强的主题
    Plug 'morhetz/gruvbox'
    " 状态栏
    Plug 'vim-airline/vim-airline'
    Plug 'vim-airline/vim-airline-themes'
    " 文件树
    Plug 'preservim/nerdtree'
    " 模糊搜索
    Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
    Plug 'junegunn/fzf.vim'
    
    " 【核心】语法高亮包 (包含 KDL, Rust, Go, Python 等几百种语言)
    Plug 'sheerun/vim-polyglot'
call plug#end()

" ====================================================================
" 1. 核心显示设置
" ====================================================================
set nocompatible
syntax on
filetype plugin indent on  " 必须开启
set t_Co=256               " 强制 256 色，修复颜色丢失
set number
set cursorline
set wrap
set encoding=utf-8
set mouse=a                " 允许鼠标点击

" ====================================================================
" 2. 自定义文件类型识别 (这里解决你的无颜色问题)
" ====================================================================
augroup CustomFiletypes
    autocmd!
    
    " --- Niri Window Manager (KDL 格式) ---
    " 识别后缀为 .kdl 的文件
    autocmd BufNewFile,BufRead *.kdl set filetype=kdl
    " 识别位于 niri 目录下名为 config 的无后缀文件
    autocmd BufNewFile,BufRead */niri/config set filetype=kdl

    " --- 其他 Linux 桌面常用配置扩充 ---
    " Waybar (通常是 JSON，但支持注释)
    autocmd BufNewFile,BufRead config.jsonc,*/waybar/config set filetype=jsonc
    " Rofi (语法类似 CSS)
    autocmd BufNewFile,BufRead *.rasi set filetype=css
    " Hyprland (自定义 Conf)
    autocmd BufNewFile,BufRead hyprland.conf set filetype=hyprlang
    " Tmux
    autocmd BufNewFile,BufRead .tmux.conf set filetype=tmux
    " Sway / I3
    autocmd BufNewFile,BufRead */sway/config,*/i3/config set filetype=i3config
augroup END

" ====================================================================
" 3. 主题设置
" ====================================================================
try
    set background=dark
    let g:gruvbox_contrast_dark = 'hard'  "以此获得更鲜明的对比度
    colorscheme gruvbox
    let g:airline_theme = 'gruvbox'
catch
    colorscheme desert
endtry

" ====================================================================
" 4. 快捷键
" ====================================================================
let mapleader=" "
nnoremap <C-f> /
inoremap <C-f> <Esc>/
nnoremap <C-n> :NERDTreeToggle<CR>
nnoremap <C-p> :Files<CR>
vmap <C-c> "+y
vmap <C-x> "+d

" --- 正常模式 (Normal Mode) ---
" 向下移动一行
nnoremap <A-Down> :m .+1<CR>==
" 向上移动一行
nnoremap <A-Up> :m .-2<CR>==

" --- 插入模式 (Insert Mode) ---
" 向下移动一行
inoremap <A-Down> <Esc>:m .+1<CR>==gi
" 向上移动一行
inoremap <A-Up> <Esc>:m .-2<CR>==gi

" --- 可视模式 (Visual Mode) ---
" 选中的代码块向下移动
vnoremap <A-Down> :m '>+1<CR>gv=gv
" 选中的代码块向上移动
vnoremap <A-Up> :m '<-2<CR>gv=gv

EOF

echo "========================================================"
echo "✅ 部署完成！"
echo "--------------------------------------------------------"
echo "已添加对以下文件的自动颜色支持："
echo "1. Niri 配置 (*.kdl, niri/config)"
echo "2. Waybar, Rofi, Sway 等常用 Linux 配置文件"
echo "========================================================"
