local webhooks = require 'config.webhooks'

local oxLogger = false

local botSettings = {
    name = 'um-ronin-multicharacter',
    image = 'https://files.fivemerr.com/images/d0e1f0c6-7cc5-4fb5-ad91-074d8d165cb7.png'
}

local colors = {
    ['blue'] = 255,
    ['red'] = 16711680,
    ['green'] = 65280,
    ['white'] = 16777215,
    ['black'] = 0,
    ['orange'] = 16744192,
    ['yellow'] = 16776960,
    ['pink'] = 16761035,
    ['lightgreen'] = 65309,
}

---@param src string
---@param idType string
---@return string
local function getIdentifier(src, idType)
    local identifier = GetPlayerIdentifierByType(src, idType) or 'unknown'
    return identifier:gsub(idType .. ':', '') or identifier
end

---@param src string
---@return string
local function userInformation(src)
    local information = string.format(
        "### 👤 User Information\n**[id]: **%s\n**[name]: **%s\n**[discord]: **%s\n**[steam]: **%s\n**[license]: **%s\n**[license2]: **%s\n",
        tostring(src),
        GetPlayerName(src),
        getIdentifier(src, 'discord'),
        getIdentifier(src, 'steam'),
        getIdentifier(src, 'license'),
        getIdentifier(src, 'license2')
    )
    return information
end

---@param data table
---@async
local function sendWebHook(data)
    local timestamp = os.date("%c")

    local message = {
        {
            ["color"] = data.color,
            ["title"] = data.title,
            ["description"] = data.message,
            ["footer"] = {
                ["text"] = timestamp .. ' | version ronin',
                ["icon_url"] = botSettings.image,
            },
        }
    }

    local jsonData = json.encode({
        username = botSettings.name,
        avatar_url = botSettings.image,
        embeds = message
    })

    SetTimeout(1000, function()
        PerformHttpRequest(data.link, function(_, _, _)
        end, 'POST', jsonData, { ['Content-Type'] = 'application/json' })
    end)
end

---@param src string
---@param type string
---@param message string
---@param color? string
---@param webhook? string
local function sendLogs(src, type, message, color, webhook)
    if oxLogger then
        return lib.logger(src, type, userInformation(src) .. '### 💬 Message \n ### ' .. message .. ' \n')
    end

    local webhookLink = webhooks[webhook]
    if not webhookLink or webhookLink == '' then return warn('Webhook link is missing: ' .. webhook) end

    local data = {
        link = webhookLink,
        title = '📌 [' .. type .. ']',
        color = colors[color] or colors['blue'],
        message = userInformation(src) .. '### 💬 Message \n ### ' .. message .. ' \n'
    }

    sendWebHook(data)
end

CreateThread(function()
    if GetConvar('datadog:key', '') ~= '' then
        oxLogger = true
    elseif GetConvar('ox:logger', '') ~= '' then
        oxLogger = true
    end
end)

return {
    sendLogs = sendLogs
}
