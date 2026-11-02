Bridge = Bridge or {}

-- qb-style charinfo stores gender as 0/1, inherited from qb-multicharacter's convention
local genderFromNumber = { [0] = 'male', [1] = 'female' }
local genderToNumber = { male = 0, female = 1 }

Bridge.GenderToNumber = genderToNumber

function Bridge.GetIdentifiers(src)
    local license, license2
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:find('license:') == 1 then
            license = id
        elseif id:find('license2:') == 1 then
            license2 = id
        end
    end
    return license, license2
end

-- qbox and qbcore both keep characters in a `players` table shaped the same way,
-- so the row-to-character mapping can live here instead of in both bridges.
-- neither framework has a license2 column, both store whichever identifier
-- was available in `license`, so the same value has to be checked twice
function Bridge.FetchQBCharacters(license, license2)
    local rows = MySQL.query.await(
        'SELECT * FROM players WHERE license = ? OR license = ?',
        { license, license2 }
    )

    if not rows then
        return {}
    end

    local characters = {}

    for _, row in ipairs(rows) do
        local charinfo = type(row.charinfo) == 'string' and json.decode(row.charinfo) or row.charinfo or {}
        local job = type(row.job) == 'string' and json.decode(row.job) or row.job or {}
        local money = type(row.money) == 'string' and json.decode(row.money) or row.money or {}
        local position = type(row.position) == 'string' and json.decode(row.position) or row.position or nil

        characters[#characters + 1] = {
            id = row.citizenid,
            slot = tonumber(charinfo.cid) or (row.cid and tonumber(row.cid)),
            firstname = charinfo.firstname,
            lastname = charinfo.lastname,
            dob = charinfo.birthdate,
            gender = genderFromNumber[charinfo.gender] or 'male',
            nationality = charinfo.nationality,
            job = job.label or job.name or 'unemployed',
            cash = math.floor(tonumber(money.cash) or 0),
            bank = math.floor(tonumber(money.bank) or 0),
            lastPlayed = row.last_updated or row.last_logged_out,
            position = position
        }
    end

    return characters
end

function Bridge.FetchAppearance(citizenid)
    local row = MySQL.single.await(
        'SELECT skin FROM playerskins WHERE citizenid = ? AND active = 1 LIMIT 1',
        { citizenid }
    )

    if not row or not row.skin then
        return nil
    end

    return type(row.skin) == 'string' and json.decode(row.skin) or row.skin
end

function Bridge.DeleteAppearance(citizenid)
    MySQL.query.await('DELETE FROM playerskins WHERE citizenid = ?', { citizenid })
end
