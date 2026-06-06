local hideHud = require("config.main").hideHud

function closeMulticharacter()
    SetNuiFocus(false, false)
    DoScreenFadeOut(5000)
    CamDestroy(true)

    while not IsScreenFadedOut() do
        Wait(0)
    end

    ClearScenarioModes()
    Wait(500)
    WeatherAndTime(false)
    NetworkEndTutorialSession()

    while NetworkIsInTutorialSession() do
        Wait(0)
    end

    SetTimecycleModifier("default")
    hideHud(false)
end

RegisterNUICallback("createCharacter", function(data, cb)
    cb("ok")

    local setModel = require("modules.client.utils").setModel

    closeMulticharacter()

    if "male" == data.gender then
        data.gender = 0
        setModel(1885233650)
    elseif "female" == data.gender then
        data.gender = 1
        setModel(-1667301416)
    end

    MultiDebug("Creating character with data:", data)

    -- Guardamos el genero para que outsideSpawnForNewCharacter lo use
    -- aunque ESX u otro script haya reseteado el modelo durante el await.
    _G.__ronin_newCharGender = data.gender  -- 0 = male, 1 = female

    SetEntityVisible(PlayerPedId(), true, false)
    lib.callback.await("um-ronin-multicharacter:createNewCharacter", false, data)
end)

RegisterNUICallback("wakeUP", function(data, cb)
    cb("ok")
    closeMulticharacter()
    lib.callback.await("um-ronin-multicharacter:loadChar", false, data.citizenid)
end)

RegisterNUICallback("deleteCharacter", function(data, cb)
    local result = lib.callback.await("um-ronin-multicharacter:server:deleteCharacter", false, data)
    cb(result and "ok" or "error")
end)

RegisterNUICallback("redeemCode", function(data, cb)
    local result, message = lib.callback.await("um-ronin-multicharacter:redeem", false, data.code)
    cb({
        result = result,
        message = message
    })
end)

RegisterNUICallback("exitGame", function(_, cb)
    cb("ok")
    TriggerServerEvent("um-ronin-multicharacter:exitGame")
end)

RegisterNUICallback("deletePartner", function(data, cb)
    cb("ok")
    DeletePartner(data and data.citizenid)
end)

RegisterNUICallback("rotateCharacter", function(data, cb)
    cb("ok")

    if not cache.ped or not DoesEntityExist(cache.ped) then
        return
    end

    local currentHeading = GetEntityHeading(cache.ped)
    local deltaX = data.deltaX or 0
    local newHeading = currentHeading + (deltaX * 0.5)

    if newHeading > 360 then
        newHeading = newHeading - 360
    elseif newHeading < 0 then
        newHeading = newHeading + 360
    end

    SetEntityHeading(cache.ped, newHeading)
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end
    ClearScenarioModes()
end)
