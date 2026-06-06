local logoutForEveryone = false
local sendLogs = require('modules.server.log').sendLogs

local permission = 'group.admin'

lib.addCommand('logout', { help = 'Logout Character', restricted = not logoutForEveryone and permission },
    function(source)
        local src = source
        Logout(src)
        sendLogs(src, 'logout', 'Logged out from their character.', 'yellow', 'logout')
        TriggerClientEvent('um-ronin-multicharacter:sessionStarted', src)
    end)

lib.addCommand('migratecid', { help = 'Migrate CID values', restricted = permission }, function()
    local affectedRows = MySQL.update.await([[
        UPDATE players p
        JOIN (
            SELECT
                id,
                ROW_NUMBER() OVER (
                    PARTITION BY
                        license
                    ORDER BY
                        citizenid
                ) AS new_cid
            FROM
                players
        ) AS r ON p.id = r.id
        SET
            p.cid = r.new_cid
    ]])
    print('^2[MIGRATE CID]^7 CID migration completed. Affected rows: ' .. (affectedRows or 0))
end)


lib.addCommand('getbucketCheck', { help = 'Get Bucket Check', restricted = permission }, function(source)
    local src = source
    local bucket = GetPlayerRoutingBucket(tostring(src))
    print('Player ' .. src .. ' is in bucket: ' .. bucket)
end)
