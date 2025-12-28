#!/bin/bash

echo ">>> 开始部署 Vim 配置..."

# 1. 下载 vim-plug (使用 -k 跳过 SSL 验证，防止国内网络报错)
echo "1. 正在安装 vim-plug..."
curl -fLo ~/.vim/autoload/plug.vim --create-dirs -k https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

# 2. 写入 .vimrc 配置
echo "2. 正在生成 ~/.vimrc 配置文件..."
cat << 'EOF' > ~/.vimrc
" ====================================================================
" 1. 插件清单 (自动下载，无需手动放 colors 文件)
" ====================================================================
call plug#begin('~/.vim/plugged')

    " --- 主题：GitHub Dark (像素级还原 VSCode 风格) ---
    Plug 'tomasiser/vim-code-dark'

    " --- 底部状态栏美化 ---
    Plug 'vim-airline/vim-airline'
    Plug 'vim-airline/vim-airline-themes'

    " --- 文件图标 (需安装 Nerd Font 字体) ---
    Plug 'ryanoasis/vim-devicons'

    " --- 功能增强 ---
    Plug 'junegunn/fzf', { 'do': { -> fzf#install() } } " 模糊搜索核心
    Plug 'junegunn/fzf.vim'                             " FZF 插件版
    Plug 'preservim/nerdtree'                           " 左侧文件树
    Plug 'psliwka/vim-smoothie'                         " 平滑滚动特效

    " --- 核心高亮 (支持几百种语言) ---
    Plug 'sheerun/vim-polyglot'

call plug#end()

" ====================================================================
" 2. 核心设置
" ====================================================================
" 基础
set noerrorbells
set novisualbell
set nocompatible
set number
syntax on
set cursorline              " 高亮当前行
set wrap                    " 自动换行
set scrolloff=5             " 滚动保留空间
set termguicolors           " 开启真彩色 (对 GitHub Dark 很重要)
set encoding=utf-8
set hidden

" 缩进
set tabstop=4
set shiftwidth=4
set expandtab
set autoindent

" 搜索体验
set hlsearch
set incsearch
set ignorecase smartcase

" 剪贴板 (Ctrl+C / Ctrl+X)
vmap <C-c> "+y
vmap <C-x> "+d

" ====================================================================
" 3. 主题设置 (直接调用插件，无需本地文件)
" ====================================================================
try
    " 设置背景为暗色
    set background=dark
    " 启用 GitHub Dark 主题
    colorscheme codedark
    
    " 让 airline 状态栏也匹配该主题
    let g:airline_theme = 'codedark'
catch
    " 防止插件还没下载时报错
endtry

" ====================================================================
" 4. 快捷键 (现代化习惯)
" ====================================================================
let mapleader=" "

" [Ctrl+f] 搜索文本 (类似 VSCode/浏览器)
nnoremap <C-f> /
inoremap <C-f> <Esc>/

" [Ctrl+n] 打开/关闭左侧文件树
nnoremap <C-n> :NERDTreeToggle<CR>

" [Ctrl+p] 全局搜索文件 (FZF)
nnoremap <C-p> :Files<CR>
EOF

echo "========================================================"
echo "✅ 配置部署完成！(Setup Done)"
echo "--------------------------------------------------------"
echo "请立即执行以下最后一步："
echo "1. 在终端输入: vim"
echo "2. 进入 vim 后，输入命令: :PlugInstall"
echo "3. 等待所有插件显示 Done 后，重启 vim 即可生效。"
echo "========================================================"
