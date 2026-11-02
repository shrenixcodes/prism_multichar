if Config.Framework ~= 'qbcore' and not (Config.Framework == 'auto' and GetResourceState('qb-core') == 'started') then
    return
end

local QBCore = exports['qb-core']:GetCoreObject()

Bridge.Framework = 'qbcore'

function Bridge.GetCharacters(license, license2, _)
    return Bridge.FetchQBCharacters(license, license2)
end

function Bridge.IsLoggedIn(src)
    return QBCore.Functions.GetPlayer(src) ~= nil
end

function Bridge.Login(src, citizenid, _)
    return QBCore.Player.Login(src, citizenid) == true
end

function Bridge.CreateCharacter(src, data, slot)
    local newData = {
        charinfo = {
            firstname = data.firstname,
            lastname = data.lastname,
            birthdate = data.dob,
            nationality = data.nationality,
            gender = Bridge.GenderToNumber[data.gender] or 0,
            cid = slot
        }
    }

    local success = QBCore.Player.Login(src, nil, newData)
    if not success then
        return nil
    end

    local player = QBCore.Functions.GetPlayer(src)
    if not player then
        return nil
    end

    Bridge.GiveStarterItems(src, player.PlayerData)

    return player.PlayerData.citizenid
end

function Bridge.DeleteCharacter(src, citizenid)
    QBCore.Player.DeleteCharacter(src, citizenid)
    Bridge.DeleteAppearance(citizenid)
    return true
end

function Bridge.GiveStarterItems(src, playerData)
    if GetResourceState('qb-inventory') == 'missing' then
        return
    end

    local charinfo = playerData.charinfo
    local sharedItems = exports['qb-core']:GetShared('StarterItems')

    local items = {}
    if sharedItems then
        for _, item in pairs(sharedItems) do
            items[#items + 1] = { name = item.item, amount = item.amount }
        end
    else
        items = Config.StarterItems
    end

    for _, item in ipairs(items) do
        local info = nil

        if item.name == 'id_card' then
            info = {
                citizenid = playerData.citizenid,
                firstname = charinfo.firstname,
                lastname = charinfo.lastname,
                birthdate = charinfo.birthdate,
                gender = charinfo.gender,
                nationality = charinfo.nationality
            }
        elseif item.name == 'driver_license' then
            info = {
                firstname = charinfo.firstname,
                lastname = charinfo.lastname,
                birthdate = charinfo.birthdate
            }
        end

        exports['qb-inventory']:AddItem(src, item.name, item.amount, false, info, 'prism_multichar:starterItems')
    end
end

function Bridge.OnPlayerLoaded(src)
    TriggerEvent('QBCore:Server:OnPlayerLoaded')
    QBCore.Commands.Refresh(src)
end
