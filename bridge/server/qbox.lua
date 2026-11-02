Bridge.Framework = 'qbox'

function Bridge.GetCharacters(license, license2)
    return Bridge.FetchQBCharacters(license, license2)
end

function Bridge.IsLoggedIn(src)
    return exports.qbx_core:GetPlayer(src) ~= nil
end

function Bridge.Login(src, citizenid)
    return exports.qbx_core:Login(src, citizenid) == true
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

    local success = exports.qbx_core:Login(src, nil, newData)
    if not success then
        return nil
    end

    local player = exports.qbx_core:GetPlayer(src)
    if not player then
        return nil
    end

    Bridge.GiveStarterItems(src, player.PlayerData)

    return player.PlayerData.citizenid
end

function Bridge.DeleteCharacter(citizenid)
    exports.qbx_core:DeleteCharacter(citizenid)
    Bridge.DeleteAppearance(citizenid)
    return true
end

function Bridge.GiveStarterItems(src, playerData)
    if GetResourceState('ox_inventory') == 'missing' then
        return
    end

    local charinfo = playerData.charinfo

    for _, item in ipairs(Config.StarterItems) do
        local metadata = nil

        if item.metadata then
            metadata = {
                citizenid = playerData.citizenid,
                firstname = charinfo.firstname,
                lastname = charinfo.lastname,
                birthdate = charinfo.birthdate
            }
        end

        exports.ox_inventory:AddItem(src, item.name, item.amount, metadata)
    end
end

function Bridge.OnPlayerLoaded(src)
    TriggerEvent('QBCore:Server:OnPlayerLoaded', src)
end
