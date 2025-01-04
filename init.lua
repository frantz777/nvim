-- Basic settings
vim.opt.hlsearch = true
vim.opt.number = true
vim.opt.syntax = "on"
vim.opt.relativenumber = true
vim.opt.mouse = "a"
--vim.opt.path:append "**"
vim.opt.wildmenu = true
vim.g.mapleader = " "
-- use nvim-tree instead
vim.o.grepprg = 'grep -HRin $* .'
vim.keymap.set('n','<Leader>gg',':copen | :silent :grep ')

-- Use system clipboard
vim.opt.clipboard:append({ "unnamed", "unnamedplus" })

vim.opt.scrolloff = 10					-- scroll page when cursor is 8 lines from top/bottom
vim.opt.sidescrolloff = 10				-- scroll page when cursor is 8 spaces from left/right
-- scroll a bit extra horizontally and vertically when at the end/bottom
vim.opt.cursorline = true
vim.opt.wrap = false


vim.opt.swapfile = false 
-- Persist undo
vim.opt.undofile = true

-- Tab stuff
vim.opt.tabstop = 4 
vim.opt.shiftwidth = 4
vim.opt.expandtab = true 
vim.opt.autoindent = true

-- Search configuration
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.gdefault = true

-- scroll a bit extra horizontally and vertically when at the end/bottom
vim.opt.sidescrolloff = 8
vim.opt.scrolloff = 8

-- Move between windows using hjkl
--vim.keymap.set('n', 'h', '<C-w>h', { noremap = true, silent = true })
--vim.keymap.set('n', 'j', '<C-w>j', { noremap = true, silent = true })
--vim.keymap.set('n', 'k', '<C-w>k', { noremap = true, silent = true })
--vim.keymap.set('n', 'l', '<C-w>l', { noremap = true, silent = true })

-- open new split panes to right and below (as you probably expect)
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.api.nvim_set_keymap('n', '-', '$', { noremap = true, silent = true })
vim.api.nvim_set_keymap('v', '-', '$', { noremap = true, silent = true })
-- Save current file and execute :luafile %
vim.api.nvim_set_keymap('n', '<Leader>l', ':w<CR>:luafile %<CR>', { noremap = true, silent = true })
script_dir = '/home/zoro/.config/nvim/?.lua'
package.path = package.path .. ";" .. script_dir 
 
require('buffer')
require('fileFinder')

-- Simple function to attach LSP
local function on_attach(client, bufnr)
    -- Example keymap
    vim.api.nvim_buf_set_keymap(bufnr, 'n', 'gd', '<cmd>lua vim.lsp.buf.definition()<CR>', { noremap=true, silent=true })
end

-- Start clangd for C++ files
local function start_cpp_lsp()
    local clangd_path = vim.fn.exepath("clangd")
    if clangd_path ~= "" then
        vim.lsp.start({
            name = "clangd",
            cmd = { clangd_path },
            on_attach = on_attach,
        })
    else
        print("clangd is not installed or not in your PATH")
    end
end

-- Start python lsp for py files
local function start_py_lsp()
    local pyLsp_path = vim.fn.exepath("/home/zoro/myPythonLsp/bin/python3.12")
    if pyLsp_path ~= "" then
        vim.lsp.start({
            name = "pylsp",
            cmd = { pyLsp_path },
            on_attach = on_attach,
        })
    else
        print("pylsp is not installed or not in your PATH")
    end
end


-- Autocommand for C++ files
vim.api.nvim_create_autocmd("FileType", {
    pattern = "cpp",
    callback = start_cpp_lsp,})

-- Autocommand for Python files
vim.api.nvim_create_autocmd("FileType", {
    pattern = "py",
    callback = start_py_lsp,})

