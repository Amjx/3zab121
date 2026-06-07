local partnerPed = nil
local syncScene = nil
local currentAnimDict = nil
local partnerClothingCache = {}
local sceneObjects = {}

local utils = require("modules.client.utils")
local kvp = require("modules.client.kvp")
local partnerCitizenId = kvp.partnerCitizenId

local coupleAnims = {
    {
        animDict = "timetable@trevor@ig_1",
        m = "ig_1_thedontknowwhy_trevor",
        f = "ig_1_thedontknowwhy_patricia"
    },
    {
        animDict = "timetable@trevor@ig_1",
        m = "ig_1_therearejustsomemoments_trevor",
        f = "ig_1_therearejustsomemoments_patricia"
    },
    {
        animDict = "timetable@trevor@ig_1",
        m = "ig_1_thedesertissobeautiful_trevor",
        f = "ig_1_thedesertissobeautiful_patricia"
    }
}

local bffAnims = {
    {
        animDict = "anim@mp_player_intcelebrationpaired@f_f_sarcastic",
        left = "sarcastic_left",
        right = "sarcastic_right"
    },
    {
        animDict = "anim@mp_player_intcelebrationpaired@f_f_fist_bump",
        left = "fist_bump_left",
        right = "fist_bump_right"
    },
    {
        animDict = "anim@mp_player_intcelebrationpaired@m_m_manly_handshake",
        left = "manly_handshake_left",
        right = "manly_handshake_right"
    },
    {
        animDict = "anim@mp_player_intcelebrationpaired@m_m_bro_hug",
        left = "bro_hug_left",
        right = "bro_hug_right"
    },
    {
        animDict = "anim@mp_player_intcelebrationpaired@f_m_bro_hug",
        left = "bro_hug_left",
        right = "bro_hug_right"
    }
}

function setupBarScenario(coords)
    local barAnimDict = "safe@trevor@ig_5"
    currentAnimDict = barAnimDict

    local sceneProps = {
        { anim = "drink_3_beer", model = 1360987401 },
        { anim = "drink_3_cam", model = -1296774200 }
    }

    local playerAnim = "drink_3"

    lib.requestAnimDict(currentAnimDict)

    syncScene = NetworkCreateSynchronisedScene(
        coords.x, coords.y, coords.z - 0.95,
        0.0, 0.0, 20.67,
        2, true, false, 1065353216, 0, 1.0
    )

    NetworkAddPedToSynchronisedScene(
        cache.ped, syncScene, currentAnimDict, playerAnim,
        1.5, -4.0, 1, 16, 1148846080, 0
    )

    sceneObjects = {}

    for _, prop in pairs(sceneProps) do
        lib.requestModel(prop.model)

        local obj = CreateObject(prop.model, coords.x, coords.y, coords.z - 0.95, true, true, true)
        sceneObjects[#sceneObjects + 1] = obj

        NetworkAddEntityToSynchronisedScene(obj, syncScene, currentAnimDict, prop.anim, 1.0, -4.0, 1)
    end

    NetworkStartSynchronisedScene(syncScene)
end

function getRandomCoupleAnim()
    local anim = coupleAnims[math.random(1, #coupleAnims)]
    local playerModel = GetEntityModel(cache.ped)
    local isFemale = playerModel == -1667301416

    if isFemale then
        return anim.animDict, anim.f, anim.m, true
    end

    return anim.animDict, anim.m, anim.f, false
end

function getRandomBFFAnim()
    local anim = bffAnims[math.random(1, #bffAnims)]
    return anim.animDict, anim.left, anim.right
end

function getDefaultPartnerAppearance()
    local emptySkin = json.decode("{}")
    local defaultModel = 153984193
    return emptySkin, defaultModel
end

function createPartnerPed(playerCitizenId, coords, partnerCid, scenarioType)
    local heading = coords.w or 0.0

    local animDict, playerAnim, partnerAnim
    local sceneZ, sceneHeading

    local cachedClothing = partnerClothingCache[partnerCid]

    if not cachedClothing then
        local skin, model = lib.callback.await("um-ronin-multicharacter:server:getClothing", false, partnerCid)

        if not skin or not model then
            partnerCitizenId("remove", playerCitizenId)
            skin, model = getDefaultPartnerAppearance()
            warn("Partner character data not found for CID: " .. tostring(partnerCid))
        end

        partnerClothingCache[partnerCid] = { skin = skin, model = model }
    end

    if scenarioType == "bff" then
        animDict, playerAnim, partnerAnim = getRandomBFFAnim()
        sceneZ = coords.z - 1
        sceneHeading = heading + 90
    else
        animDict, playerAnim, partnerAnim = getRandomCoupleAnim()
        sceneZ = coords.z
        sceneHeading = heading
    end

    currentAnimDict = animDict

    lib.requestAnimDict(currentAnimDict)

    syncScene = NetworkCreateSynchronisedScene(
        coords.x, coords.y, sceneZ,
        0.0, 0.0, sceneHeading,
        2, true, false, 1065353216, 0, 1.0
    )

    NetworkAddPedToSynchronisedScene(
        cache.ped, syncScene, currentAnimDict, playerAnim,
        1.5, -4.0, 1, 16, 1148846080, 0
    )

    local cachedData = partnerClothingCache[partnerCid]
    cachedData.model = utils.modelToJoaat(cachedData.model)

    lib.requestModel(cachedData.model, 300000)

    partnerPed = CreatePed(4, cachedData.model, coords.x, coords.y, coords.z, heading + 180.0, true, true)

    while not DoesEntityExist(partnerPed) do
        Wait(0)
    end

    SetAppearance(partnerPed, cachedData.skin)
    FreezeEntityPosition(partnerPed, true)
    SetEntityInvincible(partnerPed, true)
    SetBlockingOfNonTemporaryEvents(partnerPed, true)

    NetworkAddPedToSynchronisedScene(
        partnerPed, syncScene, currentAnimDict, partnerAnim,
        1.5, -4.0, 1, 16, 1148846080, 0
    )

    NetworkStartSynchronisedScene(syncScene)
    SetModelAsNoLongerNeeded(cachedData.model)
    SetPedAsNoLongerNeeded(partnerPed)
end

function SetScenarioModes(data)
    local partnerData = partnerCitizenId("get", data and data.citizenid)

    if partnerData and partnerData.citizenid then
        SetWithPartnerMode(true, partnerData.type)
        createPartnerPed(data and data.citizenid, data.coords, partnerData.citizenid, partnerData.type)
        return
    end

    if data.camMode == 2 then
        setupBarScenario(data.coords)
    elseif data and data.emote then
        utils.playEmote(data.emote)
    end
end

function ClearScenarioModes()
    SetWithPartnerMode(false)
    utils.cancelEmote()

    if not syncScene or not currentAnimDict then
        return
    end

    if partnerPed then
        DeletePed(partnerPed)
        partnerPed = nil
        partnerClothingCache = {}
    else
        for _, obj in pairs(sceneObjects) do
            if DoesEntityExist(obj) then
                DeleteEntity(obj)
            end
        end
        sceneObjects = {}
    end

    NetworkStopSynchronisedScene(syncScene)
    RemoveAnimDict(currentAnimDict)
end

function DeletePartner(citizenid)
    partnerCitizenId("remove", citizenid)
    ClearScenarioModes()
end

function GetPartnerPed()
    return partnerPed
end
