#!/bin/bash

echo ">>> 开始部署兼容性最强的 Vim 配置 (Gruvbox 版)..."

# 1. 下载 vim-plug
if [ ! -f ~/.vim/autoload/plug.vim ]; then
    echo "1. 下载插件管理器..."
    curl -fLo ~/.vim/autoload/plug.vim --create-dirs -k https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi

# 2. 写入 .vimrc
echo "2. 生成配置文件..."
cat << 'EOF' > ~/.vimrc
" ====================================================================
" 0. 自动安装插件
" ====================================================================
if empty(glob('~/.vim/plugged'))
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin('~/.vim/plugged')
    " --- 换用 Gruvbox 主题 (兼容性最强，看着舒服) ---
    Plug 'morhetz/gruvbox'
    
    " --- 状态栏 ---
    Plug 'vim-airline/vim-airline'
    Plug 'vim-airline/vim-airline-themes'
    
    " --- 功能区 ---
    Plug 'preservim/nerdtree'
    Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
    Plug 'junegunn/fzf.vim'
    
    " --- 语法高亮增强 ---
    Plug 'sheerun/vim-polyglot'
call plug#end()

" ====================================================================
" 核心显示设置 (关键修改)
" ====================================================================
set nocompatible
syntax on
filetype plugin indent on  " 必须开启，否则无法识别文件类型导致无颜色

" 关掉 termguicolors，改用传统的 256 色模式
" 这样可以保证在任何终端（Xshell/Putty/CMD）都有颜色
set t_Co=256 

set number
set cursorline
set wrap
set encoding=utf-8

" ====================================================================
" 主题设置
" ====================================================================
try
    set background=dark
    
    " 设置 Gruvbox 的对比度为硬朗模式，颜色更鲜艳
    let g:gruvbox_contrast_dark = 'hard'
    
    " 加载主题
    colorscheme gruvbox
    let g:airline_theme = 'gruvbox'
catch
    " 即使插件还没好，也强制用内置主题兜底
    colorscheme desert
endtry

" ====================================================================
" 快捷键
" ====================================================================
let mapleader=" "
nnoremap <C-f> /
inoremap <C-f> <Esc>/
nnoremap <C-n> :NERDTreeToggle<CR>
nnoremap <C-p> :Files<CR>
vmap <C-c> "+y
vmap <C-x> "+d

EOF

echo "========================================================"
echo "✅ 部署完成 (兼容版)"
echo "--------------------------------------------------------"
echo "这个版本去掉了会导致颜色丢失的 '真彩色' 强制开关，"
echo "并换用了对环境要求最低的 Gruvbox 主题。"
echo ""
echo "请输入: vim"
echo "等待底部插件安装进度条走完 (Done)，颜色就会立刻出来。"
echo "========================================================"