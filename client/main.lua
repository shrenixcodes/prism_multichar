local isOpen = false
local slots = {}
local activeCharacter = nil

local function notifyError(code)
    SendNUIMessage({ action = 'error', code = code })
end

local function finishSpawn(coords)
    StopCinematicCamera()
    UnloadScene()

    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do
        Wait(0)
    end

    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
    SetEntityHeading(ped, coords.w or 0.0)
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, false)
    DisplayRadar(true)
    ClearFocus()

    TriggerServerEvent('prism_multichar:server:spawned')
    Bridge.OnSpawned(coords)

    DoScreenFadeIn(500)

    isOpen = false
    activeCharacter = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function runCharacterCreator(gender, onDone)
    SetNuiFocus(false, false)

    local model = gender == 'female' and 'mp_f_freemode_01' or 'mp_m_freemode_01'
    exports['illenium-appearance']:setPlayerModel(model)

    exports['illenium-appearance']:startPlayerCustomization(function(appearance)
        if appearance then
            TriggerServerEvent('illenium-appearance:server:saveAppearance', appearance)
        end
        onDone()
    end, {
        enableExit = false,
        ped = true,
        headBlend = true,
        faceFeatures = true,
        headOverlays = true,
        components = true,
        props = true,
        tattoos = true
    })
end

local function openSpawnPicker(character)
    activeCharacter = character

    local spawns = {}
    for i, spawn in ipairs(Config.Spawns) do
        spawns[i] = { label = spawn.label }
    end

    SendNUIMessage({
        action = 'spawnPicker',
        spawns = spawns,
        hasLastLocation = character.position ~= nil
    })
end

function SelectSlot(slot)
    local character = slots[slot]
    local token = NextPreviewToken()

    if character then
        lib.callback('prism_multichar:server:getAppearance', false, function(appearance)
            SetPreviewAppearance(character.gender, appearance, token)
        end, character.id)
    else
        SetPreviewAppearance('male', nil, token)
    end
end

function OpenSelection()
    if isOpen then
        return
    end

    isOpen = true

    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open' })

    lib.callback('prism_multichar:server:getCharacters', false, function(ok, payload)
        if not ok then
            notifyError(payload)
            isOpen = false
            SetNuiFocus(false, false)
            return
        end

        slots = payload.slots

        local scene = Config.Scenes[math.random(#Config.Scenes)]
        local ped = LoadScene(scene)
        StartCinematicCamera(ped, scene.shots)

        SendNUIMessage({ action = 'slots', slots = slots, total = payload.total })

        if IsScreenFadedOut() then
            DoScreenFadeIn(500)
        end

        SelectSlot(1)
    end)
end

exports('OpenSelection', OpenSelection)

RegisterNUICallback('selectSlot', function(data, cb)
    SelectSlot(data.slot)
    cb(1)
end)

RegisterNUICallback('rotate', function(data, cb)
    RotatePed(data.delta)
    cb(1)
end)

RegisterNUICallback('createCharacter', function(data, cb)
    lib.callback('prism_multichar:server:createCharacter', false, function(ok, result)
        if not ok then
            notifyError(result)
            return
        end

        slots[data.slot] = {
            id = result.id,
            slot = data.slot,
            firstname = data.data.firstname,
            lastname = data.data.lastname,
            dob = data.data.dob,
            gender = data.data.gender,
            nationality = data.data.nationality
        }

        runCharacterCreator(data.data.gender, function()
            finishSpawn(Config.NewCharacterSpawn)
        end)
    end, data.slot, data.data)

    cb(1)
end)

RegisterNUICallback('play', function(data, cb)
    local character = slots[data.slot]
    if character then
        openSpawnPicker(character)
    end
    cb(1)
end)

RegisterNUICallback('confirmSpawn', function(data, cb)
    local character = activeCharacter
    if not character then
        cb(1)
        return
    end

    local coords
    if data.type == 'last' and character.position then
        local pos = character.position
        coords = vector4(pos.x, pos.y, pos.z, pos.w or 0.0)
    else
        coords = Config.Spawns[data.index].coords
    end

    ShowSpawnCamera(coords)

    lib.callback('prism_multichar:server:loginCharacter', false, function(ok, err)
        if not ok then
            notifyError(err)
            HideSpawnCamera()
            return
        end

        finishSpawn(coords)
    end, character.id, character.slot)

    cb(1)
end)

RegisterNUICallback('backToScene', function(_, cb)
    HideSpawnCamera()
    activeCharacter = nil
    SendNUIMessage({ action = 'closeSpawnPicker' })
    cb(1)
end)

RegisterNUICallback('deleteCharacter', function(data, cb)
    local character = slots[data.slot]
    if not character then
        cb(1)
        return
    end

    lib.callback('prism_multichar:server:deleteCharacter', false, function(ok, err)
        if ok then
            slots[data.slot] = false
            SendNUIMessage({ action = 'deleted', slot = data.slot })
        else
            notifyError(err)
        end
    end, character.id)

    cb(1)
end)

local function onRelog()
    if GetInvokingResource() then
        return
    end
    OpenSelection()
end

RegisterNetEvent('qb-multicharacter:client:chooseChar', onRelog)
RegisterNetEvent('qbx_core:client:playerLoggedOut', onRelog)
RegisterNetEvent('esx:onPlayerLogout', onRelog)

CreateThread(function()
    while not NetworkIsSessionStarted() do
        Wait(0)
    end
    OpenSelection()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then
        return
    end

    StopCinematicCamera()
    UnloadScene()
    SetNuiFocus(false, false)
end)
