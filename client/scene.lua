local previewPed = nil
local previewToken = 0
local previewModel = nil
local clockActive = false
local currentScene = nil

local GHOST_ALPHA = 140
local FULL_ALPHA = 255

local function loadModel(name)
    local hash = joaat(name)
    RequestModel(hash)

    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do
        Wait(0)
    end

    return hash
end

local function pinClock(hour, minute)
    clockActive = true
    CreateThread(function()
        while clockActive do
            NetworkOverrideClockTime(hour, minute, 0)
            Wait(1000)
        end
    end)
end

local function snapToGround(ped, coords)
    local timeout = GetGameTimer() + 2000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do
        Wait(0)
    end

    local found, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 5.0, false)
    if found then
        SetEntityCoords(ped, coords.x, coords.y, groundZ, false, false, false, false)
    end
end

local function playIdleAnim(ped, anim)
    RequestAnimDict(anim.dict)

    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(anim.dict) and GetGameTimer() < timeout do
        Wait(0)
    end

    TaskPlayAnim(ped, anim.dict, anim.clip, 8.0, -8.0, -1, 1, 0, false, false, false)
end

local function ensureModel(ped, gender)
    local desired = gender == 'female' and 'mp_f_freemode_01' or 'mp_m_freemode_01'
    if previewModel == desired then
        return
    end

    local hash = loadModel(desired)
    SetEntityModel(ped, hash)
    SetModelAsNoLongerNeeded(hash)
    previewModel = desired
end

local function fadeTo(ped, target, token)
    local step = target > GetEntityAlpha(ped) and 15 or -15

    while token == previewToken and DoesEntityExist(ped) do
        local alpha = GetEntityAlpha(ped)
        if (step > 0 and alpha >= target) or (step < 0 and alpha <= target) then
            SetEntityAlpha(ped, target, false)
            return
        end

        SetEntityAlpha(ped, alpha + step, false)
        Wait(0)
    end
end

function LoadScene(scene)
    currentScene = scene

    pinClock(scene.time[1], scene.time[2])
    SetWeatherTypeNowPersist(scene.weather)

    local hash = loadModel('mp_m_freemode_01')
    previewModel = 'mp_m_freemode_01'

    previewPed = CreatePed(4, hash, scene.coords.x, scene.coords.y, scene.coords.z, scene.coords.w, false, true)
    SetModelAsNoLongerNeeded(hash)
    SetEntityAsMissionEntity(previewPed, true, true)
    FreezeEntityPosition(previewPed, true)
    SetEntityInvincible(previewPed, true)
    SetBlockingOfNonTemporaryEvents(previewPed, true)
    SetEntityAlpha(previewPed, 0, false)

    snapToGround(previewPed, scene.coords)
    playIdleAnim(previewPed, Config.DefaultAnim)

    return previewPed
end

function UnloadScene()
    clockActive = false

    if previewPed and DoesEntityExist(previewPed) then
        DeletePed(previewPed)
    end

    previewPed = nil
    previewModel = nil
    currentScene = nil
end

function NextPreviewToken()
    previewToken = previewToken + 1
    return previewToken
end

function SetPreviewAppearance(gender, appearance, token)
    if not previewPed or token ~= previewToken then
        return
    end

    ensureModel(previewPed, gender)
    SetEntityAlpha(previewPed, 0, false)

    if appearance then
        exports['illenium-appearance']:setPedAppearance(previewPed, appearance)
    end

    fadeTo(previewPed, appearance and FULL_ALPHA or GHOST_ALPHA, token)
end

function RotatePed(delta)
    if not previewPed or not DoesEntityExist(previewPed) then
        return
    end

    local heading = GetEntityHeading(previewPed) + delta
    SetEntityHeading(previewPed, heading % 360.0)
end

function GetPreviewPed()
    return previewPed
end

function GetCurrentScene()
    return currentScene
end
