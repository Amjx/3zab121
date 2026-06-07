local config = require("config.main")
local utils = require("modules.client.utils")

local nuiReady = false
local characterCache = {}

NetworkStartSoloTutorialSession()
SetEntityVisible(PlayerPedId(), false, false)

function previewPed(citizenId, cacheIndex)
    if not citizenId then
        return
    end

    local clothing = nil
    local model = nil
    local cachedEntry = characterCache[cacheIndex]

    if cachedEntry and cachedEntry.appearance then
        clothing = cachedEntry.appearance.clothing
        model = cachedEntry.appearance.model
        MultiDebug("[CACHE] Using cached character data for: " .. citizenId)
    else
        clothing, model = lib.callback.await("um-ronin-multicharacter:server:getClothing", false, citizenId)

        if model and clothing then
            if not characterCache[cacheIndex] then
                characterCache[cacheIndex] = {}
            end
            characterCache[cacheIndex].appearance = {
                clothing = clothing,
                model = model
            }
            MultiDebug("[CACHE] Cached character data for: " .. citizenId)
        else
            SetEntityVisible(PlayerPedId(), false, false)
            warn("No model or clothing found for preview")
            return
        end
    end

    utils.setModel(model)
    if SetAppearance then
        SetAppearance(PlayerPedId(), clothing)
    elseif GetResourceState('illenium-appearance') == 'started' then
        exports['illenium-appearance']:setPedAppearance(PlayerPedId(), clothing)
    end
    SetEntityVisible(PlayerPedId(), true, false)
    MultiDebug("[previewPed] COMPLETED for citizenId: " .. citizenId)
end

function loadingCharacter(characterData, totalSlots, deleteAccess)
    MultiDebug("[loadingCharacter] STARTED")

    local playerPed = PlayerPedId()

    local jobName = characterData and characterData.job and characterData.job.name
    local gangName = characterData and characterData.gang and characterData.gang.name

    local selectedLocation = utils.getSelectedCoords(
        jobName or "unknown",
        gangName or "unknown",
        config.randomCoords
    )

    local coords = selectedLocation.coords
    if not characterData then
        coords = config.registerShowCoords
    end

    utils.reqAndSetPlayer(coords, playerPed)

    local distance = utils.getPedDistance(coords, playerPed)
    while distance > 1.0 do
        Wait(0)
        MultiDebug("Loading character spawn collision, distance:", distance)
        distance = utils.getPedDistance(coords, playerPed)
        SetEntityCoordsNoOffset(playerPed, coords.x, coords.y, coords.z, false, false, false)

        local heading = coords and coords.w or 0.0
        SetEntityHeading(playerPed, heading)
    end

    NetworkStartSoloTutorialSession()

    while not NetworkIsInTutorialSession() do
        Wait(0)
    end

    Wait(1500)
    DisplayRadar(false)
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    config.hideHud(true)
    WeatherAndTime(config.weatherAndTimeForce.enable)
    SetFollowPedCamViewMode(2)

    lib.callback.await("setBucketRonin")

    if characterData then
        SetEntityVisible(playerPed, true, false)

        local emote = selectedLocation.emote
        if not emote then
            emote = { animName = utils.getRandomEmote() }
        end

        SetScenarioModes({
            citizenid = characterData and characterData.citizenid,
            coords = coords,
            camMode = selectedLocation.camMode,
            emote = emote
        })
    end

    DoScreenFadeIn(100)

    local camMode = (characterData and selectedLocation.camMode) or 4
    local camOptions = (characterData and selectedLocation.camOptions) or nil

    local cameraReady = Citizen.Await(CamCreate(camMode, camOptions))

    Wait(500)
    MultiDebug("Camera ready, showing NUI")

    if cameraReady then
        SetNuiFocus(true, true)
        SendNUIMessage({
            type = "open",
            data = {
                character = characterData or false,
                remainingSlots = characterData and (totalSlots - #characterCache) or totalSlots,
                characterCount = characterData and #characterCache or 0,
                deleteAccess = (characterData and deleteAccess) or false
            }
        })
    end
end

RegisterNetEvent("um-ronin-multicharacter:sessionStarted", function()
    DoScreenFadeOut(0)
    SetEntityVisible(PlayerPedId(), false, false)
    SetNuiFocus(false, false)

    local characters, totalSlots, hasDeleteAccess = lib.callback.await("um-ronin-multicharacter:server:getAllCharacters", false)

    characterCache = characters or {}

    local firstCharacter = characterCache and characterCache[1]

    MultiDebug("First character data fetched:", (firstCharacter and firstCharacter.citizenid) or "No character found")

    previewPed(firstCharacter and firstCharacter.citizenid, 1)
    loadingCharacter(firstCharacter, totalSlots, hasDeleteAccess)
end)

RegisterNUICallback("changeCharacter", function(data, cb)
    local characterData = characterCache and characterCache[data]

    if not (characterData and characterData.citizenid) then
        return warn("No character data found for key: " .. tostring(data))
    end

    local playerPed = PlayerPedId()
    local fadeInDuration = 50

    local jobName = characterData and characterData.job and characterData.job.name
    local gangName = characterData and characterData.gang and characterData.gang.name

    local selectedLocation = utils.getSelectedCoords(
        jobName or "unknown",
        gangName or "unknown",
        false
    )

    local coords = selectedLocation.coords
    local distance = utils.getPedDistance(selectedLocation.coords, playerPed)

    ClearScenarioModes()

    if distance > 50 then
        fadeInDuration = 500
    end

    DoScreenFadeOut(50)

    while not IsScreenFadedOut() do
        Wait(0)
    end

    CamDestroy()
    utils.reqAndSetPlayer(coords, playerPed)
    previewPed(characterData.citizenid, data)

    Wait(100)

    local emote = selectedLocation.emote
    if not emote then
        emote = { animName = utils.getRandomEmote() }
    end

    SetScenarioModes({
        coords = coords,
        citizenid = characterData.citizenid,
        camMode = selectedLocation.camMode,
        emote = emote
    })

    Citizen.Await(CamCreate(selectedLocation.camMode, selectedLocation.camOptions, true))

    DoScreenFadeIn(fadeInDuration)

    while not IsScreenFadedIn() do
        Wait(0)
    end

    cb({ newCharacter = characterData })
end)

RegisterNUICallback("getLoadingData", function(_, cb)
    local locale = GetConvar("ox:locale", "en")
    local localeData = lib.loadJson("locales." .. locale)
    local nuiLocale = localeData.nui

    local kvp = require("modules.client.kvp")
    local settings = kvp.getSettings()

    cb({
        locale = nuiLocale,
        settingsData = settings,
        storeURL = config.storeURL,
        logoURL = config.logoURL,
        credits = config.credits
    })

    MultiDebug("Sent loading data to NUI")
end)

lib.callback.register("getNextAvailableCid", function()
    if not next(characterCache) then
        return 1
    end

    local usedCids = {}
    for i = 1, #characterCache do
        local cid = characterCache[i] and characterCache[i].cid
        if cid then
            usedCids[cid] = true
        end
    end

    local nextCid = 1
    while usedCids[nextCid] do
        nextCid = nextCid + 1
    end

    return nextCid
end)

RegisterNetEvent("um-ronin-multicharacter:saveCharacterKVP", function(data)
    if GetInvokingResource() then
        return
    end

    if not data then
        return
    end

    local playerData = GetPlayerData()
    local citizenId = playerData and playerData.citizenid

    local kvp = require("modules.client.kvp")
    kvp.setHeightOrBackstory(citizenId, data.height, data.backstory)

    MultiDebug("Character KVP saved for setHeightOrBackstory")
end)

RegisterNUICallback("roninReady", function(_, cb)
    cb("ok")
    nuiReady = true
    MultiDebug("Ronin is ready")
end)

if config.manuelStart then
    return
end

CreateThread(function()
    while true do
        Wait(0)

        if NetworkIsSessionStarted() and nuiReady then
            Wait(300)

            pcall(function()
                exports.spawnmanager:setAutoSpawn(false)
            end)

            if config.experimentalCrashPreventionForYmtLimits then
                local pedModels = { -1667301416, 1885233650 }
                for _, modelHash in pairs(pedModels) do
                    lib.requestModel(modelHash)
                end
            end

            TriggerEvent("um-ronin-multicharacter:sessionStarted")
            break
        end
    end

    while NetworkIsInTutorialSession() do
        SetEntityInvincible(PlayerPedId(), true)
        Wait(250)
    end

    SetEntityInvincible(PlayerPedId(), false)
end)
