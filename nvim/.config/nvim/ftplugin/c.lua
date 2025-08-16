vim.opt_local.makeprg = "gcc -ggdb -o gen_state gen_state.c -Wall"
vim.keymap.set('n', '<leader>m', ':wa<CR>:make<CR>:copen<CR>')
vim.keymap.set('n', '<leader>n', ':cnext<CR>')
vim.keymap.set('n', '<leader>c', ':cclose<CR>')
vim.keymap.set('n', '<leader>e', ':edit ~/.config/nvim/ftplugin/c.lua<CR>')


