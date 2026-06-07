local detectedClothingMenu = nil

local clothingHandlers = {
    {
        name = 'bl_appearance',
        handler = function(ped, data)
            exports.bl_appearance:SetPlayerPedAppearance(data)
        end
    },
    {
        name = 'rcore_clothing',
        handler = function(ped, data)
            exports.rcore_clothing:setPedSkin(ped, data)
        end
    },
    {
        name = 'crm-appearance',
        handler = function(ped, data)
            exports['crm-appearance']:crm_set_ped_appearance(ped, data)
        end
    },
    {
        name = 'tgiann-clothing',
        handler = function(ped, data)
            exports["tgiann-clothing"]:SetPedAppearance(ped, data)
        end
    },
    {
        name = '0r-clothingv2',
        handler = function(ped, data)
            TriggerEvent('0r-clothing:client:loadPlayerClothing', data, ped)
        end
    },
    {
        name = '0r-clothing',
        handler = function(ped, data)
            TriggerEvent('0r-clothing:client:loadPlayerClothing', data, ped)
        end
    },
    {
        name = 'illenium-appearance',
        handler = function(ped, data)
            exports['illenium-appearance']:setPedAppearance(ped, data)
        end
    },
    {
        name = 'fivem-appearance',
        handler = function(ped, data)
            exports['fivem-appearance']:setPedAppearance(ped, data)
        end
    },
    {
        name = 'qb-clothing',
        handler = function(ped, data)
            TriggerEvent('qb-clothing:client:loadPlayerClothing', data, ped)
        end
    },
    {
        name = 'origen_clothing',
        handler = function(ped, data)
            exports['origen_clothing']:SetAppearance(ped, data)
        end
    },
}

function SetAppearance(cacheped, skinData)
    if detectedClothingMenu then
        detectedClothingMenu.handler(cacheped, skinData)
        return true
    end

    -- No clothing system found
    warn('[WARNING] No supported clothing system detected. Available systems:')
    return false
end

CreateThread(function()
    for _, config in ipairs(clothingHandlers) do
        if GetResourceState(config.name) == 'started' then
            detectedClothingMenu = config
            MultiDebug('[INFO] Detected clothing system: ' .. config.name)
            break
        end
    end
end)
