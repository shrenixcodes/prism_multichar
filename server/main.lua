assert(Bridge.Framework, 'prism_multichar: no supported framework detected (qbx_core, qb-core or es_extended). set Config.Framework manually if detection failed.')

local Sessions = {}

local function getAceSlots(src)
    local best = 0

    for n = 1, Config.MaxSlots do
        if IsPlayerAceAllowed(src, ('prism_multichar.slots.%d'):format(n)) then
            best = n
        end
    end

    return best
end

local function resolveSlotCount(src, license, license2)
    local count = Config.DefaultSlots

    local override = Config.SlotOverrides[license] or (license2 and Config.SlotOverrides[license2])
    if override then
        count = math.max(count, override)
    end

    count = math.max(count, getAceSlots(src))

    return math.min(count, Config.MaxSlots)
end

-- characters keep whatever slot number they were created with, so a reduced
-- MaxSlots or a collision from manual DB edits must never erase one -
-- anything that can't fit cleanly gets pushed into an extra slot instead
local function buildSlots(characters, slotCount)
    local used = {}
    local overflow = {}

    for _, character in ipairs(characters) do
        local slot = character.slot
        if slot and slot >= 1 and not used[slot] then
            used[slot] = character
        else
            overflow[#overflow + 1] = character
        end
    end

    local nextFree = slotCount + 1
    for _, character in ipairs(overflow) do
        while used[nextFree] do
            nextFree = nextFree + 1
        end
        used[nextFree] = character
        nextFree = nextFree + 1
    end

    local total = math.max(slotCount, nextFree - 1)
    local slots = {}

    for i = 1, total do
        local character = used[i]
        if character then
            character.slot = i
        end
        slots[i] = character or false
    end

    return slots, total
end

local function startSelection(src, license, license2)
    Sessions[src] = {
        license = license,
        license2 = license2,
        lastAction = 0
    }
    SetPlayerRoutingBucket(src, Config.SelectionBucketOffset + src)

    if Config.WeatherSync.enabled then
        TriggerClientEvent(Config.WeatherSync.resource .. ':client:DisableSync', src)
    end
end

local function endSelection(src)
    Sessions[src] = nil
    SetPlayerRoutingBucket(src, 0)

    if Config.WeatherSync.enabled then
        TriggerClientEvent(Config.WeatherSync.resource .. ':client:EnableSync', src)
    end
end

local function throttle(src)
    local session = Sessions[src]
    if not session then
        return false
    end

    local now = GetGameTimer()
    if now - session.lastAction < 500 then
        return false
    end

    session.lastAction = now
    return true
end

AddEventHandler('playerDropped', function()
    Sessions[source] = nil
end)

local function trim(value)
    return value:gsub('^%s+', ''):gsub('%s+$', '')
end

local function titleCase(value)
    return (value:lower():gsub("(%a)([%a'%-]*)", function(first, rest)
        return first:upper() .. rest
    end))
end

local function validateName(value)
    if type(value) ~= 'string' then
        return nil
    end

    value = trim(value)

    if #value < Config.Name.min or #value > Config.Name.max then
        return nil
    end

    if not value:match("^[%a%s'%-]+$") then
        return nil
    end

    return titleCase(value)
end

local function validateNationality(value)
    if type(value) ~= 'string' then
        return nil
    end

    value = trim(value)

    if value == '' or #value > 50 then
        return nil
    end

    return value
end

local function validateGender(value)
    if value == 'male' or value == 'female' then
        return value
    end

    return nil
end

local daysInMonth = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }

local function isLeapYear(year)
    return year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0)
end

local function parseIsoDate(value)
    if type(value) ~= 'string' then
        return nil
    end

    local y, m, d = value:match('^(%d%d%d%d)-(%d%d)-(%d%d)$')
    if not y then
        return nil
    end

    y, m, d = tonumber(y), tonumber(m), tonumber(d)
    if m < 1 or m > 12 then
        return nil
    end

    local maxDay = daysInMonth[m]
    if m == 2 and isLeapYear(y) then
        maxDay = 29
    end

    if d < 1 or d > maxDay then
        return nil
    end

    return { year = y, month = m, day = d }
end

local function ageFromDate(date)
    local now = os.date('*t')
    local age = now.year - date.year

    if now.month < date.month or (now.month == date.month and now.day < date.day) then
        age = age - 1
    end

    return age
end

local function formatDate(date, pattern)
    pattern = pattern:gsub('%%d', ('%02d'):format(date.day))
    pattern = pattern:gsub('%%m', ('%02d'):format(date.month))
    pattern = pattern:gsub('%%Y', ('%04d'):format(date.year))
    return pattern
end

local function validateCharacterData(input)
    if type(input) ~= 'table' then
        return nil, 'invalid_data'
    end

    local firstname = validateName(input.firstname)
    if not firstname then
        return nil, 'invalid_firstname'
    end

    local lastname = validateName(input.lastname)
    if not lastname then
        return nil, 'invalid_lastname'
    end

    local gender = validateGender(input.gender)
    if not gender then
        return nil, 'invalid_gender'
    end

    local date = parseIsoDate(input.dob)
    if not date then
        return nil, 'invalid_dob'
    end

    local age = ageFromDate(date)
    if age < Config.Birthdate.minAge or age > Config.Birthdate.maxAge then
        return nil, 'invalid_dob'
    end

    local nationality = nil
    if Bridge.Framework ~= 'esx' then
        nationality = validateNationality(input.nationality)
        if not nationality then
            return nil, 'invalid_nationality'
        end
    end

    local pattern = Bridge.Framework == 'esx' and Config.ESX.DateFormat or '%m-%d-%Y'

    return {
        firstname = firstname,
        lastname = lastname,
        gender = gender,
        nationality = nationality,
        dob = formatDate(date, pattern)
    }
end

local function findCharacter(characters, id)
    for _, character in ipairs(characters) do
        if character.id == id then
            return character
        end
    end

    return nil
end

lib.callback.register('prism_multichar:server:getCharacters', function(src)
    if Bridge.IsLoggedIn(src) then
        return false, 'already_logged_in'
    end

    local license, license2 = Bridge.GetIdentifiers(src)
    if not license and not license2 then
        return false, 'no_identifier'
    end

    startSelection(src, license, license2)

    local slotCount = resolveSlotCount(src, license, license2)
    local characters = Bridge.GetCharacters(license, license2, slotCount)
    local slots, total = buildSlots(characters, slotCount)

    return true, { slots = slots, total = total }
end)

lib.callback.register('prism_multichar:server:createCharacter', function(src, slot, data)
    local session = Sessions[src]
    if not session or Bridge.IsLoggedIn(src) then
        return false, 'no_session'
    end

    if not throttle(src) then
        return false, 'too_fast'
    end

    slot = tonumber(slot)
    if not slot or slot < 1 or slot ~= math.floor(slot) or slot > Config.MaxSlots then
        return false, 'invalid_slot'
    end

    local slotCount = resolveSlotCount(src, session.license, session.license2)
    if slot > slotCount then
        return false, 'slot_locked'
    end

    local characters = Bridge.GetCharacters(session.license, session.license2, slotCount)
    for _, character in ipairs(characters) do
        if character.slot == slot then
            return false, 'slot_taken'
        end
    end

    local validated, err = validateCharacterData(data)
    if not validated then
        return false, err
    end

    local id = Bridge.CreateCharacter(src, validated, slot)
    if not id then
        return false, 'create_failed'
    end

    session.loggedIn = true
    TriggerEvent('prism_multichar:server:characterCreated', src, id)

    return true, { id = id, slot = slot }
end)

lib.callback.register('prism_multichar:server:loginCharacter', function(src, id, slot)
    local session = Sessions[src]
    if not session or Bridge.IsLoggedIn(src) then
        return false, 'no_session'
    end

    if not throttle(src) then
        return false, 'too_fast'
    end

    local slotCount = resolveSlotCount(src, session.license, session.license2)
    local characters = Bridge.GetCharacters(session.license, session.license2, slotCount)

    if not findCharacter(characters, id) then
        return false, 'not_owned'
    end

    if not Bridge.Login(src, id, slot) then
        return false, 'login_failed'
    end

    session.loggedIn = true
    TriggerEvent('prism_multichar:server:characterLoaded', src, id)

    return true
end)

lib.callback.register('prism_multichar:server:deleteCharacter', function(src, id)
    local session = Sessions[src]
    if not session or Bridge.IsLoggedIn(src) then
        return false, 'no_session'
    end

    if not throttle(src) then
        return false, 'too_fast'
    end

    local slotCount = resolveSlotCount(src, session.license, session.license2)
    local characters = Bridge.GetCharacters(session.license, session.license2, slotCount)

    if not findCharacter(characters, id) then
        return false, 'not_owned'
    end

    Bridge.DeleteCharacter(src, id)
    TriggerEvent('prism_multichar:server:characterDeleted', src, id)

    return true
end)

lib.callback.register('prism_multichar:server:getAppearance', function(src, id)
    local session = Sessions[src]
    if not session or Bridge.IsLoggedIn(src) then
        return nil
    end

    local slotCount = resolveSlotCount(src, session.license, session.license2)
    local characters = Bridge.GetCharacters(session.license, session.license2, slotCount)

    if not findCharacter(characters, id) then
        return nil
    end

    return Bridge.FetchAppearance(id)
end)

RegisterNetEvent('prism_multichar:server:spawned', function()
    local src = source
    local session = Sessions[src]

    if not session or not session.loggedIn then
        return
    end

    endSelection(src)
    Bridge.OnPlayerLoaded(src)
end)
