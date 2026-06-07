local tableList = require 'config.tablelist'

---@source https://github.com/Qbox-project/qbx_core/blob/main/server/storage/players.lua#L220-L253

---checks if a table exists in the database
---@param tableName string
---@return boolean
local function doesTableExist(tableName)
    local result = MySQL.scalar.await(
        'SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ?',
        { tableName })
    return result and result > 0
end

---deletes character data using the tableList
---@param citizenId string
---@param source number
---@return boolean success if operation is successful.
local function deletePlayer(citizenId, source)
    local query = 'DELETE FROM %s WHERE %s = ?'
    local queries = {}

    for i = 1, #tableList do
        local data = tableList[i]
        local tableName = data.table
        local columnName = data.column
        local identifierType = data.type

        local identifier = citizenId
        if identifierType ~= 'citizenid' then
            identifier = GetPlayerIdentifierByType(tostring(source), identifierType)
        end

        if identifier and doesTableExist(tableName) then
            queries[#queries + 1] = {
                query = query:format(tableName, columnName),
                values = {
                    identifier,
                }
            }
        elseif not doesTableExist(tableName) then
            warn(('Table %s does not exist in database, please remove it from tableList or create the table')
                :format(tableName))
        end
    end

    local success = MySQL.transaction.await(queries)
    return not not success
end

return {
    deletePlayer = deletePlayer
}
