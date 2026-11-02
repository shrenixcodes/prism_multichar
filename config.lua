Config = {}

Config.Framework = 'auto' -- 'auto', 'qbox', 'qbcore', 'esx'
Config.Locale = 'en'
Config.Debug = false

Config.MaxSlots = 5
Config.DefaultSlots = 3

-- keyed by 'license:xxxx', highest value wins alongside ace perms, capped at MaxSlots
Config.SlotOverrides = {
    -- ['license:0000000000000000000000000000000000000000'] = 5,
}

Config.Name = {
    min = 2,
    max = 16
}

Config.Birthdate = {
    minAge = 13,
    maxAge = 100
}

-- players sit in bucket SelectionBucketOffset + source while picking a character
Config.SelectionBucketOffset = 100000

Config.Genders = { 'male', 'female' }

Config.NewCharacterSpawn = vector4(-1035.71, -2731.19, 20.17, 327.75)

Config.Spawns = {
    { label = 'legion_square', coords = vector4(215.37, -810.19, 30.74, 160.0) },
    { label = 'sandy_shores', coords = vector4(1961.48, 3740.52, 32.34, 210.0) },
    { label = 'paleto_bay', coords = vector4(-146.58, 6304.26, 31.48, 230.0) },
    { label = 'vinewood_hills', coords = vector4(-1588.65, 282.32, 65.38, 50.0) }
}

Config.DefaultAnim = {
    dict = 'anim@heists@heist_corona@single_team',
    clip = 'single_team_loop_boss'
}

-- how long the camera lingers on each shot before gliding to the next, in ms
Config.CameraShotDuration = 9000

-- camera offsets are relative to the ped's feet and heading: x = right, y = forward, z = up
Config.Scenes = {
    {
        name = 'apartment',
        coords = vector4(-1035.71, -2731.19, 20.17, 327.75),
        time = { 21, 30 },
        weather = 'CLEAR',
        shots = {
            { x = 1.3, y = 2.6, z = 0.7, fov = 40.0 },
            { x = -0.9, y = 1.8, z = 1.3, fov = 35.0 },
            { x = 0.4, y = 3.4, z = 0.9, fov = 45.0 }
        }
    },
    {
        name = 'rooftop',
        coords = vector4(-771.37, 312.1, 86.0, 160.0),
        time = { 20, 0 },
        weather = 'CLEAR',
        shots = {
            { x = -1.1, y = 2.2, z = 0.5, fov = 38.0 },
            { x = 1.0, y = 1.4, z = 1.6, fov = 32.0 },
            { x = 0.0, y = 3.0, z = 1.0, fov = 44.0 }
        }
    },
    {
        name = 'docks',
        coords = vector4(1207.3, -3127.9, 5.9, 45.0),
        time = { 6, 15 },
        weather = 'FOGGY',
        shots = {
            { x = 1.5, y = 2.0, z = 0.6, fov = 42.0 },
            { x = -1.3, y = 1.6, z = 1.2, fov = 36.0 },
            { x = 0.2, y = 2.8, z = 0.8, fov = 40.0 }
        }
    }
}

Config.StarterItems = {
    { name = 'water_bottle', amount = 1 },
    { name = 'sandwich', amount = 1 },
    { name = 'phone', amount = 1 },
    { name = 'id_card', amount = 1, metadata = true },
    { name = 'driver_license', amount = 1, metadata = true }
}

Config.WeatherSync = {
    enabled = true,
    resource = 'qb-weathersync'
}

Config.ESX = {
    DateFormat = '%d/%m/%Y',
    RelogCommand = 'relog',
    DeleteTables = {
        { table = 'users', column = 'identifier' },
        { table = 'user_licenses', column = 'owner' },
        { table = 'user_inventory', column = 'identifier' },
        { table = 'user_accounts', column = 'identifier' }
    }
}
