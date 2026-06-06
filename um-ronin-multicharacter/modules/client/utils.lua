local locations = require 'config.coords'
local animList = require 'config.main'.defaultSettings.animList

local utils = {}
local publicLocations = {}
local groupLocations = {}
local fixedLocation = {}

local EmoteSystem = {
    RPEMOTES_REBORN = 'rpemotes-reborn',
    RPEMOTES = 'rpemotes',
    SCULLY = 'scully_emotemenu',
    NATIVE = 'native'
}

local activeEmoteSystem = EmoteSystem.NATIVE

---@param emoteName string
local function executeEmote(emoteName)
    if activeEmoteSystem == EmoteSystem.RPEMOTES_REBORN then
        pcall(function() exports["rpemotes-reborn"]:EmoteCommandStart(emoteName) end)
    elseif activeEmoteSystem == EmoteSystem.RPEMOTES then
        pcall(function() exports["rpemotes"]:EmoteCommandStart(emoteName) end)
    elseif activeEmoteSystem == EmoteSystem.SCULLY then
        pcall(function() exports.scully_emotemenu:playEmoteByCommand(emoteName) end)
    else
        ExecuteCommand(('e %s'):format(emoteName))
    end
end

---@param location table
---@return table|nil camOptions
local function getCamOptions(location)
    if location.mode ~= 3 then return nil end
    return {
        camCoords = location.camCoords,
        fov = location?.fov,
        focusOffset = location?.focusOffset,
        blurOptions = location?.blurOptions,
    }
end

--- @param jobName string|nil
--- @param gangName string|nil
--- @param random boolean|nil
---@return table selected
local function getRandomCoords(jobName, gangName, random)
    if jobName and groupLocations[jobName] then
        local jobLocs = groupLocations[jobName]
        local randomIndex = random and math.random(#jobLocs) or 1
        return jobLocs[randomIndex]
    end

    if gangName and groupLocations[gangName] then
        local gangLocs = groupLocations[gangName]
        local randomIndex = random and math.random(#gangLocs) or 1
        return gangLocs[randomIndex]
    end

    if next(fixedLocation) and not random then
        return fixedLocation
    end

    local randomPublicLocation = random and math.random(#publicLocations) or 1
    local selected = publicLocations[randomPublicLocation]

    fixedLocation = selected

    return selected
end

function utils.getPedDistance(coords, ped)
    local pedCoords = GetEntityCoords(ped)
    local locationCoords = vector3(coords.x, coords.y, coords.z)
    return #(pedCoords - locationCoords)
end

function utils.reqAndSetPlayer(coords, ped)
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)

    SetEntityVisible(ped, false, false)
    SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityHeading(ped, coords.w or 0.0)

    local time = GetGameTimer()

    while (not HasCollisionLoadedAroundEntity(ped) and (GetGameTimer() - time) < 5000) do
        RequestCollisionAtCoord(coords.x, coords.y, coords.z)
        Wait(0)
    end
end

---@param model string|number
---@return number hash
function utils.modelToJoaat(model)
    local asNumber = tonumber(model)
    if asNumber then return asNumber end

    if model == 'mp_m_freemode_01' or model == 'm' or model == 0 then
        return joaat('mp_m_freemode_01')
    end

    if model == 'mp_f_freemode_01' or model == 'f' or model == 1 then
        return joaat('mp_f_freemode_01')
    end

    return joaat(model)
end

function utils.setModel(model)
    model = utils.modelToJoaat(model)
    lib.requestModel(model, 300000)
    SetPlayerModel(cache.playerId, model)
    Wait(200)
    SetModelAsNoLongerNeeded(model)
    MultiDebug('[setModel] Model set successfully: ' .. tostring(model))
end

function utils.getSelectedCoords(jobName, gangName, forceRandom)
    local selected = getRandomCoords(jobName, gangName, forceRandom)
    local options = getCamOptions(selected)
    return {
        coords = selected.coords,
        camMode = selected.mode or 1,
        camOptions = options,
        emote = selected.emote,
    }
end

function utils.getRandomEmote()
    local emoteList = animList
    if not next(emoteList) then return nil end
    local randomIndex = math.random(#emoteList)
    return emoteList[randomIndex]
end

--- Cancel any active emote on the player ped
function utils.cancelEmote()
    local ped = PlayerPedId()

    -- Önce 3rd party emote sistemlerini dene
    if activeEmoteSystem == EmoteSystem.RPEMOTES_REBORN then
        pcall(function() exports["rpemotes-reborn"]:EmoteCancel(true) end)
    elseif activeEmoteSystem == EmoteSystem.RPEMOTES then
        pcall(function() exports["rpemotes"]:EmoteCancel(true) end)
    elseif activeEmoteSystem == EmoteSystem.SCULLY then
        pcall(function() exports.scully_emotemenu:cancelEmote(false) end)
    end

    if IsPedUsingAnyScenario(ped) then
        SetPedShouldPlayImmediateScenarioExit(ped)
        ClearPedTasksImmediately(ped)
    else
        ClearPedTasks(ped)
    end
end

---@param data { animName?: string, scenario?: string }
function utils.playEmote(data)
    if not data?.animName and not data?.scenario then return end

    if data?.scenario then
        return TaskStartScenarioInPlace(PlayerPedId(), data.scenario, 0, true)
    end

    if data?.animName then
        executeEmote(data.animName)
    end
end

-- locations init
CreateThread(function()
    for i = 1, #locations do
        local loc = locations[i]
        if loc.group then
            local groups = type(loc.group) == "table" and loc.group or { loc.group }
            for j = 1, #groups do
                local groupName = groups[j]
                if not groupLocations[groupName] then
                    groupLocations[groupName] = {}
                end
                groupLocations[groupName][#groupLocations[groupName] + 1] = loc
            end
        else
            publicLocations[#publicLocations + 1] = loc
        end
    end

    if GetResourceState('rpemotes-reborn') == 'started' then
        activeEmoteSystem = EmoteSystem.RPEMOTES_REBORN
    elseif GetResourceState('rpemotes') == 'started' then
        activeEmoteSystem = EmoteSystem.RPEMOTES
    elseif GetResourceState('scully_emotemenu') == 'started' then
        activeEmoteSystem = EmoteSystem.SCULLY
    else
        activeEmoteSystem = EmoteSystem.NATIVE
    end
end)

return utils
