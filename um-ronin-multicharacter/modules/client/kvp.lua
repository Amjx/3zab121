local cfg = require 'config.main'
local KVP_KEY = 'multicharacter_settings'
local CHARACTER_SETTINGS_KVP_KEY = 'characterSettings'

local kvp = {}

local function deepMerge(target, source)
    for key, value in pairs(source) do
        if type(value) == 'table' and type(target[key]) == 'table' then
            deepMerge(target[key], value)
        else
            target[key] = value
        end
    end
    return target
end

local function defaultSettings()
    local register = require 'config.register'
    return {
        fpsMode = cfg.defaultSettings.fpsMode,
        cinematicMode = cfg.defaultSettings.cinematicMode,
        fov = cfg.defaultSettings.fovPosition,
        tebexShop = cfg.tebexShopImport,
        heightStatus = register.height,
        backstoryStatus = register.backstory and register.backstory.enable or false,
        weather = cfg.weatherAndTimeForce.enable and cfg.weatherAndTimeForce.weather or 'select',
        clock = {
            hour = cfg.weatherAndTimeForce.enable and cfg.weatherAndTimeForce.hour or GetClockHours(),
            minute = cfg.weatherAndTimeForce.enable and cfg.weatherAndTimeForce.minute or GetClockMinutes(),
        },
        volume = 50,
        characterSettings = {},
    }
end

---@param citizenid string
---@param charSettings table | nil
---@return table
local function createCharSettings(citizenid, charSettings)
    if not charSettings then
        charSettings = {}
    end
    if not charSettings[citizenid] then
        charSettings[citizenid] = {}
    end
    return charSettings
end

---@return table | nil
function kvp.getAll()
    local value = GetResourceKvpString(KVP_KEY)
    if value then
        local success, decoded = pcall(json.decode, value)
        if success and type(decoded) == 'table' then
            return decoded
        end
    end
    return nil
end

---@return table
function kvp.getSettings()
    local defaults = defaultSettings()
    local saved = kvp.getAll()

    if not saved then return defaults end

    for key, defaultValue in pairs(defaults) do
        if saved[key] == nil then
            saved[key] = defaultValue
        end
    end

    return saved
end

---@param key string
---@return any
function kvp.get(key)
    local settings = kvp.getAll()
    if settings then
        return settings[key]
    end
    return nil
end

---@param settings table
---@param mergeWithOld? boolean
function kvp.saveAll(settings, mergeWithOld)
    if type(settings) ~= 'table' then return false end

    if mergeWithOld then
        local oldSettings = kvp.getAll() or {}
        settings = deepMerge(oldSettings, settings)
    end

    MultiDebug('Saving all settings to KVP:', settings)

    local success, encoded = pcall(json.encode, settings)
    if success then
        SetResourceKvp(KVP_KEY, encoded)
    end
end

---@param key string
---@param value any
function kvp.set(key, value)
    local settings = kvp.getAll() or {}
    settings[key] = value
    kvp.saveAll(settings)
end

---comment
---@param action string
---@param citizenId string
---@param newPartnerCitizenid? string
---@param scenarioType? string
---@return {citizenid: string, type: string}?
function kvp.partnerCitizenId(action, citizenId, newPartnerCitizenid, scenarioType)
    if not cfg.partnerInvite or not citizenId then return nil end

    local KEY = CHARACTER_SETTINGS_KVP_KEY
    local charSettings = kvp.get(KEY)

    if action == 'get' then
        return charSettings and charSettings[citizenId]?.partner
    elseif action == 'set' then
        charSettings = createCharSettings(citizenId, charSettings)
        charSettings[citizenId].partner = { citizenid = newPartnerCitizenid, type = scenarioType }
        kvp.set(KEY, charSettings)
    elseif action == 'remove' then
        if charSettings and charSettings[citizenId] then
            charSettings[citizenId].partner = nil
            kvp.set(KEY, charSettings)
        end
    end
end

---@param citizenId string
---@param height number | nil
---@param backstory string | nil
function kvp.setHeightOrBackstory(citizenId, height, backstory)
    if not citizenId then return end
    if not height and not backstory then return end
    local KEY = CHARACTER_SETTINGS_KVP_KEY
    local charSettings = kvp.get(KEY)
    charSettings = createCharSettings(citizenId, charSettings)
    charSettings[citizenId].height = height or nil
    charSettings[citizenId].backstory = backstory or nil
    kvp.set(KEY, charSettings)
end

function kvp.reset()
    DeleteResourceKvp(KVP_KEY)
end

RegisterNUICallback('resetSettings', function(_, cb)
    kvp.reset()
    cb('ok')
end)

RegisterNUICallback('saveAllKVP', function(data, cb)
    if data then
        SetTimeout(500, function()
            kvp.saveAll(data, true)
            MultiDebug('Settings saved after delay')
        end)
    end
    cb('ok')
end)

return kvp
