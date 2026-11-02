local cam = nil
local spawnCam = nil
local cinematicActive = false
local cinematicPaused = false

local EASE_IN_MS = 1200.0

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function lerpVector(a, b, t)
    return vector3(lerp(a.x, b.x, t), lerp(a.y, b.y, t), lerp(a.z, b.z, t))
end

local function smoothstep(t)
    t = math.max(0.0, math.min(1.0, t))
    return t * t * (3.0 - 2.0 * t)
end

local function computeShotPosition(ped, shot)
    local coords = GetEntityCoords(ped)
    local heading = math.rad(GetEntityHeading(ped))

    local forwardX, forwardY = -math.sin(heading), math.cos(heading)
    local rightX, rightY = math.cos(heading), math.sin(heading)

    local x = coords.x + rightX * shot.x + forwardX * shot.y
    local y = coords.y + rightY * shot.x + forwardY * shot.y
    local z = coords.z + shot.z

    return vector3(x, y, z)
end

function StartCinematicCamera(ped, shots)
    cinematicActive = true
    cinematicPaused = false

    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamFov(cam, shots[1].fov)
    SetCamCoord(cam, computeShotPosition(ped, shots[1]))
    RenderScriptCams(true, false, 0, true, true)

    CreateThread(function()
        local index = 1

        while cinematicActive do
            local shot = shots[index]
            local startPos = GetCamCoord(cam)
            local startFov = GetCamFov(cam)
            local targetPos = computeShotPosition(ped, shot)
            local elapsed = 0.0

            while cinematicActive and elapsed < Config.CameraShotDuration do
                if not cinematicPaused then
                    local t = smoothstep(elapsed / EASE_IN_MS)
                    SetCamCoord(cam, lerpVector(startPos, targetPos, t))
                    SetCamFov(cam, lerp(startFov, shot.fov, t))
                    PointCamAtEntity(cam, ped, 0.0, 0.0, 0.55, true)
                    elapsed = elapsed + (GetFrameTime() * 1000.0)
                end
                Wait(0)
            end

            index = index % #shots + 1
        end

        if cam and DoesCamExist(cam) then
            DestroyCam(cam, false)
        end
        cam = nil
    end)
end

function PauseCinematicCamera()
    cinematicPaused = true
end

function ResumeCinematicCamera()
    cinematicPaused = false
end

function StopCinematicCamera()
    cinematicActive = false
    RenderScriptCams(false, false, 0, true, true)
end

function ShowSpawnCamera(coords)
    PauseCinematicCamera()

    local fromCam = GetRenderingCam()
    spawnCam = CreateCamWithParams(
        'DEFAULT_SCRIPTED_CAMERA',
        coords.x, coords.y, coords.z + 35.0,
        -75.0, 0.0, 0.0,
        50.0, false, 0
    )

    SetFocusPosAndVel(coords.x, coords.y, coords.z, 0.0, 0.0, 0.0)
    SetCamActiveWithInterp(spawnCam, fromCam, 1500, 1, 1)
    RenderScriptCams(true, false, 0, true, true)
end

function HideSpawnCamera()
    if cam and spawnCam and DoesCamExist(spawnCam) then
        SetCamActiveWithInterp(cam, spawnCam, 1200, 1, 1)
    end

    local removeCam = spawnCam
    spawnCam = nil

    CreateThread(function()
        Wait(1300)
        if removeCam and DoesCamExist(removeCam) then
            DestroyCam(removeCam, false)
        end
    end)

    ResumeCinematicCamera()
end
