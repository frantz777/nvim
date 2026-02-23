local function create_live_grep()

    local move_selection
    local update_preview
    local close_all
    local run_grep_async

    --local SEARCH_ROOT = "/home/zoro/CPPStuff/"
    local SEARCH_ROOT = "."
    local width  = math.floor(vim.o.columns / 2) - 10
    local height = vim.o.lines - 15
    local center_col = math.floor(vim.o.columns / 2)
    local row = math.floor(vim.o.lines / 2) - math.floor(height / 2)

    -- STATE
    local results = {}
    local current_index = 1
    local highlight_ns = vim.api.nvim_create_namespace("live_grep_highlight")
    local current_job = nil

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
            --results, display_lines = update_results(query)
            current_index = 1

            -- Clear old highlights
            vim.api.nvim_buf_clear_namespace(output_buf, highlight_ns, 0, -1)

           if #results > 0 then
                move_selection(0)
            end
        end, })

    -- KEYMAPS
    vim.keymap.set("n", "<Esc>", function() close_all() end, { buffer = output_buf })
    vim.keymap.set("i", "<Esc>", function() close_all() end, { buffer = input_buf })

    vim.keymap.set("n", "<Down>", function() move_selection(1) end, { buffer = output_buf })
    vim.keymap.set("n", "<Up>", function() move_selection(-1) end, { buffer = output_buf })

    vim.keymap.set({"n","i"}, "<Down>", function() move_selection(1) end, { buffer = input_buf })
    vim.keymap.set({"n","i"}, "<Up>", function() move_selection(-1) end, { buffer = input_buf })

    vim.keymap.set({"n","i"}, "<C-j>", function() move_selection(1) end, { buffer = input_buf })
    vim.keymap.set({"n","i"}, "<C-k>", function() move_selection(-1) end, { buffer = input_buf })

    vim.keymap.set("i", "<Enter>", function()
        if #results == 0 then return end
        local entry = results[current_index]
        close_all()
        vim.cmd("edit " .. entry.filename)
        vim.api.nvim_win_set_cursor(0, { entry.lnum, 0 })
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

    -- MOVE SELECTION
    move_selection = function(delta)
        if #results == 0 then return end

        current_index = current_index + delta
        if current_index < 1 then
            current_index = 1
        elseif current_index > #results then
            current_index = #results
        end

        vim.api.nvim_buf_clear_namespace(output_buf, highlight_ns, 0, -1)
        vim.api.nvim_buf_add_highlight( output_buf,highlight_ns,"Visual",current_index - 1,0,-1)
        vim.api.nvim_win_set_cursor(output_win, { current_index, 0 })

        update_preview()
    end

    -- UPDATE PREVIEW
    update_preview = function()
        if #results == 0 then return end

        local entry = results[current_index]
        local lines = vim.fn.readfile(entry.filename)

        vim.api.nvim_buf_set_option(prev_buf, "modifiable", true)
        vim.api.nvim_buf_set_lines(prev_buf, 0, -1, false, lines)
        vim.api.nvim_buf_set_option(prev_buf, "modifiable", false)

        -- Detect and set filetype
        local ft = vim.filetype.match({ filename = entry.filename })
        if ft then
            vim.bo[prev_buf].filetype = ft
        end
        vim.api.nvim_win_set_cursor(prev_win, { entry.lnum, 0 })
    end

    run_grep_async = function(query)
        if query == "" then
            results = {}
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

        local cmd = { "grep", "-HRsiIn", "--exclude-dir", ".cache", query, SEARCH_ROOT, }
        local stdout_data = {}

        current_job = vim.fn.jobstart(cmd, { stdout_buffered = true,
            on_stdout = function(_, data)
                if data then
                    for _, line in ipairs(data) do
                        if line ~= "" then
                            table.insert(stdout_data, line)
                        end
                    end
                end
            end,

            on_exit = function()
                local parsed = {} local display = {}

                for _, line in ipairs(stdout_data) do
                    local filename, lnum, text =
                        line:match("^(.-):(%d+):(.*)$")

                    if filename and lnum and text then
                        lnum = tonumber(lnum)
                        table.insert(parsed, { filename = filename, lnum = lnum, text = text, })
                        local line_display = string.format("%s:%d:%s", filename, lnum, text)

                        if #line_display > width then
                            line_display = string.sub(line_display, #line_display - width + 2)
                        end

                        table.insert(display, line_display)
                    end
                end

                vim.schedule(function()
                    results = parsed
                    current_index = 1
                    if output_buf == nil then 
                        return
                    end
                    vim.api.nvim_buf_set_option(output_buf, "modifiable", true)
                    vim.api.nvim_buf_set_lines(output_buf, 0, -1, false, display)
                    vim.api.nvim_buf_set_option(output_buf, "modifiable", false)
                    vim.api.nvim_buf_clear_namespace(output_buf, highlight_ns, 0, -1)

                    if #results > 0 then
                        move_selection(0)
                    end
                end)
            end,
        })
    end
end

_G.create_live_grep = create_live_grep
vim.keymap.set("n", "<leader>lg", create_live_grep,{ noremap = true, silent = true })
