local slots = {}

--[[
    this license based extra slot configuration
    if you are using Discord role-based extra slots, this will be disabled.
]]
slots.list = {
    -- {license = "license2:d2e126c8342d33460756", slot = 9},
    -- {license = "license:xxxx2", slot = 7},
    -- {license = "license:xxxx3", slot = 3},
    -- {license = "license:xxxx4", slot = 4},
    -- {license = "license:xxxx5", slot = 1},
}

--[[
    if Discord role-based extra slots are used, add role IDs and slot counts here
    need add convar in [server.cfg]
    set um:DISCORD_BOT_TOKEN "your_bot_token_here"
    set um:DISCORD_GUILD_ID "your_guild_id_here"
]]
slots.discordRoles = {
    --{ id = "1372592152718213232", slot = 1 },
    -- { id = "roleid", slot = 3 },
    -- { id = "roleid", slot = 4 },
    -- { id = "roleid", slot = 5 },
    -- { id = "roleid", slot = 6 },
}

--[[
    if deleteButtonForEveryone is false in config - main.lua,
    you can enable the licence-based delete button here.
]]
slots.deleteCharacterAccess = {
    --"license:xxxxx1",
    --"license2:xxxxx3",
}

return slots
