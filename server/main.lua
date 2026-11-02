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
        slots[i] = used[i] or false
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
end

local function endSelection(src)
    Sessions[src] = nil
    SetPlayerRoutingBucket(src, 0)
end

local function hasActiveSession(src)
    return Sessions[src] ~= nil
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
