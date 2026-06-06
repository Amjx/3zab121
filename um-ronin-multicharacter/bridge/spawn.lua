local spawnState = require 'config.main'
local detectedApartment, detectedSpawn = nil, nil

local spawn = {}

local apartmentHandlers = {
    ['um-spawn'] = {
        handler = function(src)
            TriggerClientEvent('um-spawn:client:startSpawnUI', src)
        end
    },
    ['ps-housing'] = {
        handler = function(src, newData)
            if GetResourceState('qbx_properties') ~= 'missing' then
                TriggerClientEvent('apartments:client:setupSpawnUI', src)
            else
                TriggerClientEvent('ps-housing:client:setupSpawnUI', src, newData, true, true)
            end
        end
    },
    ['okokSpawnSelector'] = {
        handler = function(src)
            TriggerClientEvent('okokSpawnSelector:spawnMenu', src, true)
        end
    },
    ['vms_spawnselector'] = {
        handler = function(src)
            TriggerClientEvent('vms_spawnselector:open', src, true)
        end
    },
    ['bcs_housing'] = {
        handler = function(src, newData)
            TriggerClientEvent('Housing:client:SetupSpawnUI', src, newData)
        end
    },
    ['qbx_properties'] = {
        handler = function(src)
            TriggerClientEvent('apartments:client:setupSpawnUI', src)
        end
    },
    ['qb-apartments'] = {
        handler = function(src, newData)
            TriggerClientEvent('apartments:client:setupSpawnUI', src, newData, true, true)
        end
    },
    ['qbx_apartments'] = {
        handler = function(src, newData)
            TriggerClientEvent('apartments:client:setupSpawnUI', src, newData)
        end
    },
    ['0r-apartment'] = {
        handler = function(src, newData)
            TriggerClientEvent('apartments:client:setupSpawnUI', src, newData, true, true)
        end
    }
}

-- Spawn system handlers for existing characters
local spawnHandlers = {
    ['um-spawn'] = {
        handler = function(src)
            TriggerClientEvent('um-spawn:client:startSpawnUI', src)
        end
    },
    ['okokSpawnSelector'] = {
        handler = function(src, cData)
            TriggerClientEvent('okokSpawnSelector:spawnMenu', src, false, json.decode(cData.lastloc) or cData.lastloc)
        end
    },
    ['vms_spawnselector'] = {
        handler = function(src)
            TriggerClientEvent('vms_spawnselector:open', src)
        end
    },
    ['qbx_spawn'] = {
        handler = function(src, cData)
            TriggerClientEvent('qb-spawn:client:setupSpawns', src, cData?.citizenid)
        end
    },
    ['qb-spawn'] = {
        handler = function(src, cData)
            TriggerClientEvent('qb-spawn:client:setupSpawns', src, cData?.citizenid)
            TriggerClientEvent('qb-spawn:client:openUI', src, true)
        end
    }
}


function spawn.GetApartmentInsideStartSpawnUI(src, newData)
    if not spawnState.apartmentStart then
        TriggerClientEvent('um-ronin-multicharacter:outsideSpawnForNewCharacter', src)
        MultiDebug('[INFO] NewPlayerApartmentInsideStart is disabled, using default spawn')
        return
    end

    if detectedApartment then
        detectedApartment.handler(src, newData)
        MultiDebug('[INFO] Using detected apartment system for new character')
        return
    end

    TriggerClientEvent('um-ronin-multicharacter:outsideSpawnForNewCharacter', src)
    MultiDebug('[WARNING] No apartment system detected, using default spawn')
end

function spawn.GetCharacterReadySpawnUI(src, data)
    if spawnState.onlyLastLocationNoSpawnMenu then
        TriggerClientEvent("um-ronin-multicharacter:spawnLastLocation", src, data)
        MultiDebug('[INFO] NoSpawnMenuOnlyLastLocation enabled, spawning at last location')
        return
    end

    if detectedSpawn then
        detectedSpawn.handler(src, data)
        MultiDebug('[INFO] Using detected spawn system for existing character')
        return
    end


    TriggerClientEvent("um-ronin-multicharacter:spawnLastLocation", src, data)
    MultiDebug('[WARNING] No spawn system detected, spawning at last location')
end

CreateThread(function()
    local detectConfigs = {
        { handlers = apartmentHandlers, checkState = 'started', setter = function(c) detectedApartment = c end, name = 'apartment' },
        { handlers = spawnHandlers,     checkState = 'started', setter = function(c) detectedSpawn = c end,     name = 'spawn', }
    }

    for _, detect in ipairs(detectConfigs) do
        for resourceName, config in pairs(detect.handlers) do
            local state = GetResourceState(resourceName)
            local match = state == detect.checkState
            if match then
                detect.setter(config)
                MultiDebug('[INFO] Detected ' .. detect.name .. ' system: ' .. resourceName)
                break
            end
        end
    end
end)

return spawn
