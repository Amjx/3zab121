local config = require 'config.main'
local defaultSlots = config.defaultSlot
local deleteButton = config.deleteButtonForEveryone
local tebexShopImport = config.tebexShopImport

local query = require 'modules.server.query'
local slots = require 'config.extraslot'

local discordConfig = {
    guild_id = GetConvar('um:DISCORD_GUILD_ID', ''),
    bot_token = GetConvar('um:DISCORD_BOT_TOKEN', ''),
}

local function RequestDiscordExtraSlots(src)
    local discord = GetPlayerIdentifierByType(src, 'discord') or 'undefined'

    if discord == 'undefined' then
        warn('^1Discord ID not found')
        return 0
    end

    if discord:find('discord' .. ':') then
        discord = discord:gsub('discord' .. ':', '')
    end

    local status, data = PerformHttpRequestAwait(
        ("https://ptb.discord.com/api/v10/guilds/%s/members/%s"):format(discordConfig.guild_id, discord), 'GET', '', {
            ['Content-Type'] = 'application/json',
            ['Authorization'] = ('Bot %s'):format(discordConfig.bot_token)
        })

    if status ~= 200 then
        return 0
    end

    if data then
        local responseData = json.decode(data)
        local roles = responseData.roles or {}
        for i = 1, #roles do
            local role = roles[i]
            for j = 1, #slots.discordRoles do
                local slotRole = slots.discordRoles[j]
                if tostring(role) == tostring(slotRole.id) then
                    return slotRole.slot
                end
            end
        end
    end

    return 0
end

function GetTotalCharacterSlotAndDeleteAccess(src)
    if not src then return defaultSlots, deleteButton end

    local license, license2 = PlayerIdentifier(src)

    local extraSlot = 0

    if tebexShopImport then
        local tebexSlots = MySQL.scalar.await(query.tebexSlotsQuery, { license, license2 }) or 0
        extraSlot = extraSlot + tebexSlots
    end

    if next(slots.discordRoles) then
        extraSlot = extraSlot + RequestDiscordExtraSlots(src)
    elseif next(slots.list) then
        for i = 1, #slots.list do
            local v = slots.list[i]
            if v.license == license2 or v.license == license then
                extraSlot = extraSlot + v.slot
                break
            end
        end
    end

    local hasDeleteAccess = deleteButton

    if not hasDeleteAccess then
        if next(slots.deleteCharacterAccess) then
            for i = 1, #slots.deleteCharacterAccess do
                local listItem = slots.deleteCharacterAccess[i]
                if listItem == license or listItem == license2 then
                    hasDeleteAccess = true
                    break
                end
            end
        end
    end

    MultiDebug(('Total extra slots for license %s / %s : %d'):format(license, license2, extraSlot + defaultSlots))
    return extraSlot + defaultSlots, hasDeleteAccess
end
