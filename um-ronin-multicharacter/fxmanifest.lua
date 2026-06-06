fx_version 'cerulean'
game 'gta5'

name "um-ronin-multicharacter"
author "um"
series "ronin"
version "v0.2.5"
description [[
        🐼 - uyuyorumstore
        Ronin Multicharacter
]]

ox_lib 'locale'

ui_page 'web/build/index.html'

files {
    -- Lang
    'locales/*.json',
    -- Config
    'config/coords.lua',
    'config/main.lua',
    'config/register.lua',
    'config/credits.lua',
    -- Modules
    'modules/client/kvp.lua',
    'modules/client/utils.lua',
    -- Web
    'web/build/**',
}

shared_scripts {
    '@ox_lib/init.lua',
    'bridge/framework/*.lua',
}

client_scripts {
    'bridge/appearance.lua',
    'bridge/compat.lua',
    'modules/client/camera.lua',
    'modules/client/modescenario.lua',
    'modules/client/weather.lua',
    'client/*.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/getskin.lua',
    'modules/server/validator.lua',
    'server/*.lua',
}


escrow_ignore {
    'locales/*.json',
    'config/*.lua',
    'bridge/**',

    'client/event.lua',
    'client/invite.lua',

    'modules/client/kvp.lua',
    'modules/client/utils.lua',

    'modules/server/chardel.lua',
    'modules/server/log.lua',
    'modules/server/query.lua',
    'modules/server/ratelimit.lua',
    'modules/server/utils.lua',

    'server/commands.lua',
    'server/slot.lua',
    'server/tebex.lua',
    'server/invite.lua'
}

dependencies {
    '/server:17000',
    'ox_lib',
    '/onesync'
}


lua54 'yes'
use_experimental_fxv2_oal 'yes'
nui_callback_strict_mode 'true'

provides { 'qb-multicharacter', 'um-multicharacter' }

dependency '/assetpacks'
