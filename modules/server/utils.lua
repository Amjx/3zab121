local utils = {}

local function addItemToInventory(src, item, amount, metadata)
    if GetResourceState('ox_inventory') == 'started' then
        exports.ox_inventory:AddItem(src, item, amount, metadata)
        return
    end

    local player = GetPlayer(src)
    if not player then return end
    player.Functions.AddItem(item, amount, false, metadata)

    -- exports['qb-inventory']:AddItem(src, item, amount, false, metadata)
end

local function defaultQBMetaData(src, item)
    local player = GetPlayer(src)
    if not player then return end

    local charinfo = player.PlayerData.charinfo

    local data = {}

    if item == "id_card" then
        data = {
            firstname = charinfo.firstname,
            lastname = charinfo.lastname,
            birthdate = charinfo.birthdate,
            gender = charinfo.gender,
            nationality = charinfo.nationality,
        }
    elseif item == "driver_license" then
        data = {
            firstname = charinfo.firstname,
            lastname = charinfo.lastname,
            birthdate = charinfo.birthdate,
            type = "Class C Driver License",
        }
    end

    addItemToInventory(src, item, 1, data)
end

local function customIDCard(src, item)
    if GetResourceState('um-idcard') == 'started' then
        exports['um-idcard']:CreateMetaLicense(src, item)
    elseif GetResourceState('bl_idcard') == 'started' then
        exports.bl_idcard:createLicense(src, item)
    elseif GetResourceState('qbx_idcard') == 'started' then
        exports['qbx_idcard']:CreateMetaLicense(src, item)
    else
        defaultQBMetaData(src, item)
    end
end


function utils.GiveStarterItems(src)
    local player = GetPlayer(src)
    if not player then return end

    local starterItems = lib.load('config.starteritems') or {}

    for i = 1, #starterItems do
        local data = starterItems[i]

        if data.item == 'id_card' or data.item == 'driver_license' then
            customIDCard(src, data.item)
        else
            addItemToInventory(src, data.item, data.amount, data?.metadata or {})
        end
    end
end

function utils.LoadHouseData(src)
    if GetResourceState('ps-housing') == 'started' then return end

    local status, result = pcall(function()
        return MySQL.query.await('SELECT * FROM houselocations', {})
    end)

    if not status then return end

    local HouseGarages = {}
    local Houses = {}

    if result[1] ~= nil then
        for _, v in pairs(result) do
            local owned = false
            if tonumber(v.owned) == 1 then
                owned = true
            end
            local garage = v.garage ~= nil and json.decode(v.garage) or {}
            Houses[v.name] = {
                coords = json.decode(v.coords),
                owned = owned,
                price = v.price,
                locked = true,
                adress = v.label,
                tier = v.tier,
                garage = garage,
                decorations = {},
            }
            HouseGarages[v.name] = {
                label = v.label,
                takeVehicle = garage,
            }
        end
    end

    TriggerClientEvent("qb-garages:client:houseGarageConfig", src, HouseGarages)
    TriggerClientEvent("qb-houses:client:setHouseConfig", src, Houses)
end

return utils
