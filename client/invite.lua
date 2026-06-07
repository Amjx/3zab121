local partnerStatus = require 'config.main'.partnerInvite

if not partnerStatus then return end

local partnerCitizenId = require 'modules.client.kvp'.partnerCitizenId

RegisterNetEvent('um-ronin-multicharacter:client:invitePlayer', function(inviterType, inviterName)
    if GetInvokingResource() then return end

    local status = lib.alertDialog({
        header = locale('partnerInvite.title') .. ' [' .. inviterType .. ']',
        content = locale('partnerInvite.description', inviterName),
        centered = true,
        cancel = true,
        labels = {
            cancel = locale('partnerInvite.decline'),
            confirm = locale('partnerInvite.accept')
        },
        size = 'sm'
    })

    TriggerServerEvent('um-ronin-multicharacter:server:acceptInvite', status)
end)

RegisterNetEvent('um-ronin-multicharacter:client:saveInviteKVP', function(targetCitizen, plyCitizen, type)
    if GetInvokingResource() then return end

    partnerCitizenId('set', plyCitizen, targetCitizen, type)
    MultiDebug('Partner Citizen ID saved: ' .. tostring(targetCitizen), tostring(plyCitizen))
end)
