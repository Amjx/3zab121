local tebexShop = require 'config.main'.tebexShopImport

if not tebexShop then return end

if GetConvar('sv_tebexSecret', '') == '' then
    warn('Tebex secret is not set! Please set sv_tebexSecret convar in server.cfg')
    return
end

local sendLogs = require 'modules.server.log'.sendLogs

local rateLimit = {}
local maxAttempts = 5
local resetRateLimitTime = 60 * 1000

local function checkRateLimit(source)
    local data = rateLimit[source]

    if not data then
        rateLimit[source] = { attempts = 0, resetAt = nil }
        return true
    end

    local now = GetGameTimer()

    if data.resetAt and now >= data.resetAt then
        rateLimit[source] = { attempts = 0, resetAt = nil }
        return true
    end

    -- Deneme hakkı kaldıysa izin ver
    if data.attempts < maxAttempts then
        return true
    end

    -- Rate limited
    return false
end

local function incrementAttempt(source)
    local data = rateLimit[source]

    if not data then
        rateLimit[source] = { attempts = 1, resetAt = nil }
        return
    end

    data.attempts += 1

    -- 5. denemede rate limit başlat
    if data.attempts >= maxAttempts then
        local now = GetGameTimer()
        data.resetAt = now + resetRateLimitTime
    end
end


lib.callback.register('um-ronin-multicharacter:getPurchaseHistory', function(source)
    if not source then return end

    local license = GetPlayerIdentifierByType(source, 'license2')

    if not license then
        return
    end

    local slots = MySQL.query.await([[
        SELECT transaction_id, slots_count, created_at FROM ronin_slots
        WHERE license = ? AND claim = 1
        ORDER BY created_at DESC
    ]], { license })

    return slots or {}
end)

lib.callback.register('um-ronin-multicharacter:redeem', function(source, transid)
    if not source then return end

    if not checkRateLimit(source) then
        local remaining = math.ceil((rateLimit[source].resetAt - GetGameTimer()) / 1000)
        return false, locale('redeem.error.rate_limited', remaining)
    end

    if type(transid) ~= 'string' then
        incrementAttempt(source)
        return false, locale('redeem.error.invalid_transaction_id')
    end

    transid = transid:gsub('%s+', '')

    if transid == '' or not transid:match("^tbx%-[a-zA-Z0-9%-]+$") then
        incrementAttempt(source)
        return false, locale('redeem.error.invalid_transaction_id')
    end

    local slot = MySQL.single.await([[
        SELECT id, slots_count
        FROM ronin_slots
        WHERE transaction_id = ? AND claim = 0
        LIMIT 1
    ]], { transid })

    if not slot then
        incrementAttempt(source)
        return false, locale('redeem.error.transaction_not_found_or_already_claimed')
    end


    local license = GetPlayerIdentifierByType(source, 'license2')

    if not license then
        return false, 'license_not_found'
    end

    MySQL.update.await([[
        UPDATE ronin_slots
        SET claim = 1, license = ?
        WHERE id = ?
    ]], { license, slot.id })


    rateLimit[source] = nil

    sendLogs(source, 'tebex', 'User has redeemed a Tebex transaction | Transaction ID: ' .. transid, 'green', 'tebex')
    return slot.slots_count, locale('redeem.success')
end)

--[[
    Don't change command name, used in tebex shop import
]]
RegisterCommand('addNewCharacterSlot', function(source, args)
    if source ~= 0 then return end

    local data = json.decode(args[1]) or {}

    if not data.transid then
        return warn('No data provided to add new character slot')
    end

    Wait(2000)

    local exists = MySQL.scalar.await([[
        SELECT 1 FROM ronin_slots
        WHERE transaction_id = ?
        LIMIT 1
    ]], { data.transid })

    if exists then
        return warn('Transaction ID already claim or exists: ' .. data.transid)
    end

    MySQL.insert.await([[
        INSERT INTO ronin_slots (transaction_id, slots_count)
        VALUES (?, ?)
    ]], { data.transid, tonumber(data.extraSlot) })
end, false)


MySQL.ready(function()
    MySQL.execute([[
            CREATE TABLE IF NOT EXISTS ronin_slots (
                id INT AUTO_INCREMENT PRIMARY KEY,
                transaction_id VARCHAR(100) NOT NULL UNIQUE,
                slots_count INT NOT NULL,
                license VARCHAR(100) DEFAULT NULL,
                claim BOOLEAN DEFAULT FALSE,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        ]])
end)
