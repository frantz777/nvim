local function create_popup_output(prompt, callback)
    -- Getting path of file to look for supporting files
	local script_dir = debug.getinfo(1, "S").source
    script_dir = script_dir:match("^(.*)[/\\]")
    script_dir = string.sub(script_dir,2)
    script_dir = script_dir .. "/?.lua"
    package.path = package.path .. ";" .. script_dir 
	local utils = require("utils")
 
    -- Define the popup window size and position
    local width = 80 -- width of window 
    local height = 8 -- height of window
    local row = math.floor(vim.o.lines / 2) - math.floor(height / 2)
    local col = math.floor(vim.o.columns / 2) - math.floor(width / 2)
    files = {''}

    -- start running command to write all filenames to tempt file  
    utils.run_find_async()

    -- Filter the file list based on the input in the second window
    local function update_file_list(input,file_buf)
        local file_list = {}

         -- Build the grep command
        local command = string.format("grep -i '%s' %s", input, "~/.fzfFile.txt")
        
        -- Run the command and capture the output
        local handle = io.popen(command)
        local result = handle:read("*a")
        handle:close()

        -- Store the matching lines in a Lua table
        local string_file_list = {}
        for line in result:gmatch("([^\n]*)\n?") do
            table.insert(string_file_list, line)
        end
        
        -- Update the buffer with the new file list in the first window
        vim.api.nvim_buf_set_option(file_buf, 'modifiable', true)  -- Make the file list buffer readonly
        vim.api.nvim_buf_set_lines(file_buf, 0, -1, false, string_file_list)
        vim.api.nvim_buf_set_option(file_buf, 'modifiable', false)  -- Make the file list buffer readonly
        return string_file_list
    end

    -- Variable to keep track of the currently highlighted file index
    local current_index = 1
    local highlight_ns = vim.api.nvim_create_namespace('file_highlight')  -- Unique namespace for highlighting
    local current_extmark = nil  -- To store the current highlight extmark


	-- Initalize list with first few files, quicker than loading whole list
    local function initializeList()
        local file_path = "~/.fzfFile.txt"
        local command = string.format("head -n %d %s", height, file_path)
        local handle = io.popen(command)  -- Run the command and capture the output
        local result = handle:read("*a")  -- Read all the output
        handle:close()

   		-- Split the result into lines and return as a table
        local lines_init = {}
        for line in result:gmatch("([^\n]*)\n?") do
            table.insert(lines_init, line)
        end

    	return lines_init
    end
	
    initFiles = initializeList()
    -- Initialize the file list with the first few files
    local file_list = {}
    
    local string_file_list = {''}
    for i = 1, math.min(8, #initFiles) do
        table.insert(file_list, initFiles[i])
    end

    -- Create buffers for the file list and input field
    local file_buf = vim.api.nvim_create_buf(false, true)  -- Buffer for the file list
    local input_buf = vim.api.nvim_create_buf(false, true)  -- Buffer for the input field
    local current_length = #file_list

    -- Open the first window (file list)
    local file_win = vim.api.nvim_open_win(file_buf, true, {
        relative = 'editor',
        width = width,
        height = height,  -- We add space for the input field
        row = row - 2,  -- Position the first window a bit higher
        col = col,
        style = 'minimal',
        border = 'rounded',
    })
    
    -- Open the second window (input field), positioned below the file list
    local input_win = vim.api.nvim_open_win(input_buf, true, {
        relative = 'editor',
        width = width,
        height = 1,
        row = row + height,  -- Position input window below the file list
        col = col,
        style = 'minimal',
        border = 'rounded',
    })

    -- Set the initial file list
    vim.api.nvim_buf_set_lines(file_buf, 0, -1, false, file_list)
    vim.api.nvim_buf_set_option(file_buf, 'modifiable', false)  -- Make the file list buffer readonly
    vim.api.nvim_buf_set_option(file_buf, 'bufhidden', 'delete')
    vim.cmd([[hi NormalFloat guibg=NONE]])

    -- Focus on the input buffer and set its options
    vim.api.nvim_buf_set_option(input_buf, 'buftype', 'prompt')
    vim.api.nvim_buf_set_option(input_buf, 'modifiable', true)
    vim.api.nvim_buf_set_option(input_buf, 'bufhidden', 'delete')
	vim.fn.prompt_setprompt(input_buf,'> ')
    vim.cmd('startinsert')  -- Start in insert mode 

    -- Use key mappings to capture input changes
    vim.api.nvim_buf_set_keymap(input_buf, 'i', '<Enter>', '', {
        noremap = true,
        callback = function()
            vim.api.nvim_win_close(file_win, true)
            vim.api.nvim_win_close(input_win, true)
            local selected_file = string_file_list[current_index]  -- Get the file at the highlighted line
            vim.cmd("edit " .. selected_file)  -- Open the file
            -- Optionally close the windows after opening the file
       end,
        silent = true,
    })
    -- Automatically trigger update on every keystroke in the input window
    vim.api.nvim_create_autocmd("TextChangedI", {
        buffer = input_buf,
        callback = function()            
            local input = vim.api.nvim_get_current_line()
            local trimmed_input = string.sub(input, 3) -- Trim leading/trailing whitespace
            string_file_list = update_file_list(trimmed_input,file_buf) 

            current_length = #string_file_list
            if vim.api.nvim_buf_line_count(file_buf) > 1 then
                current_extmark = utils.highlight_file(file_buf,0,current_extmark)  -- Highlight the new file
                current_index = 1
            end 

            if current_length > height then
                current_length = height
            end
        end,
    })   
    -- Close the popup when Esc is pressed
    vim.api.nvim_buf_set_keymap(input_buf, 'i', '<Esc>', '', {
        noremap = true,
        callback = function()
            vim.api.nvim_win_close(file_win, true)
            vim.api.nvim_win_close(input_win, true)
        end,
        silent = true,
    })
    -- Close the popup when Esc is pressed
    vim.api.nvim_buf_set_keymap(file_buf, 'i', '<Esc>', '', {
        noremap = true,
        callback = function()
            vim.api.nvim_win_close(file_win, true)
            vim.api.nvim_win_close(input_win, true)
        end,
        silent = true,
    })
    -- Arrow key navigation in the input window to highlight files in the file list
    vim.api.nvim_buf_set_keymap(input_buf, 'i', '<Down>', '', {
        noremap = true,
        callback = function()
            -- Move down in the file list if not at the bottom
            if current_index < current_length then
                current_index = current_index + 1
                current_extmark = utils.highlight_file(file_buf, current_index - 1,current_extmark)  -- Highlight the new file
            end
        end,
        silent = true,
    })
    vim.api.nvim_buf_set_keymap(input_buf, 'i', '<Up>', '', {
        noremap = true,
        callback = function()
            -- Move up in the file list if not at the top
            if current_index > 1 then
                current_index = current_index - 1
                current_extmark = utils.highlight_file(file_buf, current_index - 1,current_extmark)  -- Highlight the new file
            end
        end,
        silent = true,
    })
end

_G.create_popup_output = create_popup_output
-- Keybinding to trigger the fuzzy file finder (e.g., <leader>ff)
vim.api.nvim_set_keymap('n', '<leader>ff', ':lua create_popup_output()<CR>', { noremap = true, silent = true })
