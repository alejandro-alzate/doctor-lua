--https://stackoverflow.com/questions/10386672/reading-whole-files-in-lua
local function readAll(file)
    local f = assert(io.open(file, "rb"))
    local content = f:read("*all")
    f:close()
    return content
end

return readAll