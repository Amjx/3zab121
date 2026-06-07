return {

    -- Language locale file to use (file in locales folder)
    -- server.cfg convar setr ox:locale en  -- en, tr, de, fr etc.
    -- If empty, default will be 'en'

    -- https://docs.uyuyorumstore.com/scripts/um-ronin-multi/ymterror
    experimentalCrashPreventionForYmtLimits = false,

    -- debug mode for testing
    debug = false,

    -- server.cfg convar to set true if new players should start inside an apartment
    apartmentStart = GetConvar('um:NewPlayerApartmentInsideStart', 'false') == 'true',

    -- If true for multistart need event trigger: 'um-ronin-multicharacter:sessionStarted'
    manuelStart = false,

    -- If true, when a character is selected, last location will be used without showing spawn menu
    onlyLastLocationNoSpawnMenu = false,

    -- If convar(ApartmentInsideStart) false this vector4 will be used for new create character spawn
    defaultSpawnCoords = vec4(-1037.11, -2736.96, 20.17, 323.76),

    -- This for only new character register screen (water effect)
    registerShowCoords = vec4(-1719.23, 4481.87, 9.18, 18.5),

    -- If true, when character is showing, random coord from coords.lua will be used
    randomCoords = true,

    -- Default settings for character selection
    defaultSettings = {
        forceDisableBlurMode = false, --  If true, blur mode will be disabled
        fpsMode = false,
        cinematicMode = false,
        fovPosition = 2,                             -- 1 - close, 2 - far
        animList = { 'texting', 'idle3', 'smoke2' }, -- emote names from your emote menu example list {'texting', 'idle3', 'smoke2'}
        characterPosture = 'side',                   -- 'side' or 'front'
    },

    -- Partner invite feature for multicharacter screen
    -- When enabled, players can invite their partner or friend to appear together in the character selection screen
    -- Command: /partnerinvite [player_id]
    partnerInvite = true,

    -- Character total slot for new character creation
    defaultSlot = 3,

    -- If true, import slot total from Tebex shop (Requires tebex sv_secretKey convar to be set)
    tebexShopImport = false,

    -- Your Tebex store URL 'https://uyuyorumstore.com', leave empty to disable ''
    storeURL = 'https://uyuyorumstore.com',

    -- Logo URL to show in for new character register screen
    logoURL = 'https://r2.fivemanage.com/xAGbYdcTtNkthvTNfzai9/umlogo.webp',

    -- enable/disable credits button and show credits info
    credits = true,

    -- If true, show delete button for all
    deleteButtonForEveryone = true,

    -- Function to hide/show hud during character selection
    hideHud = function(bool)
        if bool then
            --TriggerEvent('example-hud:client:hideHud', true)
            --pcall(function() exports['example-hud']:hideHud(true) end)
            return
        end
        -- TriggerEvent('example-hud:client:hideHud', false)
        -- pcall(function() exports['example-hud']:hideHud(false) end)
    end,

    -- Force weather and time during character selection
    weatherAndTimeForce = {
        enable = true,
        weather = 'XMAS', -- see weather types https://docs.fivem.net/natives/?_0x29B487C359E19889
        hour = 23,        -- 0-23
        minute = 30,      -- 0-59
        handler = function(bool)
            if bool then
                -- Entering character selection: our weather loop handles forced XMAS weather
                -- If using qb-weathersync: TriggerEvent('qb-weathersync:client:DisableSync')
            else
                -- Leaving character selection: tell cd_easytime to instantly re-push server weather/time
                if GetResourceState('cd_easytime') == 'started' then
                    TriggerServerEvent('cd_easytime:SyncMe', true)
                elseif GetResourceState('qb-weathersync') == 'started' then
                    TriggerEvent('qb-weathersync:client:EnableSync')
                end
            end
        end
    },

    -- ![[ ! DON'T CHANGE ]]
    forNewPlayerNoApartmentStartAppearanceShow = 'qb-clothes:client:CreateFirstCharacter'
}
