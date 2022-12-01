set rtp+=.
set rtp+=../plenary.nvim

lua vim.g.grapple_testing = true

runtime! plugin/plenary.vim
runtime! plugin/grapple.vim
