local M = {}

-- Function to update the visual highlight
function M.highlight_file(buf, line_number,current_extmark)
	-- Remove the previous highlight (if any)
    local highlight_ns = vim.api.nvim_create_namespace('file_highlight')  -- Unique namespace for highlighting
	local num_lines = vim.api.nvim_buf_line_count(buf)

	if current_extmark then
		vim.api.nvim_buf_del_extmark(buf, highlight_ns, current_extmark)
	end
	-- Create a new extmark to highlight the line
	current_extmark = vim.api.nvim_buf_set_extmark(buf, highlight_ns, line_number, 0, {
		end_row = line_number + 1,  -- Highlight the entire line
		hl_group = 'Visual',  -- You can customize the highlight group
	})
    return current_extmark 
end
function M.get_filenames_from_buffers(buffer_list)
    local file_names = {}
    local reduced_buffer_list = {}
 -- Loop through the buffer numbers and get their file names
    for idx, buffer in ipairs(buffer_list) do
        local file_name = vim.api.nvim_buf_get_name(buffer)
        if file_name ~= "" then
            table.insert(file_names, file_name)
            table.insert(reduced_buffer_list, buffer)
        end
    end
    return reduced_buffer_list, file_names
end
function M.switch_buffer(buffer_list,index)
    local buffer = buffer_list[index]
    -- if not a nil value, switch to that buffer
    if buffer then
        vim.api.nvim_set_current_buf(buffer)
    end
end

function M.run_find_async()
        vim.fn.jobstart('find . -path ./local/ -print -o -type f -print > ~/.fzfFile.txt', {
            -- This is called when there's output from stdout
            stdout_buffered = true,
            on_stderr = function(_, data)
                if data then
                    print("Error: " .. table.concat(data, "\n"))
                end
            end,
        })
    end

return M
