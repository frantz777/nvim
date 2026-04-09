local M = {}
function M.log(msg)
    --local logfile = vim.fn.stdpath("cache") .. "/live_grep.log"
    local logFile = os.getenv("HOME") .. "/live_grep.log"
    
    print(logFile)
    local f = io.open(logFile, "a")
    if f then
        f:write(os.date("%H:%M:%S") .. " | " .. msg .. "\n")
        f:close()
    end
end

return M


