-- Nearby transfers use the same atomic storage path as inventory moves.
function TSSCreateGivingService(context)
    local service = {}
    local core = TSSCore

    local function location(playerSource)
        if not GetPlayerName(playerSource) or not context.identity(playerSource) then return nil end
        local playerPed = GetPlayerPed(playerSource)
        if not playerPed or playerPed == 0 then return nil end
        return GetEntityCoords(playerPed), GetPlayerRoutingBucket(playerSource)
    end

    local function distanceSquared(first, second)
        return (first.x - second.x) ^ 2 + (first.y - second.y) ^ 2 + (first.z - second.z) ^ 2
    end

    local function nearestPlayer(playerSource, origin, bucket)
        local nearest, nearestDistance
        for _, playerId in ipairs(GetPlayers()) do
            local candidate = tonumber(playerId)
            if candidate and candidate ~= playerSource then
                local coordinates, candidateBucket = location(candidate)
                local distance = coordinates and bucket == candidateBucket and distanceSquared(origin, coordinates)
                if distance and distance <= TSSGivingDistance() ^ 2 and (not nearestDistance or distance < nearestDistance
                    or distance == nearestDistance and candidate < nearest) then
                    nearest, nearestDistance = candidate, distance
                end
            end
        end
        return nearest
    end

    function service.Give(playerSource, sourceInventory, request)
        local carried, item = context.find(playerSource, { inventoryId = sourceInventory.id, id = request.itemId })
        if not carried or not item then return false, 'Give items from your own inventory' end
        if not core.integer(request.amount, 1, item.amount) then return false, 'Invalid transfer amount' end
        local origin, bucket = location(playerSource)
        if not origin then return false, 'Player is unavailable' end
        local recipient = request.targetPlayer
        if recipient == nil then recipient = nearestPlayer(playerSource, origin, bucket) end
        if not core.integer(recipient, 1, 65535) or recipient == playerSource then return false, 'No player nearby' end
        local destination, recipientBucket = location(recipient)
        if not destination or recipientBucket ~= bucket or distanceSquared(origin, destination) > TSSGivingDistance() ^ 2 then
            return false, 'Player is no longer nearby'
        end
        local targetInventory, targetError = context.player(recipient)
        if not targetInventory then return false, targetError or 'Player inventory is unavailable' end
        if targetInventory.id == carried.id then return false, 'Choose another player' end
        if context.busy(playerSource) or context.busy(recipient) or context.locks[carried.id] or context.locks[targetInventory.id] then
            return false, 'Inventory is busy'
        end
        local moved, moveError = core.quickMove(carried, targetInventory, item.id, request.amount)
        if not moved then return false, moveError end
        context.commit(carried, targetInventory)
        context.itemBox(playerSource, item, 'removed', request.amount)
        context.itemBox(recipient, item, 'added', request.amount)
        return true
    end

    return service
end
