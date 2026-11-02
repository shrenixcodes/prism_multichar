Bridge = Bridge or {}

local function detectFramework()
    if Config.Framework ~= 'auto' then
        return Config.Framework
    end

    if GetResourceState('qbx_core') == 'started' then
        return 'qbox'
    elseif GetResourceState('qb-core') == 'started' then
        return 'qbcore'
    elseif GetResourceState('es_extended') == 'started' then
        return 'esx'
    end

    return nil
end

Bridge.Framework = detectFramework()
Bridge.Loaded = false

assert(Bridge.Framework, 'prism_multichar: no supported framework detected (qbx_core, qb-core or es_extended). set Config.Framework manually if detection failed.')

if Bridge.Framework == 'esx' then
    function Bridge.OnSpawned(coords)
        TriggerEvent('playerSpawned', coords)
        TriggerEvent('esx:onPlayerSpawn')
        TriggerServerEvent('esx:onPlayerSpawn')
        TriggerEvent('esx:restoreLoadout')
        Bridge.Loaded = true
    end
else
    function Bridge.OnSpawned(_)
        TriggerEvent('QBCore:Client:OnPlayerLoaded')
        Bridge.Loaded = true
    end
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        Bridge.Loaded = false
    end
end)
