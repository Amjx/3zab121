local defaultSpawnCoords = require 'config.main'.defaultSpawnCoords
local reqAndSetPlayer    = require 'modules.client.utils'.reqAndSetPlayer
local setModel           = require 'modules.client.utils'.setModel

local function houseOrApartmentInside(citizenid)
    local PlayerData = GetPlayerData()
    local insideMeta = PlayerData?.metadata["inside"] or {}

    if GetResourceState('ps-housing') == 'started' then
        local result = lib.callback.await('ps-housing:cb:GetOwnedApartment', source, citizenid)
        if result then
            TriggerEvent("apartments:client:SetHomeBlip", result?.type)
        end
    end

    if insideMeta?.house ~= nil then
        local houseId = insideMeta.house
        TriggerEvent('qb-houses:client:LastLocationHouse', houseId)
    elseif insideMeta?.apartment?.apartmentType ~= nil or insideMeta?.apartment?.apartmentId ~= nil then
        local apartmentType = insideMeta.apartment.apartmentType
        local apartmentId = insideMeta.apartment.apartmentId
        TriggerEvent('qb-apartments:client:LastLocationHouse', apartmentType, apartmentId)
    elseif insideMeta?.propertyId or insideMeta?.property_id then
        TriggerServerEvent('ps-housing:server:enterProperty', tostring(insideMeta.propertyId))
    end
end

RegisterNetEvent('um-ronin-multicharacter:spawnLastLocation', function(data)
    if GetInvokingResource() then return end

    local ped = PlayerPedId()
    local coords = type(data.lastloc) == 'string' and json.decode(data.lastloc) or data.lastloc

    reqAndSetPlayer(coords, ped)

    houseOrApartmentInside(data?.citizenid)

    TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
    TriggerEvent('QBCore:Client:OnPlayerLoaded')
    -- esx:onPlayerLoaded se dispara automaticamente desde el handler de esx:playerLoaded
    -- que es_extended tiene en el cliente. No lo llamamos manualmente para evitar que
    -- scripts como esx_status reciban el evento con datos invalidos.
    TriggerServerEvent('qb-houses:server:SetInsideMeta', 0, false)
    TriggerServerEvent('qb-apartments:server:SetInsideMeta', 0, 0, false)

    SetEntityVisible(ped, true, false)
    FreezeEntityPosition(ped, false)

    -- Aplica la apariencia guardada (necesario en ESX; en QBCore lo hace OnPlayerLoaded)
    if data.citizenid then
        local clothing, model = lib.callback.await('um-ronin-multicharacter:server:getClothing', false, data.citizenid)
        if model then
            setModel(model)
        end
        if clothing then
            local newPed = PlayerPedId()
            SetEntityVisible(newPed, true, false)
            SetEntityAlpha(newPed, 255, false)
            if SetAppearance then
                SetAppearance(newPed, clothing)
            elseif GetResourceState('illenium-appearance') == 'started' then
                exports['illenium-appearance']:setPedAppearance(newPed, clothing)
            end
        end
    end

    Wait(1000)
    DoScreenFadeIn(1000)
end)


RegisterNetEvent('um-ronin-multicharacter:outsideSpawnForNewCharacter', function()
    if GetInvokingResource() then return end

    local ped = PlayerPedId()

    reqAndSetPlayer(defaultSpawnCoords, ped)

    Wait(1000)

    TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
    TriggerEvent('QBCore:Client:OnPlayerLoaded')
    -- esx:onPlayerLoaded se dispara automaticamente via esx:playerLoaded (ver Login())
    TriggerServerEvent('qb-houses:server:SetInsideMeta', 0, false)
    TriggerServerEvent('qb-apartments:server:SetInsideMeta', 0, 0, false)
    TriggerEvent('qb-weathersync:client:EnableSync')

    -- Usamos el genero guardado desde actioncallback.lua (0=male, 1=female).
    -- No intentamos detectarlo desde el modelo actual porque ESX u otro script
    -- (ej. esx_skin) puede haberlo reseteado durante el await del server callback.
    local isFemale    = (_G.__ronin_newCharGender == 1)
    local maleHash    = GetHashKey('mp_m_freemode_01')
    local femaleHash  = GetHashKey('mp_f_freemode_01')
    local targetModel = isFemale and femaleHash or maleHash
    _G.__ronin_newCharGender = nil  -- limpiamos la variable temporal

    lib.requestModel(targetModel)
    SetPlayerModel(cache.playerId, targetModel)
    local newPed = PlayerPedId()
    SetPedDefaultComponentVariation(newPed)
    SetEntityVisible(newPed, true, false)
    SetEntityAlpha(newPed, 255, false)
    FreezeEntityPosition(newPed, false)

    DoScreenFadeIn(500)
    while not IsScreenFadedIn() do Wait(0) end

    if GetResourceState('illenium-appearance') == 'started' then
        -- IMPORTANTE: resetear head blend antes de abrir illenium.
        -- Sin esto el ped aparece invisible en el editor (igual que hace ZSX).
        SetPedHeadBlendData(PlayerPedId(), 0, 0, 0, 0, 0, 0, 0, 0, 0, false)
        Wait(100)

        local newCharCfg = {
            ped              = false,
            headBlend        = true,
            faceFeatures     = true,
            headOverlays     = true,
            components       = true,
            componentConfig  = {
                masks = true, upperBody = true, lowerBody = true, bags = true,
                shoes = true, scarfAndChains = true, bodyArmor = true,
                shirts = true, decals = true, jackets = true,
            },
            props            = true,
            propConfig       = {
                hats = true, glasses = true, ear = true,
                watches = true, bracelets = true,
            },
            tattoos          = true,
            enableExit       = true,
            automaticFade    = false,
        }

        exports['illenium-appearance']:startPlayerCustomization(function(appearance)
            if appearance then
                TriggerServerEvent('illenium-appearance:server:saveAppearance', appearance)
            end
        end, newCharCfg)
    elseif GetResourceState('bl_appearance') == 'started' then
        exports.bl_appearance:startPlayerCustomization(function(_) end)
    else
        TriggerEvent(require('config.main').forNewPlayerNoApartmentStartAppearanceShow)
    end
end)
