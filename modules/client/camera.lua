local defaultSettings = require("config.main").defaultSettings

local currentCamera = nil
local dofActive = false
local withPartner = false
local partnerType = "cp"
local currentMode = 1

local CameraMode = {
    FRONT = 1,
    BACK = 2,
    FREE = 3,
    NEW = 4
}

function lerp(from, to, t)
    return from + (to - from) * t
end

function getFov()
    local kvp = require("modules.client.kvp")
    local fovSetting = kvp.get("fov")

    if not fovSetting then
        fovSetting = defaultSettings.fovPosition
    end

    if fovSetting == 1 then
        return withPartner and 20 or 12
    elseif fovSetting == 2 then
        return withPartner and 30 or 16
    end

    return 12
end

function animateCamera(cam, targetPos, targetFov, duration, p, lookAtCoord)
    local startTime = GetGameTimer()
    local startPos = GetCamCoord(cam)
    local startFov = GetCamFov(cam)

    CreateThread(function()
        while true do
            local elapsed = GetGameTimer() - startTime
            if not (elapsed < duration) then
                break
            end

            local progress = (GetGameTimer() - startTime) / duration

            local interpPos = vector3(
                lerp(startPos.x, targetPos.x, progress),
                lerp(startPos.y, targetPos.y, progress),
                lerp(startPos.z, targetPos.z, progress)
            )

            local interpFov = lerp(startFov, targetFov, progress)

            SetCamCoord(cam, interpPos.x, interpPos.y, interpPos.z)
            SetCamFov(cam, interpFov)

            if lookAtCoord then
                PointCamAtCoord(cam, lookAtCoord.x, lookAtCoord.y, lookAtCoord.z)
            end

            Wait(0)
        end

        SetCamCoord(cam, targetPos.x, targetPos.y, targetPos.z)
        SetCamFov(cam, targetFov)

        if p then
            p:resolve(true)
        end
    end)
end

function smoothDestroyCamera(cam)
    local camCoords = GetCamCoord(cam)
    local pedCoords = GetEntityCoords(cache.ped)

    local dx = camCoords.x - pedCoords.x
    local dy = camCoords.y - pedCoords.y
    local dz = camCoords.z - pedCoords.z
    local distance = math.sqrt(dx * dx + dy * dy + dz * dz)

    local zoomStep = 0.3
    local zoomTarget = vector3(
        camCoords.x + (dx / distance) * zoomStep,
        camCoords.y + (dy / distance) * zoomStep,
        camCoords.z + (dz / distance) * zoomStep * 0.3
    )

    local zoomDuration = 5000
    local destroyPromise = promise.new()

    local lookAtTarget = vector3(pedCoords.x, pedCoords.y, pedCoords.z + 0.5)

    animateCamera(cam, zoomTarget, 20, zoomDuration, destroyPromise, lookAtTarget)

    CreateThread(function()
        Citizen.Await(destroyPromise)
        SetCamActive(cam, false)
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(cam, true)
        cam = nil
        MultiDebug("Camera destroyed (smooth)")
    end)
end

function applyDepthOfField(cam, blurOptions)
    if defaultSettings.forceDisableBlurMode then
        return
    end

    SetCamUseShallowDofMode(cam, true)
    SetCamNearDof(cam, (blurOptions and blurOptions.near) or 0.5)

    local farDof
    if blurOptions and blurOptions.far then
        farDof = blurOptions.far
    else
        farDof = withPartner and 3.0 or 2.0
    end
    SetCamFarDof(cam, farDof)

    SetCamDofStrength(cam, 1)
    _ENV["SetCamDofMaxNearInFocusDistanceBlendLevel"](cam, 0.5)
    SetCamDofMaxNearInFocusDistance(cam, 1.5)
    SetCamDofFocusDistanceBias(cam, 2.0)

    dofActive = true

    CreateThread(function()
        while dofActive and DoesCamExist(cam) do
            SetUseHiDof()
            Wait(0)
        end
        dofActive = false
    end)
end

local cameraBuilders = {}

cameraBuilders[CameraMode.FRONT] = function()
    local posture = defaultSettings.characterPosture or "side"

    local offsetX = -1.5
    local offsetY = 1.5
    local offsetZ = 0.6
    local focusX = 0.3
    local focusY = 0.0
    local focusZ = 0.6

    if withPartner then
        if partnerType == "cp" then
            offsetX = -1.2
            offsetY = 1.8
            offsetZ = 0.6
            focusX = 0.7
            focusY = 0.0
            focusZ = 0.6
        elseif partnerType == "bff" then
            offsetX = 0.5
            offsetY = 2.1
            offsetZ = 0.5
            focusX = 0.5
            focusY = 0.0
            focusZ = 0.4
        end
    end

    local camPos = GetOffsetFromEntityInWorldCoords(cache.ped, offsetX, offsetY, offsetZ)
    local focusPoint = GetOffsetFromEntityInWorldCoords(cache.ped, focusX, focusY, focusZ)

    if posture == "front" then
        local heading = GetEntityHeading(cache.ped)
        local rotationAngle = math.deg(math.atan(-offsetX, offsetY))
        SetEntityHeading(cache.ped, heading + rotationAngle)
        Wait(50)
    end

    return {
        camPos = camPos,
        focusPoint = focusPoint,
        fov = getFov(),
        useBlur = true,
        debugName = "FRONT"
    }
end

cameraBuilders[CameraMode.BACK] = function()
    DoScreenFadeOut(0)

    while not IsScreenFadedOut() do
        Wait(0)
    end

    local heading = GetEntityHeading(cache.ped)
    local newHeading = (heading + 180) % 360
    SetEntityHeading(cache.ped, newHeading)
    Wait(100)

    local partnerPed = withPartner and partnerType == "cp" and GetPartnerPed()

    local focusOffsetX = -0.3
    if partnerPed then
        if DoesEntityExist(partnerPed) then
            local playerModel = GetEntityModel(cache.ped)
            if playerModel == -1667301416 then
                focusOffsetX = -0.8
            end
        end
    end

    local camPos = GetOffsetFromEntityInWorldCoords(cache.ped, -1.0, -2.0, 0.6)
    local focusPoint = GetOffsetFromEntityInWorldCoords(cache.ped, focusOffsetX, 0.0, 0.5)

    return {
        camPos = camPos,
        focusPoint = focusPoint,
        fov = 30,
        useBlur = true,
        debugName = "BACK",
        needsFadeIn = true
    }
end

cameraBuilders[CameraMode.FREE] = function(options)
    if not (options and options.camCoords) then
        warn("CreateCamera FREE mode: camCoords is required!")
        return nil
    end

    local pedCoords = GetEntityCoords(cache.ped)
    local focusOffset = options.focusOffset or vector3(0.0, 0.0, 0.5)

    local camPos = vector3(options.camCoords.x, options.camCoords.y, options.camCoords.z)
    local focusPoint = vector3(
        pedCoords.x + focusOffset.x,
        pedCoords.y + focusOffset.y,
        pedCoords.z + focusOffset.z
    )

    return {
        camPos = camPos,
        camHeading = options.camCoords.w,
        focusPoint = focusPoint,
        fov = options.fov or getFov(),
        useBlur = true,
        blurOptions = options.blurOptions,
        debugName = "FREE"
    }
end

cameraBuilders[CameraMode.NEW] = function()
    local pedCoords = GetEntityCoords(PlayerPedId())
    local heightOffset = 25.0

    local camPos = vector3(pedCoords.x, pedCoords.y - 5.0, pedCoords.z + heightOffset)

    return {
        camPos = camPos,
        focusPoint = pedCoords,
        fov = 15,
        useBlur = false,
        debugName = "NEW (bird's eye)"
    }
end

function CamCreate(mode, camOptions, isInstant)
    local camPromise = promise.new()

    local builder = cameraBuilders[mode]
    if not builder then
        warn("CreateCamera: Invalid camera mode:", mode)
        camPromise:resolve(false)
        return camPromise
    end

    local camData = builder(camOptions)
    if not camData then
        camPromise:resolve(false)
        return camPromise
    end

    local jitter = 0.3
    local startPos = vector3(
        camData.camPos.x + jitter * 0.5,
        camData.camPos.y - jitter,
        camData.camPos.z + jitter * 0.2
    )
    local startFov = camData.fov - 3

    local initialPos = isInstant and camData.camPos or startPos
    local initialFov = isInstant and camData.fov or startFov

    local cam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", initialPos.x, initialPos.y, initialPos.z, 0, 0, 0, initialFov, true, 2)
    currentCamera = cam

    if camData.camHeading then
        SetCamRot(currentCamera, 0.0, 0.0, camData.camHeading, 2)
    end

    PointCamAtCoord(currentCamera, camData.focusPoint.x, camData.focusPoint.y, camData.focusPoint.z)
    RenderScriptCams(true, true, 0, true, true)

    if camData.needsFadeIn then
        DoScreenFadeIn(10)
    end

    local animDelay = isInstant and 0 or 5000

    if not isInstant then
        animateCamera(currentCamera, camData.camPos, camData.fov, animDelay, camPromise, camData.focusPoint)
    end

    CreateThread(function()
        local retries = 0
        while not DoesCamExist(currentCamera) and retries < 100 do
            retries = retries + 1
            Wait(50)
        end

        if not DoesCamExist(currentCamera) then
            camPromise:resolve(false)
            return
        end

        if camData.useBlur then
            applyDepthOfField(currentCamera, camData.blurOptions)
        end

        Wait(animDelay)
        MultiDebug("Camera " .. camData.debugName .. " mode created")
        camPromise:resolve(true)
    end)

    return camPromise
end

function CamDestroy(smooth)
    if not currentCamera then
        return
    end

    dofActive = false

    if DoesCamExist(currentCamera) then
        if smooth then
            smoothDestroyCamera(currentCamera)
            return
        end

        SetCamActive(currentCamera, false)
        RenderScriptCams(false, true, 0, true, true)
        DestroyCam(currentCamera, true)
        currentCamera = nil
        withPartner = false
        MultiDebug("Camera destroyed")
    end
end

function SetWithPartnerMode(enabled, type)
    withPartner = enabled
    partnerType = type or "cp"
end

RegisterNUICallback("cameraDistanceFov", function(data, cb)
    cb("ok")

    if not currentCamera or not DoesCamExist(currentCamera) then
        return
    end

    if data.fov ~= 1 and data.fov ~= 2 then
        return
    end

    local camCoords = GetCamCoord(currentCamera)
    local targetFov = nil

    if data.fov == 1 then
        targetFov = withPartner and 20 or 12
    elseif data.fov == 2 then
        targetFov = withPartner and 30 or 16
    end

    if targetFov then
        local fovPromise = promise.new()
        animateCamera(currentCamera, camCoords, targetFov, 800, fovPromise)
    end
end)
