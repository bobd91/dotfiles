vim.cmd([[
    filetype on
    syntax on
    set number
    set cursorline
    set shiftwidth=4
    set tabstop=4
    set expandtab
    set nobackup
    set nowrap
    set incsearch
    set smartcase
    set showcmd
    set showmode
    set showmatch
]])
require("config.lazy")
