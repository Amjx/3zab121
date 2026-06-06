
if GetResourceState('qbx_core') == 'started' or GetResourceState('qb-core') ~= 'started' then return end

print('^2 Using QBCore framework bridge')

local framework = exports['qb-core']:GetCoreObject()
local is_server = IsDuplicityVersion()
local debug = require 'config.main'.debug

function MultiDebug(...)
    if not debug then return end
    lib.print.info('^6[um-ronin-multicharacter] \n^2', ...)
end

if is_server then
    function Login(source, citizenid, newData)
        return framework.Player.Login(source, citizenid, newData)
    end

    function Logout(source)
        return framework.Player.Logout(source)
    end

    function PlayerIdentifier(source)
        return GetPlayerIdentifierByType(source, 'license'), GetPlayerIdentifierByType(source, 'license2')
    end

    function GetPlayer(source)
        return framework.Functions.GetPlayer(source)
    end

    function RefreshCommand(source)
        return framework.Commands.Refresh(source)
    end
else
    function GetPlayerData()
        return framework.Functions.GetPlayerData()
    end
end
