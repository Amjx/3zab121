local weatherConfig = require("config.main").weatherAndTimeForce
local kvpGet = require("modules.client.kvp").get

local savedWeather = kvpGet("weather")
local savedClock = kvpGet("clock") or {}

local rainLevel = 0.0
local currentRainLevel = 0.0
local isWeatherLoopActive = false

local weatherSettings = {}

weatherSettings.weather = savedWeather
if savedWeather == "select" or not savedWeather then
    weatherSettings.weather = weatherConfig.weather
end

weatherSettings.hour = savedClock.hour or weatherConfig.hour
weatherSettings.minute = savedClock.minute or weatherConfig.minute

function HasCustomWeather()
    return savedWeather ~= "select"
end

function GetRainLevelForWeather(weatherType)
    if weatherType == "RAIN" then
        rainLevel = 0.2
    elseif weatherType == "THUNDER" then
        rainLevel = 0.5
    else
        rainLevel = 0.0
    end
    return rainLevel
end

function ApplyWeatherType(weatherType)
    if not weatherType then
        return
    end

    currentRainLevel = GetRainLevelForWeather(weatherType)

    ClearOverrideWeather()
    ClearWeatherTypePersist()
    SetRainLevel(currentRainLevel)
    SetWeatherTypePersist(weatherType)
    SetWeatherTypeNow(weatherType)
    SetWeatherTypeNowPersist(weatherType)
end

function StartWeatherLoop()
    if isWeatherLoopActive then
        return
    end

    isWeatherLoopActive = true

    CreateThread(function()
        while isWeatherLoopActive and weatherSettings.weather do
            SetRainLevel(currentRainLevel)
            SetWeatherTypePersist(weatherSettings.weather)
            SetWeatherTypeNow(weatherSettings.weather)
            SetWeatherTypeNowPersist(weatherSettings.weather)
            Wait(0)
        end
    end)
end

function WeatherAndTime(shouldActivate)
    local hasClockSettings = weatherSettings.hour and weatherSettings.minute
    local hasWeatherSetting = weatherSettings.weather

    if not weatherConfig.enable then
        if not HasCustomWeather() then
            return
        end
    end

    if not hasClockSettings and not hasWeatherSetting then
        return
    end

    weatherConfig.handler(shouldActivate)

    if shouldActivate then
        if hasClockSettings then
            NetworkOverrideClockTime(weatherSettings.hour, weatherSettings.minute, 0)
        end

        if hasWeatherSetting then
            ApplyWeatherType(weatherSettings.weather)
            StartWeatherLoop()
        end
    else
        isWeatherLoopActive = false
        -- Limpia el weather forzado para que el script de clima del servidor retome el control
        ClearOverrideWeather()
        ClearWeatherTypePersist()
        SetRainLevel(0.0)
    end
end

RegisterNUICallback("setClockTime", function(data, cb)
    weatherSettings.hour = data.hour
    weatherSettings.minute = data.minute
    NetworkOverrideClockTime(data.hour, data.minute, 0)
    cb("ok")
end)

RegisterNUICallback("setWeatherType", function(data, cb)
    weatherSettings.weather = data.weather
    ApplyWeatherType(data.weather)
    cb("ok")
end)

RegisterNUICallback("setFilter", function(data, cb)
    SetTimecycleModifier(data.filter)
    SetTimecycleModifierStrength(1.0)
    cb("ok")
end)
