if Config.Framework ~= 'esx' and not (Config.Framework == 'auto' and GetResourceState('es_extended') == 'started') then
    return
end

local ESX = exports['es_extended']:getSharedObject()

Bridge.Framework = 'esx'

local genderToSex = { male = 'm', female = 'f' }

local requiredColumns = {
    firstname = 'VARCHAR(16) NULL DEFAULT NULL',
    lastname = 'VARCHAR(16) NULL DEFAULT NULL',
    dateofbirth = 'VARCHAR(10) NULL DEFAULT NULL',
    sex = 'VARCHAR(1) NULL DEFAULT NULL',
    height = 'INT NULL DEFAULT NULL',
    skin = 'LONGTEXT NULL DEFAULT NULL',
    prism_last_played = 'TIMESTAMP NULL DEFAULT NULL'
}

local function columnExists(column)
    local count = MySQL.scalar.await(
        'SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = ? AND column_name = ?',
        { 'users', column }
    )
    return (tonumber(count) or 0) > 0
end

-- esx_identity normally adds these columns; without it installed the raw
-- `users` table from es_extended.sql has nowhere to put a character's name
local function ensureSchema()
    for column, definition in pairs(requiredColumns) do
        if not columnExists(column) then
            MySQL.query.await(('ALTER TABLE `users` ADD COLUMN `%s` %s'):format(column, definition))
        end
    end
end

CreateThread(ensureSchema)

local function isSafeIdentifierPart(value)
    return type(value) == 'string' and value:match('^[%w_]+$') ~= nil
end

local function waitForPlayer(src, timeout)
    local deadline = GetGameTimer() + (timeout or 5000)
    while GetGameTimer() < deadline do
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            return xPlayer
        end
        Wait(50)
    end
    return nil
end

local function touchLastPlayed(identifier)
    MySQL.query.await('UPDATE users SET prism_last_played = NOW() WHERE identifier = ?', { identifier })
end

function Bridge.GetCharacters(license, _, maxSlots)
    local characters = {}

    for slot = 1, maxSlots do
        local identifier = ('char%d:%s'):format(slot, license)
        local row = MySQL.single.await('SELECT * FROM users WHERE identifier = ?', { identifier })

        if row then
            local accounts = row.accounts and json.decode(row.accounts) or {}
            local job = ESX.Jobs[row.job]

            characters[#characters + 1] = {
                id = identifier,
                slot = slot,
                firstname = row.firstname,
                lastname = row.lastname,
                dob = row.dateofbirth,
                gender = row.sex == 'f' and 'female' or 'male',
                nationality = nil,
                job = job and job.label or row.job or 'unemployed',
                cash = math.floor(tonumber(accounts.money) or 0),
                bank = math.floor(tonumber(accounts.bank) or 0),
                lastPlayed = row.prism_last_played,
                position = row.position and json.decode(row.position) or nil
            }
        end
    end

    return characters
end

function Bridge.IsLoggedIn(src)
    return ESX.GetPlayerFromId(src) ~= nil
end

function Bridge.Login(src, _, slot)
    TriggerEvent('esx:onPlayerJoined', src, ('char%d'):format(slot))

    local xPlayer = waitForPlayer(src)
    if not xPlayer then
        return false
    end

    touchLastPlayed(xPlayer.identifier)
    return true
end

function Bridge.CreateCharacter(src, data, slot)
    local payload = {
        firstname = data.firstname,
        lastname = data.lastname,
        dateofbirth = data.dob,
        sex = genderToSex[data.gender] or 'm',
        height = 178
    }

    TriggerEvent('esx:onPlayerJoined', src, ('char%d'):format(slot), payload)

    local xPlayer = waitForPlayer(src)
    if not xPlayer then
        return nil
    end

    touchLastPlayed(xPlayer.identifier)
    Bridge.GiveStarterItems(xPlayer)

    return xPlayer.identifier
end

function Bridge.DeleteCharacter(_, identifier)
    local queries = {}

    for _, entry in ipairs(Config.ESX.DeleteTables) do
        if isSafeIdentifierPart(entry.table) and isSafeIdentifierPart(entry.column) then
            queries[#queries + 1] = {
                query = ('DELETE FROM `%s` WHERE `%s` = ?'):format(entry.table, entry.column),
                values = { identifier }
            }
        end
    end

    if #queries > 0 then
        MySQL.transaction.await(queries)
    end

    return true
end

function Bridge.FetchAppearance(identifier)
    local row = MySQL.single.await('SELECT skin FROM users WHERE identifier = ?', { identifier })

    if not row or not row.skin then
        return nil
    end

    return type(row.skin) == 'string' and json.decode(row.skin) or row.skin
end

function Bridge.GiveStarterItems(xPlayer)
    for _, item in ipairs(Config.StarterItems) do
        xPlayer.addInventoryItem(item.name, item.amount)
    end
end

-- esx:onPlayerSpawn is a RegisterNetEvent that reads the ambient `source`,
-- so this only works called from inside the handler for that player's own request
function Bridge.OnPlayerLoaded(_)
    TriggerEvent('esx:onPlayerSpawn')
end
