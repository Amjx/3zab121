local detectedClothing = nil

local clothingHandlers = {
    {
        name = 'illenium-appearance',
        handler = function(citizenid)
            -- illenium-appearance con ESX guarda la skin en la columna `skin` de users
            local row = MySQL.single.await(
                'SELECT `skin` FROM `users` WHERE `identifier` = ? LIMIT 1',
                { citizenid }
            )
            if not row or not row.skin or row.skin == '' then return nil, nil end
            local skin = json.decode(row.skin)
            if not skin then return nil, nil end
            local model = skin.model or 'mp_m_freemode_01'
            return skin, model
        end
    },
    {
        name = 'bl_appearance',
        handler = function(citizenid)
            local appearance = exports.bl_appearance:GetPlayerAppearance(citizenid)

            if not appearance then
                return nil, nil
            end

            return appearance, appearance.model
        end
    },
    {
        name = 'rcore_clothing',
        handler = function(citizenid)
            local skin = exports.rcore_clothing:getSkinByIdentifier(citizenid)

            if not skin then
                return nil, nil
            end

            return skin.skin, skin.ped_model
        end
    },
    {
        name = 'tgiann-clothing',
        handler = function(citizenid)
            local skin = MySQL.single.await('SELECT `model`, `skin` FROM `tgiann_skin` WHERE `citizenid` = ? LIMIT 1',
                { citizenid })

            if not skin then
                return nil, nil
            end

            return json.decode(skin.skin), skin.model
        end
    },
    {
        name = 'origen_clothing',
        handler = function(citizenid)
            local skin = MySQL.single.await(
                'SELECT `model`, `skin` FROM `origen_clothing_skins` WHERE `citizenid` = ? AND `active` = 1 LIMIT 1',
                { citizenid }
            )

            if not skin then
                return nil, nil
            end

            return json.decode(skin.skin), skin.model
        end
    },
}

local function getPlayerClothing(source, citizenid)
    if not source or not citizenid then return nil, nil end

    if detectedClothing then
        MultiDebug('[INFO] Using detected clothing system for character')
        return detectedClothing.handler(citizenid)
    end

    -- Default fallback: illenium-appearance / qb-clothing and etc
    local result = MySQL.single.await('SELECT * FROM playerskins WHERE citizenid = ? AND active = 1 LIMIT 1',
        { citizenid })

    if not result then return nil, nil end

    MultiDebug('No clothing handler system detected, using default query: illenium-appearance / qb-clothing and etc')
    return json.decode(result.skin), result.model
end

lib.callback.register('um-ronin-multicharacter:server:getClothing', function(source, citizenid)
    return getPlayerClothing(source, citizenid)
end)

CreateThread(function()
    for _, config in ipairs(clothingHandlers) do
        if GetResourceState(config.name) == 'started' then
            detectedClothing = config
            MultiDebug('[INFO] Detected clothing system: ' .. config.name)
            break
        end
    end
end)
