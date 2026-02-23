function create_buffer_window(prompt, callback)
    -- Getting path of file to look for supporting files
	local utils = require("utils")
 
    -- Define the popup window size and position
    local width = math.floor(vim.o.columns) - 6
    local height = 10
    local row = math.floor(vim.o.lines / 2) - math.floor(height / 2)
    local col = math.floor(vim.o.columns / 2) - math.floor(width / 2)
    
    local file_buf = vim.api.nvim_create_buf(false, true)  -- Buffer for the file list

    local current_extmark = nil  -- To store the current highlight extmark

    -- Variable to keep track of the currently highlighted ile index
    local current_index = 1
    
    buffer_list = vim.api.nvim_list_bufs()
	buffer_list, file_names = utils.get_filenames_from_buffers(buffer_list)

    current_length = math.max(height, #file_names)
	
    -- Open the first window (file list)
    local file_win = vim.api.nvim_open_win(file_buf, true, {
        relative = 'editor',
        width = width,
        height = height,  
        row = row,
        col = col,
        style = 'minimal',
        border = 'rounded',
    })
    
   -- vim.wo[file_win].number = true 
    vim.api.nvim_buf_set_lines(file_buf, 0, -1, false, file_names)
    vim.api.nvim_buf_set_option(file_buf, 'modifiable', false)  -- Make the file list buffer readonly
    vim.cmd([[hi NormalFloat guibg=NONE]])

    -- Close the popup when Esc is pressed
    vim.api.nvim_buf_set_keymap(file_buf, 'n', '<Esc>', '', {
        noremap = true,
        callback = function()
            vim.api.nvim_win_close(file_win, true)
        end,
        silent = true,
    })
    vim.api.nvim_buf_set_keymap(file_buf, 'n', '<Down>', '', {
        noremap = true,
        callback = function()
            -- Move down in the file list if not at the bottom
            if current_index < #file_names then
                current_index = current_index + 1
                vim.api.nvim_win_set_cursor(file_win,{current_index,0})
                current_extmark = utils.highlight_file(file_buf, current_index -1,current_extmark)  -- Highlight the new file
            end
        end,
        silent = true,
    })
    vim.api.nvim_buf_set_keymap(file_buf, 'n', '<Up>', '', {
        noremap = true,
        callback = function()
            -- Move up in the file list if not at the top
            if current_index > 1 then
                current_index = current_index - 1
                vim.api.nvim_win_set_cursor(file_win,{current_index,0})
                current_extmark = utils.highlight_file(file_buf, current_index -1,current_extmark)  -- Highlight the new file
            end
        end,
        silent = true,
    })

    vim.api.nvim_buf_set_keymap(file_buf, 'n', 'j', '', {
        noremap = true,
        callback = function()
            -- Move down in the file list if not at the bottom
            if current_index < #file_names then
                current_index = current_index + 1
                vim.api.nvim_win_set_cursor(file_win,{current_index,0})
                current_extmark = utils.highlight_file(file_buf, current_index -1,current_extmark)  -- Highlight the new file
            end
        end,
        silent = true,
    })
    vim.api.nvim_buf_set_keymap(file_buf, 'n', 'k', '', {
        noremap = true,
        callback = function()
            -- Move up in the file list if not at the top
            if current_index > 1 then
                current_index = current_index - 1
                vim.api.nvim_win_set_cursor(file_win,{current_index,0})
                current_extmark = utils.highlight_file(file_buf, current_index -1,current_extmark)  -- Highlight the new file
            end
        end,
        silent = true,
    })
    vim.api.nvim_buf_set_keymap(file_buf, 'n', '<Enter>', '', {
        noremap = true,
        callback = function()
            vim.api.nvim_win_close(file_win, true)
            local index = buffer_list[current_index]  -- Get the file at the highlighted line

            if index then
                print("Selected File by buf idx: " .. vim.api.nvim_buf_get_name(index))
                vim.api.nvim_set_current_buf(index)
            end
           -- utils.switch_buffer(buffer_list,index)
            --vim.cmd("edit " .. selected_file)  -- Open the file
       end,
        silent = true,
    })
end 

vim.api.nvim_set_keymap('n', '<leader>bb', ':lua create_buffer_window()<CR>', { noremap = true, silent = true })
