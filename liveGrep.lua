local function live_grep()
 	local script_dir = debug.getinfo(1, "S").source
    script_dir = script_dir:match("^(.*)[/\\]")
    script_dir = string.sub(script_dir,2)
    script_dir = script_dir .. "/?.lua"
    package.path = package.path .. ";" .. script_dir 
	   
    local logger = require('logHelper')
    local move_selection
    local update_preview
    local close_all
    local run_grep_async
    vim.api.nvim_set_hl(0, "LiveGrepFilename", { fg = "#61afef", bold = true })
    vim.api.nvim_set_hl(0, "LiveGrepMatch", { bg = "#3e4452", fg = "#ffffff" })

    --logger.log('starting live_grep')

    --local SEARCH_ROOT = "/home/zoro/CPPStuff/"
    local SEARCH_ROOT = "."
    local width      = math.floor(vim.o.columns / 2) - 10
    local height     = vim.o.lines - 15
    local center_col = math.floor(vim.o.columns / 2)
    local row        = math.floor(vim.o.lines / 2) - math.floor(height / 2)

    MAX_LINES_TO_LOAD = 200
    FNAME_WIDTH = 35
    ENABLE_DEBUG = nil
    -- STATE
    results          = {}
    results.filename = {}
    results.line_num = {}
    results.text     = {}
        
    local current_index = 1
    local selection_ns = vim.api.nvim_create_namespace("live_grep_selection")
    local highlight_ns  = vim.api.nvim_create_namespace("live_grep_highlight")
    local highlight_prev_ns  = vim.api.nvim_create_namespace("live_grep_prev_highlight")
    local current_job   = nil

    -- CREATE BUFFERS
    local prev_buf   = vim.api.nvim_create_buf(false, true)
    local output_buf = vim.api.nvim_create_buf(false, true)
    local input_buf  = vim.api.nvim_create_buf(false, true)

    -- CREATE WINDOWS
    local prev_win = vim.api.nvim_open_win(prev_buf, true,
    { relative = "editor", width = width, height = height, row = row, col = center_col + 2, style = "minimal", border = "rounded", })

    local output_win = vim.api.nvim_open_win(output_buf, true, 
    { relative = "editor", width = width, height = height, row = row, col = center_col - width, style = "minimal", border = "rounded", })

    local input_win = vim.api.nvim_open_win(input_buf, true, 
    { relative = "editor", width = width * 2 + 2, height = 1, row = row - 3, col = center_col - width, style = "minimal", border = "rounded", })

    -- BUFFER SETTINGS
    vim.api.nvim_buf_set_option(output_buf, "modifiable", false)
    vim.api.nvim_buf_set_option(output_buf, "bufhidden", "wipe")
    vim.wo[output_win].wrap = false

    vim.api.nvim_buf_set_option(prev_buf, "modifiable", false)
    vim.api.nvim_buf_set_option(prev_buf, "bufhidden", "wipe")

    vim.api.nvim_buf_set_option(input_buf, "buftype", "prompt")
    vim.api.nvim_buf_set_option(input_buf, "bufhidden", "wipe")

    vim.fn.prompt_setprompt(input_buf, "> ")
    vim.cmd("startinsert")
    vim.cmd([[hi NormalFloat guibg=NONE]])
   
    -- INPUT AUTOCMD
    vim.api.nvim_create_autocmd("TextChangedI", {
        buffer = input_buf,
        callback = function()
            local input = vim.api.nvim_get_current_line()
            local query = input:sub(3)
            run_grep_async(query)

            if #results.filename > 0 then
                move_selection(0)
            end
        end, })

    -- KEYMAPS
    vim.keymap.set("n", "<Esc>", function() close_all() end, { buffer = output_buf })
    vim.keymap.set("i", "<Esc>", function() close_all() end, { buffer = input_buf })

    vim.keymap.set("n", "<Down>", function() move_selection(1) end, { buffer = output_buf })
    vim.keymap.set("n", "<Up>", function() move_selection(-1)  end, { buffer = output_buf })

    vim.keymap.set({"n","i"}, "<Down>", function() move_selection(1) end, { buffer = input_buf })
    vim.keymap.set({"n","i"}, "<Up>", function() move_selection(-1)  end, { buffer = input_buf })

    vim.keymap.set({"n","i"}, "<C-j>", function() move_selection(1)  end, { buffer = input_buf })
    vim.keymap.set({"n","i"}, "<C-k>", function() move_selection(-1) end, { buffer = input_buf })

    vim.keymap.set("i", "<Enter>", function()
        if #results.filename == 0 then return end
        local fname = results.filename[current_index]
        local lnum = results.line_num[current_index]
        close_all()
        vim.cmd("edit " .. fname)
        vim.api.nvim_win_set_cursor(0, { lnum, 0 })
    end, { buffer = input_buf })

    -- CLOSE FUNCTION
    close_all = function()
        if vim.api.nvim_win_is_valid(prev_win) then
            vim.api.nvim_win_close(prev_win, true)
        end
        if vim.api.nvim_win_is_valid(output_win) then
            vim.api.nvim_win_close(output_win, true)
        end
        if vim.api.nvim_win_is_valid(input_win) then
            vim.api.nvim_win_close(input_win, true)
        end
    end
    move_selection = function(delta)

        if #results.filename == 0 then return end

        current_index = current_index + delta

        if current_index < 1 then
            current_index = 1
        elseif current_index > #results.filename then
            current_index = #results.filename
        end

        -- ONLY clear selection highlight (NOT all highlights)
        vim.api.nvim_buf_clear_namespace(output_buf, selection_ns, 0, -1)

        -- highlight current line
        vim.api.nvim_buf_add_highlight( output_buf, selection_ns, "Visual", current_index - 1, 0, -1)
        if ENABLE_DEBUG then
            logger.log("seting cursor 134, current_index: " .. current_index)
        end

        -- move cursor to selected line
        vim.api.nvim_win_set_cursor(output_win, { current_index, 0 })

        update_preview()
    end

    -- UPDATE PREVIEW
    update_preview = function()
        if #results.line_num == 0 then return end

        local fname = results.filename[current_index]
        local lnum  = results.line_num[current_index]
        local success, lines = pcall(vim.fn.readfile,fname)
        if not success then
            return 
        end

        vim.api.nvim_buf_set_option(prev_buf, "modifiable", true)
        vim.api.nvim_buf_set_lines(prev_buf, 0, -1, false, lines)
        vim.api.nvim_buf_set_option(prev_buf, "modifiable", false)

        -- Detect and set filetype
        local ft = vim.filetype.match({ filename = fname })
        if ft then
            vim.bo[prev_buf].filetype = ft
        end
        vim.api.nvim_buf_clear_namespace(prev_buf, highlight_prev_ns, 0, -1)
        vim.api.nvim_buf_add_highlight(prev_buf,highlight_prev_ns,"Visual",lnum-1,0,-1)

        if ENABLE_DEBUG then
            logger.log("setting lnum: ".. lnum)
        end
        vim.api.nvim_win_set_cursor(prev_win, {lnum , 0})
        vim.api.nvim_win_set_option(prev_win, 'winbar', fname)


    end

    run_grep_async = function(query)
        -- clear old results
        results = {}
        results.filename= {}
        results.line_num = {}
        results.text = {}
        
        if query == "" then
            vim.api.nvim_buf_set_option(output_buf, "modifiable", true)
            vim.api.nvim_buf_set_lines(output_buf, 0, -1, false, {})
            vim.api.nvim_buf_set_option(output_buf, "modifiable", false)
            return
        end

        -- Kill previous job if still running
        if current_job then
            vim.fn.jobstop(current_job)
            current_job = nil
        end
        if ENABLE_DEBUG then
            logger.log('#######################################################################')
            logger.log('########################### Starting new Grep #########################')
            logger.log('#######################################################################')
        end
        vim.api.nvim_buf_set_option(output_buf, "modifiable", true)
        vim.api.nvim_buf_set_lines(output_buf, 0, -1, false, {})

        local cmd = { "grep", "-HRsiIn" , "-m 10", "--exclude-dir=.local", "--exclude-dir=.cache","--exclude=*.log", query, SEARCH_ROOT, }
        local stdout_data = {}
        if ENABLE_DEBUG then 
            logger.log("###CMD###: " ..table.concat(cmd),',')
        end
        local line_insert = -1 
        current_job = vim.fn.jobstart(cmd, { stdout_buffered = false,
            on_stderr = function(job_id, data, event)
                if ENABLE_DEBUG then
                    logger.log("stderr: " .. data[1] )--table.concat(data,'\n'))
                end
            end,
            --]]--
            on_stdout = function(_, data)
                if not data then
                    return 
                end

                vim.schedule(function()

                    local win_width = vim.api.nvim_win_get_width(output_win) 
                    for _, line in ipairs(data) do

                        if ENABLE_DEBUG then
                            logger.log("Line in data: " .. line)
                        end
                        if line ~= "" then
                            -- parse + append ONE LINE at a time
                            local filename, lnum, text = line:match("^(.-):(%d+):(.*)$")

                            if filename then
                                local short = vim.fn.fnamemodify(filename, ":.")

                                -- clamp filename width
                                if #short > FNAME_WIDTH  then
                                    short = "…" .. short:sub(#short - FNAME_WIDTH + 2)
                                end

                                local line_display = string.format(
                                    "%-" .. FNAME_WIDTH .. "s %4d | %s",
                                    short,
                                    lnum,
                                    text
                                )
                                table.insert(results.filename, filename)
                                table.insert(results.line_num, tonumber(lnum))
                                table.insert(results.text, line_display)                     

                                if #results.filename > MAX_LINES_TO_LOAD then 
                                    if current_job then
                                        vim.fn.jobstop(current_job)
                                        current_job = nil
                                    end
                                    break
                                end
                            end
                        end
                    end
                    if ENABLE_DEBUG then
                        for idx, line in ipairs(results.text) do
                            logger.log("results.text: " .. line .. " results.line_num: " .. results.line_num[idx] )
                        end
                    end
                    vim.api.nvim_buf_set_option(output_buf, "modifiable", true)
                    vim.api.nvim_buf_set_lines(output_buf, 0, -1, false, results.text)
                    vim.api.nvim_buf_clear_namespace(output_buf, highlight_ns, 0, -1)
                    
                    if ENABLE_DEBUG then
                        logger.log("added 262 #results.text: " .. #results.text) 
                    end
                    for i = 1, #results.text do
                        local line = results.text[i]
                        local fname = results.filename[i]
                        local lnum  = results.line_num[i]

                        local short = vim.fn.fnamemodify(fname, ":.")
                        --local prefix = string.format("%s:%d | ", short, lnum)
                        local prefix = string.format( "%-" .. FNAME_WIDTH .. "s %4d | ", short, lnum)

                        -- highlight filename
                        vim.api.nvim_buf_add_highlight( output_buf, highlight_ns, "LiveGrepFilename", i - 1, 0, #short)

                        -- highlight match (plain search)
                        local text_part = line:sub(#prefix + 1)
                        local start_col = text_part:lower():find(query:lower(), 1, true)

                        if start_col then
                            local start = #prefix + start_col - 1
                            local finish = start + #query
                            vim.api.nvim_buf_add_highlight( output_buf, highlight_ns, "LiveGrepMatch", i - 1, start, finish)
                        end
                    end
                    vim.api.nvim_buf_set_option(output_buf, "modifiable", false)
                    move_selection(0)

                end)
            end
        })
    end

end

_G.live_grep = live_grep
vim.keymap.set("n", "<leader>lg", live_grep,{ noremap = true, silent = true })
