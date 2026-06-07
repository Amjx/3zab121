local config = require 'config.main'
local debug  = config.debug

if MultiDebug == nil then
    function MultiDebug(...)
        if not debug then return end
        lib.print.info('^6[um-ronin-multicharacter] \n^2', ...)
    end
end

local warned = {}

local function warnOnce(key, message)
    if warned[key] then return end
    warned[key] = true
    lib.print.warn(message)
end

-- PlayerIdentifier: retorna license e license2 do jogador.
-- Sempre definido (fallback seguro para qualquer framework).
if PlayerIdentifier == nil then
    function PlayerIdentifier(src)
        return GetPlayerIdentifierByType(src, 'license'),
               GetPlayerIdentifierByType(src, 'license2')
    end
end

-- RefreshCommand: no-op por padrao; frameworks que precisam sobrescrevem.
if RefreshCommand == nil then
    function RefreshCommand(_) return end
end

-- Retorna o objeto compartilhado do es_extended, ou nil se nao estiver ativo.
local function getEsx()
    if GetResourceState('es_extended') ~= 'started' then return nil end
    local ok, shared = pcall(function()
        return exports['es_extended']:getSharedObject()
    end)
    if not ok then
        warnOnce('esx_shared', '^3[um-ronin-multicharacter]^7 es_extended iniciado mas getSharedObject() falhou.')
        return nil
    end
    return shared
end

-- ─────────────────────────────────────────────────────────────────────────────
-- LADO SERVIDOR
-- ─────────────────────────────────────────────────────────────────────────────
if IsDuplicityVersion() then

    -- Cache de dados de personagem por source, populado pelo Login().
    local playerCache = {}

    -- GetPlayer: retorna objeto compativel com QBCore a partir do cache ou ESX.
    if GetPlayer == nil then
        function GetPlayer(src)
            if playerCache[src] then return playerCache[src] end

            local ESX = getEsx()
            if not ESX then return nil end

            local xPlayer = ESX.GetPlayerFromId(src)
            if not xPlayer then return nil end

            return {
                PlayerData = {
                    source     = src,
                    citizenid  = xPlayer.identifier,
                    identifier = xPlayer.identifier,
                    charinfo   = { firstname = '', lastname = '', birthdate = '', gender = '', nationality = '' },
                    metadata   = {},
                    position   = { x = -1037.11, y = -2736.96, z = 20.17, w = 323.76 },
                    job        = xPlayer.job,
                },
                Functions = {
                    AddItem = function(item, amount, _, metadata)
                        xPlayer.addInventoryItem(item, tonumber(amount) or 1, metadata)
                    end
                }
            }
        end
    end

    -- Login: integra con ESX multichar (Config.Multichar=true).
    -- El identificador usa formato "char{N}:hexlicense" nativo de ESX.
    -- ESX.GetIdentifier devuelve license SIN prefijo ("ae2afbe..." no "license:ae2afbe...").
    -- Por tanto el identifier en DB es: "char1:ae2afbe..." (sin "license:").
    if Login == nil then
        -- ESX.GetIdentifier hace gsub("license:", "") al identifier.
        -- Replicamos exactamente eso para construir el mismo identifier que ESX usara.
        local function esxGetIdentifier(src)
            local id = GetPlayerIdentifierByType(tostring(src), "license")
            if id then return id:gsub("license:", "") end
            return nil
        end

        -- Extrae el prefijo "charN" de un identifier ESX multichar.
        local function charPrefixOf(identifier)
            if not identifier then return "char1" end
            return identifier:match("^(char%d+):") or "char1"
        end

        -- Normaliza el sexo al formato que ESX usa para el INSERT.
        local function normalizeSex(gender)
            if gender == 'female' or gender == 1 or tostring(gender) == '1' then
                return 'f'
            end
            return 'm'
        end

        -- Espera hasta que ESX.Players[src] este poblado (max 8 segundos).
        local function waitForEsxPlayer(src)
            local ESX = getEsx()
            if not ESX then return end
            local deadline = GetGameTimer() + 8000
            while not ESX.GetPlayerFromId(src) and GetGameTimer() < deadline do
                Wait(50)
            end
            if not ESX.GetPlayerFromId(src) then
                lib.print.warn('^3[um-ronin-multicharacter]^7 Timeout esperando ESX.Players para source ' .. tostring(src))
            end
        end

        local function buildCache(src, citizenId, charinfo, position, job)
            local ESX = getEsx()
            return {
                PlayerData = {
                    source     = src,
                    citizenid  = citizenId,
                    identifier = citizenId,
                    charinfo   = charinfo or {},
                    metadata   = {},
                    position   = position or { x = 0.0, y = 0.0, z = 0.0, w = 0.0 },
                    job        = job,
                },
                Functions = {
                    AddItem = function(item, amount, _, metadata)
                        if not ESX then return end
                        local xPlayer = ESX.GetPlayerFromId(src)
                        if xPlayer then
                            xPlayer.addInventoryItem(item, tonumber(amount) or 1, metadata)
                        end
                    end
                }
            }
        end

        function Login(source, citizenid, charData)
            if GetResourceState('es_extended') ~= 'started' then
                warnOnce('login_missing', '^1[um-ronin-multicharacter]^7 Sin framework bridge. Login() no disponible.')
                return false
            end

            -- Usa ESX.GetIdentifier para obtener el hex puro sin prefijo "license:"
            local hexId = esxGetIdentifier(source)
            if not hexId then
                lib.print.warn('[um-ronin-multicharacter] No se pudo obtener license para source ' .. tostring(source))
                return false
            end
            -- license con prefijo (para columna license de getAllCharactersQuery)
            local licenseWithPrefix  = GetPlayerIdentifierByType(tostring(source), 'license') or hexId
            local license2WithPrefix = GetPlayerIdentifierByType(tostring(source), 'license2') or ''

            local spawnCfg = config.defaultSpawnCoords or vec4(-1037.11, -2736.96, 20.17, 323.76)

            if not citizenid and charData then
                -- ── Nuevo personaje ──────────────────────────────────────────────────────
                local cid        = charData.cid or 1
                local charinfo   = charData.charinfo or {}
                local charPrefix = "char" .. cid
                -- Identifier que ESX usara internamente: charN:hexId
                local esxIdentifier = charPrefix .. ":" .. hexId

                -- Delegamos el INSERT a ESX pasando los datos del personaje.
                -- ESX.createESXPlayer hace el INSERT correcto y luego loadESXPlayer.
                local esxData = {
                    firstname   = charinfo.firstname or '',
                    lastname    = charinfo.lastname  or '',
                    dateofbirth = charinfo.birthdate or '',
                    sex         = normalizeSex(charinfo.gender),
                    height      = 182,
                }
                TriggerEvent("esx:onPlayerJoined", source, charPrefix, esxData)
                waitForEsxPlayer(source)

                -- Setear license, license2 y cid (columnas custom que ESX no setea).
                -- Usamos esxIdentifier en WHERE porque ESX lo construye igual: charN:hexId.
                MySQL.query.await(
                    'UPDATE users SET license=?, license2=?, cid=? WHERE identifier=?',
                    { licenseWithPrefix, license2WithPrefix, cid, esxIdentifier }
                )

                local pos = { x = spawnCfg.x, y = spawnCfg.y, z = spawnCfg.z, w = spawnCfg.w }
                local job = { name = 'unemployed', label = 'Unemployed', grade = { name = 'Freelancer', level = 0 } }
                playerCache[source] = buildCache(source, esxIdentifier, {
                    firstname   = charinfo.firstname or '',
                    lastname    = charinfo.lastname  or '',
                    birthdate   = charinfo.birthdate or '',
                    gender      = charinfo.gender    or '0',
                    nationality = '',
                }, pos, job)

                TriggerEvent('um-ronin-multicharacter:internal:playerReady', source)
                return true
            else
                -- ── Personaje existente ──────────────────────────────────────────────────
                local charPrefix = charPrefixOf(citizenid)

                -- Migrar identifier en formato antiguo al formato ESX multichar
                if citizenid and not citizenid:match("^char%d+:") then
                    local newId = "char1:" .. hexId
                    MySQL.query.await('UPDATE users SET identifier=? WHERE identifier=?', { newId, citizenid })
                    citizenid = newId
                    charPrefix = "char1"
                end

                -- ESX carga desde DB, puebla ESX.Players[source] y dispara esx:playerLoaded.
                TriggerEvent("esx:onPlayerJoined", source, charPrefix, nil)
                waitForEsxPlayer(source)

                -- Aseguramos que license/cid esten seteados (por si es una fila sin migrar).
                local cid = tonumber(charPrefix:match("%d+")) or 1
                MySQL.query.await(
                    'UPDATE users SET license=?, license2=?, cid=? WHERE identifier=? AND (license IS NULL OR cid IS NULL)',
                    { licenseWithPrefix, license2WithPrefix, cid, citizenid }
                )

                local ESX = getEsx()
                local xPlayer = ESX and ESX.GetPlayerFromId(source)
                if xPlayer then
                    local jobObj = xPlayer.getJob()
                    playerCache[source] = buildCache(source, xPlayer.identifier, {
                        firstname   = xPlayer.get('firstName')   or '',
                        lastname    = xPlayer.get('lastName')    or '',
                        birthdate   = xPlayer.get('dateofbirth') or '',
                        gender      = xPlayer.get('sex')         or '',
                        nationality = '',
                    }, { x = spawnCfg.x, y = spawnCfg.y, z = spawnCfg.z, w = spawnCfg.w }, {
                        name  = jobObj.name  or 'unemployed',
                        label = jobObj.label or 'Unemployed',
                        grade = { name = jobObj.grade_name or '', level = jobObj.grade or 0 },
                    })
                else
                    playerCache[source] = buildCache(source, citizenid, {},
                        { x = spawnCfg.x, y = spawnCfg.y, z = spawnCfg.z, w = spawnCfg.w },
                        { name = 'unemployed', label = 'Unemployed', grade = { name = '', level = 0 } })
                end

                TriggerEvent('um-ronin-multicharacter:internal:playerReady', source)
                return true
            end
        end
    end

    -- Logout: limpa el cache, guarda datos ESX y limpia ESX.Players[source].
    -- esx:playerLogout es el mecanismo nativo de ESX para cierre de sesion de personaje.
    if Logout == nil then
        function Logout(source)
            playerCache[source] = nil
            TriggerEvent("esx:playerLogout", source)
            return true
        end
    end

    -- Limpa cache cuando el jugador sale del servidor.
    AddEventHandler('playerDropped', function()
        playerCache[source] = nil
    end)

-- ─────────────────────────────────────────────────────────────────────────────
-- LADO CLIENTE
-- ─────────────────────────────────────────────────────────────────────────────
else
    -- GetPlayerData: retorna dados do jogador no formato QBCore para o ESX.
    if GetPlayerData == nil then
        function GetPlayerData()
            if GetResourceState('es_extended') ~= 'started' then
                warnOnce('playerdata_missing', '^1[um-ronin-multicharacter]^7 Nenhum framework bridge carregado. GetPlayerData() indisponivel.')
                return { metadata = {}, charinfo = {} }
            end

            local ESX = getEsx()
            if not ESX then return { metadata = {}, charinfo = {} } end

            local pd = ESX.PlayerData or {}
            return {
                citizenid  = pd.identifier,
                identifier = pd.identifier,
                metadata   = pd.metadata or {},
                charinfo   = {
                    firstname   = pd.firstName   or '',
                    lastname    = pd.lastName    or '',
                    birthdate   = pd.dateofbirth or '',
                    gender      = pd.sex         or '',
                    nationality = pd.nationality or '',
                }
            }
        end
    end
end
