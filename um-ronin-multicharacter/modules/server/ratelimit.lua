local ratelimit = {}
local activeProcesses = {}

---@param source number Player source
---@param action string Action name
---@return boolean isProcessing
function ratelimit.isProcessing(source, action)
    local key = source .. ':' .. action
    if activeProcesses[key] then
        return true
    end
    activeProcesses[key] = true
    return false
end

---@param source number Player source
---@param action string Action name
function ratelimit.clearProcess(source, action)
    local key = source .. ':' .. action
    activeProcesses[key] = nil
end

---@param source number Player source
function ratelimit.clearPlayer(source)
    local pattern = '^' .. source .. ':'
    for key in pairs(activeProcesses) do
        if key:find(pattern) then
            activeProcesses[key] = nil
        end
    end
end

return ratelimit
