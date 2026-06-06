local partnerStatus = require 'config.main'.partnerInvite

if not partnerStatus then return end

local inviteList = {}

lib.addCommand('partnerinvite', {
    help = 'Invite partner to character selection',
    params = {
        { name = 'target', type = 'playerId', help = 'ID of the player to invite' },
        { name = 'type',   type = 'string',   help = 'cp (couple) or bff (best friend)' }
    }
}, function(source, args)
    if not source then return end

    local targetPlayer = tonumber(args.target)
    if not targetPlayer then return end

    if targetPlayer == source then
        return MultiDebug('You cannot send yourself an invitation request.')
    end

    if inviteList[targetPlayer] then
        return MultiDebug('Target player already has a pending invite')
    end

    if not (GetPlayerName(targetPlayer) and GetPlayerPed(targetPlayer)) then
        return
    end

    local inviteType = args.type
    if inviteType ~= 'cp' and inviteType ~= 'bff' then
        return lib.notify(source, {
            title = locale('partnerInvite.title'),
            description = 'Type must be either cp or bf',
            type = 'error'
        })
    end

    local plyCoords = GetEntityCoords(GetPlayerPed(source))
    local targetCoords = GetEntityCoords(GetPlayerPed(targetPlayer))
    local distance = #(plyCoords - targetCoords)

    if distance > 10.0 then
        return
    end

    local targetCitizenid = GetPlayer(targetPlayer).PlayerData.citizenid
    if not targetCitizenid then
        return
    end

    local playerCitizenid = GetPlayer(source).PlayerData.citizenid


    inviteList[targetPlayer] = {
        ownerSource = source,
        playerCitizenid = playerCitizenid,
        targetCitizenid = targetCitizenid,
        type = inviteType
    }

    lib.notify(source, {
        title = locale('partnerInvite.title'),
        description = locale('partnerInvite.invite_sent', GetPlayerName(targetPlayer)),
        type = 'success'
    })

    inviteType = inviteType == 'cp' and locale('partnerInvite.couple') or locale('partnerInvite.best_friend')

    TriggerClientEvent('um-ronin-multicharacter:client:invitePlayer', targetPlayer, inviteType, GetPlayerName(source))
end)

RegisterNetEvent('um-ronin-multicharacter:server:acceptInvite', function(status)
    local data = inviteList[source]

    if not data then return end

    status = status == 'confirm'

    local plyName = GetPlayerName(source)

    lib.notify(data?.ownerSource, {
        title = locale('partnerInvite.title'),
        description = status and locale('partnerInvite.accepted', plyName) or locale('partnerInvite.declined', plyName),
        type = status and 'success' or 'error'
    })

    if status then
        TriggerClientEvent('um-ronin-multicharacter:client:saveInviteKVP', data.ownerSource, data.targetCitizenid, data
            .playerCitizenid, data.type)
        -- maybe log added here
    end

    inviteList[source] = nil
end)


lib.addCommand('forcepartner', {
    restricted = 'group.admin',
    help = 'Force add partner to character selection',
    params = {
        { name = 'targetCitizenid', type = 'string', help = 'Citizen ID of the player to invite' },
        { name = 'type',   type = 'string',   help = 'cp (couple) or bff (best friend)' }
    }
}, function(source, args)
    if not source then return end

    local inviteType = args.type
    if inviteType ~= 'cp' and inviteType ~= 'bff' then
        return lib.notify(source, {
            title = locale('partnerInvite.title'),
            description = 'Type must be either cp or bf',
            type = 'error'
        })
    end

    local targetCitizenid = args.targetCitizenid

    local playerCitizenid = GetPlayer(source).PlayerData.citizenid

    TriggerClientEvent('um-ronin-multicharacter:client:saveInviteKVP', source, targetCitizenid, playerCitizenid,
        inviteType)

    lib.notify(source, {
        title = locale('partnerInvite.title'),
        type = 'success'
    })
end)
