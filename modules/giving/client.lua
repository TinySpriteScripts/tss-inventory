TSSInventoryClient = TSSInventoryClient or {}
local giving = {}
TSSInventoryClient.Giving = giving
local active = false
local candidates = {}
local nextScan = 0
local lastSignature = nil

function giving.Stop()
    active, candidates, nextScan, lastSignature = false, {}, 0, nil
    SendNUIMessage({ type = 'nearbyPlayers', players = {} })
end

local function updateTargets()
    local playerPed = PlayerPedId()
    if not DoesEntityExist(playerPed) then giving.Stop(); return end
    local origin = GetEntityCoords(playerPed)
    local maximumDistance = TSSGivingDistance() ^ 2
    if GetGameTimer() >= nextScan then
        candidates = GetActivePlayers()
        nextScan = GetGameTimer() + 250
    end
    local targets, signature = {}, {}
    for _, playerId in ipairs(candidates) do
        if playerId ~= PlayerId() and NetworkIsPlayerActive(playerId) then
            local targetPed = GetPlayerPed(playerId)
            if targetPed ~= 0 and DoesEntityExist(targetPed) and IsEntityVisible(targetPed) then
                local coordinates = GetEntityCoords(targetPed)
                local distance = (origin.x - coordinates.x) ^ 2 + (origin.y - coordinates.y) ^ 2 + (origin.z - coordinates.z) ^ 2
                if distance <= maximumDistance then
                    local visible, screenX, screenY = GetScreenCoordFromWorldCoord(coordinates.x, coordinates.y, coordinates.z + 0.4)
                    if visible and screenX >= 0 and screenX <= 1 and screenY >= 0 and screenY <= 1 then
                        local serverId = GetPlayerServerId(playerId)
                        screenX, screenY = math.floor(screenX * 2000 + 0.5) / 2000, math.floor(screenY * 2000 + 0.5) / 2000
                        targets[#targets + 1] = { id = serverId, x = screenX, y = screenY }
                        signature[#signature + 1] = ('%d:%.4f:%.4f'):format(serverId, screenX, screenY)
                    end
                end
            end
        end
    end
    local encoded = table.concat(signature, '|')
    if encoded ~= lastSignature then
        lastSignature = encoded
        SendNUIMessage({ type = 'nearbyPlayers', players = targets })
    end
end

RegisterNUICallback('givingPreview', function(request, callback)
    if request.active == true then
        active, nextScan, lastSignature = true, 0, nil
        updateTargets()
    else giving.Stop() end
    callback({ ok = true })
end)

CreateThread(function()
    while true do
        Wait(active and 50 or 250)
        if active then updateTargets() end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then giving.Stop() end
end)
