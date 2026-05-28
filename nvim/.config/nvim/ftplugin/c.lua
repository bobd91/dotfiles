vim.opt_local.makeprg = "gcc -ggdb -o %:p:r %:p"
vim.keymap.set('n', '<leader>m', ':wa<CR>:make<CR>:copen<CR>')
vim.keymap.set('n', '<leader>n', ':cnext<CR>')
vim.keymap.set('n', '<leader>c', ':cclose<CR>')
vim.keymap.set('n', '<leader>e', ':edit ~/.config/nvim/ftplugin/c.lua<CR>')


