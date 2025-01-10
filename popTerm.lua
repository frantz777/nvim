function popup_terminal()

 -- Define the popup window size and position
    local width = vim.o.columns - 4 -- width of window 
    local height = 20 -- height of window
    local row = vim.o.lines - (height/2) 
    local col = math.floor(vim.o.columns / 2) - math.floor(width / 2)

    -- Create a floating window for the terminal
    local opts = {
        relative = 'editor',           -- Use the editor as the reference for positioning
        width    = width,           -- Width of the floating window
        height = height,         -- Height of the floating window
        col = col,               -- Column position of the window
        row = row,               -- Row position of the window
        anchor = 'NW',                 -- Anchor the window at the top-left
        style = 'minimal',             -- Make it minimal, no borders or UI elements
        border = 'rounded',            -- Optional: give the window rounded borders
    }
    
    -- Open the floating window
    local buf = vim.api.nvim_create_buf(false, true)  -- Create a new buffer (no name, no file)
    local win = vim.api.nvim_open_win(buf, true, opts)  -- Open the buffer in a floating window

    vim.api.nvim_buf_set_option(buf, 'modifiable', false)  -- Make the file list buffer readonly
    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'delete')
    vim.cmd([[hi NormalFloat guibg=NONE]])

    -- Run the terminal inside the window
    vim.api.nvim_command('term')  -- Launch a terminal inside the window
    vim.cmd('startinsert')  -- Start in insert mode 
    
    -- Close the popup when Esc is pressed (for terminal mode)
    vim.api.nvim_buf_set_keymap(buf, 't', '<Esc>', [[<C-\><C-n>:q<CR>]], {
        noremap = true,
        silent = true,
    })
    -- Close the popup when Esc is pressed (for terminal mode)
    vim.api.nvim_buf_set_keymap(buf, 't', '<Leader>tt', [[<C-\><C-n>:q<CR>]], {
        noremap = true,
        silent = true,
    })

end

vim.api.nvim_set_keymap('n', '<leader>tt', ':lua popup_terminal()<CR>', { noremap = true, silent = true })
