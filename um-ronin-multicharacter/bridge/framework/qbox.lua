if GetResourceState('qbx_core') ~= 'started' then return end

print('^2 Using QBox framework bridge')

local framework = exports.qbx_core
local is_server = IsDuplicityVersion()
local debug = require 'config.main'.debug

function MultiDebug(...)
    if not debug then return end
    lib.print.info('^6[um-ronin-multicharacter] \n^2', ...)
end

if is_server then
    function Login(source, citizenid, newData)
        return framework:Login(source, citizenid, newData)
    end

    function Logout(source)
        return framework:Logout(source)
    end

    function PlayerIdentifier(source)
        return GetPlayerIdentifierByType(source, 'license'), GetPlayerIdentifierByType(source, 'license2')
    end

    function GetPlayer(source)
        return framework:GetPlayer(source)
    end

    function RefreshCommand(source)
        return MultiDebug('QBox framework does not require command refresh', source)
    end
else
    function GetPlayerData()
        return framework:GetPlayerData()
    end
end
