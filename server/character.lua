local query = require("modules.server.query")
local ratelimit = require("modules.server.ratelimit")
local utils = require("modules.server.utils")
local spawn = require("bridge.spawn")
local sendLogs = require("modules.server.log").sendLogs
local deletePlayer = require("modules.server.chardel").deletePlayer

local playerLoadedState = {}

function canCreateCharacter(source)
    local license, fivemId = PlayerIdentifier(source)
    local charCount = MySQL.scalar.await(query.getCharacterCountQuery, { license, fivemId })

    if not charCount then
        charCount = 0
    end

    local maxSlots = GetTotalCharacterSlotAndDeleteAccess(source) or 1

    if charCount >= maxSlots then
        warn("^1[CHARACTER CREATION ERROR]^7 " .. GetPlayerName(source) .. " tried to create a character but has reached the maximum slot limit (" .. maxSlots .. ")")
        sendLogs(source, "exploit", "Tried to create a character but has reached the maximum slot limit (" .. maxSlots .. ")", "red", "exploit")

        SetTimeout(30000, function()
            ratelimit.clearProcess(source, "createCharacter")
        end)

        return false
    end

    return true
end

function getNextCid(source)
    if not source then
        return nil
    end

    local cid = lib.callback.await("getNextAvailableCid", source)

    if "number" ~= type(cid) then
        local invalidCid = tostring(cid)
        warn("^1[CHARACTER CREATION ERROR]^7 Invalid CID from client: " .. invalidCid .. " | Player: " .. GetPlayerName(source))
        DropPlayer(tostring(source), "Invalid CID detected. Please contact support.")
        sendLogs(source, "exploit", "Invalid CID from client: " .. invalidCid, "red", "exploit")
        return nil
    end

    if cid ~= math.floor(cid) or cid < 1 or cid > 100 then
        local invalidCid = tostring(cid)
        warn("^1[CHARACTER CREATION ERROR]^7 Out of bounds CID from client: " .. invalidCid .. " | Player: " .. GetPlayerName(source))
        DropPlayer(tostring(source), "Invalid CID detected. Please contact support.")
        sendLogs(source, "exploit", "Out of bounds CID from client: " .. invalidCid, "red", "exploit")
        return nil
    end

    -- Verify the CID does not already exist in the DB (guards against stale client cache
    -- where the cid column is NULL and the character is not returned by getAllCharactersQuery).
    local license, fivemId = PlayerIdentifier(source)
    local existingRows = MySQL.query.await(
        'SELECT cid FROM users WHERE (license = ? OR license2 = ?)',
        { license, fivemId }
    )
    if existingRows and #existingRows > 0 then
        local usedCids = {}
        for i = 1, #existingRows do
            local existingCid = existingRows[i].cid
            if existingCid then
                usedCids[tonumber(existingCid)] = true
            else
                -- Row exists but cid is NULL: treat it as cid=1 (legacy first character)
                usedCids[1] = true
            end
        end
        while usedCids[cid] do
            cid = cid + 1
        end
    end

    MultiDebug("Next available CID for player " .. GetPlayerName(source) .. " is: " .. cid)
    return cid
end

lib.callback.register("um-ronin-multicharacter:server:getAllCharacters", function(source)
    if not source then
        return
    end

    local characters = {}
    local license, fivemId = PlayerIdentifier(source)
    local rows = MySQL.query.await(query.getAllCharactersQuery, { license, fivemId })

    if not rows then
        return characters
    end

    for i = 1, #rows do
        local charInfo = json.decode(rows[i].charinfo)
        characters[i] = rows[i]
        characters[i].citizenid = rows[i].citizenid

        local cid = rows[i].cid
        if not cid then
            cid = charInfo.cid
        end
        characters[i].cid = cid

        characters[i].money = json.decode(rows[i].money)

        local jobData = rows[i].job
        if jobData then
            jobData = json.decode(rows[i].job)
        end
        characters[i].job = jobData

        local gangData = rows[i].gang
        if gangData then
            gangData = json.decode(rows[i].gang)
        end
        characters[i].gang = gangData

        characters[i].firstname = charInfo.firstname
        characters[i].lastname = charInfo.lastname
        characters[i].dob = charInfo.birthdate
        characters[i].nationality = charInfo.nationality
        characters[i].position = json.decode(rows[i].position)
    end

    return characters, GetTotalCharacterSlotAndDeleteAccess(source)
end)

lib.callback.register("um-ronin-multicharacter:createNewCharacter", function(source, charData)
    if not source then
        return
    end

    if ratelimit.isProcessing(source, "createCharacter") then
        return
    end

    local isValid, validationErrors = ValidateRegistration(charData)

    if not isValid then
        ratelimit.clearProcess(source, "createCharacter")

        if "table" ~= type(validationErrors) then
            return warn("^1[CHARACTER CREATION ERROR]^7 " .. GetPlayerName(source) .. " " .. validationErrors)
        end

        for field, errorMsg in pairs(validationErrors) do
            warn("^1[CHARACTER CREATION ERROR]^7 " .. GetPlayerName(source) .. " " .. field .. ": " .. errorMsg)
        end
        return
    end

    if not canCreateCharacter(source) then
        return
    end

    local cid = getNextCid(source)
    if not cid then
        return
    end

    local height = charData and charData.height
    local backstory = SetClearBackStory(charData and charData.backstory)

    local newCharData = {}
    newCharData.cid = cid
    newCharData.charinfo = charData

    if newCharData.charinfo then
        newCharData.charinfo.height = nil
    end
    if newCharData.charinfo then
        newCharData.charinfo.backstory = nil
    end

    local loginResult = Login(source, false, newCharData)

    if loginResult then
        local timeout = 0
        repeat
            Wait(10)
            timeout = timeout + 1
        until playerLoadedState[source] or timeout > 1000

        if not playerLoadedState[source] then
            warn("^1[CHARACTER LOAD TIMEOUT]^7 " .. GetPlayerName(source) .. " | Event QBCore:Server:PlayerLoaded failed to fire within 10s.")
            -- Don't drop player automatically, but log it clearly
        end

        print("^2[CREATE CHARACTER]^7 " .. GetPlayerName(source) .. " User has created new character")
        RefreshCommand(source)
        utils.LoadHouseData(source)
        SetPlayerRoutingBucket(source, 0)
        spawn.GetApartmentInsideStartSpawnUI(source, newCharData)
        utils.GiveStarterItems(source)

        sendLogs(source, "createNewCharacter", "User has created new character \n" .. json.encode(charData, { indent = true }), "purple", "createcharacter")
    end

    if height or backstory then
        TriggerClientEvent("um-ronin-multicharacter:saveCharacterKVP", source, {
            height = height,
            backstory = backstory
        })
    end

    ratelimit.clearProcess(source, "createCharacter")
end)

lib.callback.register("um-ronin-multicharacter:loadChar", function(source, citizenid)
    if not source or not citizenid then
        return
    end

    if ratelimit.isProcessing(source, "loadChar") then
        return
    end

    local loginResult = Login(source, citizenid)

    if loginResult then
        local timeout = 0
        repeat
            Wait(10)
            timeout = timeout + 1
        until playerLoadedState[source] or timeout > 1000

        if not playerLoadedState[source] then
            warn("^1[PLAYER JOIN TIMEOUT]^7 " .. GetPlayerName(source) .. " | Event QBCore:Server:PlayerLoaded failed to fire within 10s.")
        end

        print("^2[PLAY GAME]^7 " .. GetPlayerName(source) .. " (Citizen ID: " .. citizenid .. ") user has joined the server ")
        RefreshCommand(source)
        SetPlayerRoutingBucket(source, 0)
        utils.LoadHouseData(source)

        local lastPosition = GetPlayer(source).PlayerData
        if lastPosition then
            lastPosition = lastPosition.position
        end
        if not lastPosition then
            lastPosition = { x = 0.0, y = 0.0, z = 0.0, w = 0.0 }
        end

        spawn.GetCharacterReadySpawnUI(source, {
            lastloc = lastPosition,
            citizenid = citizenid
        })

        sendLogs(source, "playgame", "User has joined the server | CitizenID: " .. citizenid, "green", "playgame")
    end

    ratelimit.clearProcess(source, "loadChar")
end)

lib.callback.register("um-ronin-multicharacter:server:deleteCharacter", function(source, citizenid)
    if not source then
        return
    end

    local license, fivemId = PlayerIdentifier(source)

    if ratelimit.isProcessing(source, "deleteCharacter") then
        return
    end

    local ownerIdentifier = MySQL.scalar.await(query.deleteCharacterQuery, { citizenid })

    if ownerIdentifier == license or ownerIdentifier == fivemId then
        local deleted = deletePlayer(citizenid, source)

        if deleted then
            MultiDebug(("Character with citizenid %s has been deleted from the database."):format(citizenid))
            TriggerClientEvent("um-ronin-multicharacter:sessionStarted", source)
            ratelimit.clearProcess(source, "deleteCharacter")
            sendLogs(source, "deleteCharacter", ("Character with citizenid %s has been deleted from the database."):format(citizenid), "green", "deletecharacter")
            return true
        end
    else
        warn(("Player %s attempted to delete character %s without proper authorization."):format(license, citizenid))
        ratelimit.clearProcess(source, "deleteCharacter")
        sendLogs(source, "deleteCharacter", ("Player attempted to delete character %s without proper authorization."):format(citizenid), "red", "exploit")
        return false
    end
end)

lib.callback.register("setBucketRonin", function(source)
    if not source then
        return
    end

    local bucket = math.random(100, 10000)
    SetPlayerRoutingBucket(source, bucket)
end)

RegisterNetEvent("um-ronin-multicharacter:exitGame", function()
    DropPlayer(tostring(source), tostring(locale("exit")))
end)

AddEventHandler("QBCore:Server:PlayerLoaded", function(player)
    Wait(1000)
    local playerId = player.PlayerData.source
    playerLoadedState[playerId] = true
end)

AddEventHandler("QBCore:Server:OnPlayerUnload", function(source)
    playerLoadedState[source] = false
    ratelimit.clearPlayer(source)
end)

AddEventHandler('esx:playerLoaded', function(playerId)
    Wait(1000)
    playerLoadedState[playerId] = true
end)

-- Evento interno: disparado por Login() del bridge ESX
-- para marcar al jugador como listo sin afectar otros recursos
AddEventHandler('um-ronin-multicharacter:internal:playerReady', function(playerId)
    playerLoadedState[playerId] = true
end)

AddEventHandler('playerDropped', function()
    local src = source
    playerLoadedState[src] = false
    ratelimit.clearPlayer(src)
end)
