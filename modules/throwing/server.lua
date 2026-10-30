-- Holding does not consume an item. A throw transfers one real instance into a temporary drop.
function TSSCreateThrowingService(context)
    local core = TSSCore
    local heldItems = {}
    local flights = {}
    local nextToken = 0
    local service = {}

    local function finite(number)
        return type(number) == 'number' and number == number and math.abs(number) < math.huge
    end

    local function distanceSquared(first, second)
        return (first.x - second.x) ^ 2 + (first.y - second.y) ^ 2 + (first.z - second.z) ^ 2
    end

    function service.Clear(playerSource, token)
        local held = heldItems[playerSource]
        if not held or (token and held.token ~= token) then return true end
        heldItems[playerSource] = nil
        TriggerClientEvent('tss-inventory:heldItem', playerSource, false)
        return true
    end

    local function carriedItem(playerSource, held)
        if context.identity(playerSource) ~= held.characterId then return nil end
        local inventory, item = context.find(playerSource, { inventoryId = held.inventoryId, id = held.itemId })
        if not item or item.name ~= held.name or context.locks[inventory.id]
            or not context.canUse(playerSource, inventory) then return nil end
        return inventory, item
    end

    function service.Begin(playerSource, inventory, item)
        local definition = item and core.itemDefinition(item)
        if not definition or definition.throwable ~= true then return false, 'Item cannot be held' end
        if context.busy(playerSource) or context.locks[inventory.id] then return false, 'Inventory is busy' end
        if not context.canUse(playerSource, inventory) then return false, 'Use items from your own inventory' end
        if GetEntityHealth(GetPlayerPed(playerSource)) <= 0 then return false, 'Cannot hold items while dead' end
        service.Clear(playerSource)
        context.holster(playerSource)
        context.close(playerSource)
        nextToken = nextToken + 1
        local held = { token = nextToken, inventoryId = inventory.id, itemId = item.id, name = item.name,
            characterId = context.identity(playerSource), expiresAt = GetGameTimer() + 4000, ready = false }
        heldItems[playerSource] = held
        local itemSnapshot = core.itemView(item)
        itemSnapshot.definition = definition
        TriggerClientEvent('tss-inventory:heldItem', playerSource, { token = held.token, item = itemSnapshot })
        SetTimeout(4000, function()
            if heldItems[playerSource] == held and not held.ready then service.Clear(playerSource, held.token) end
        end)
        return true
    end

    function service.Ready(playerSource, token)
        local held = heldItems[playerSource]
        if not held or held.token ~= token or held.ready or GetGameTimer() > held.expiresAt then return false end
        if not carriedItem(playerSource, held) then service.Clear(playerSource); return false end
        held.ready = true
        local idleTimeout = TSSThrowing.Settings().idleTimeout
        held.expiresAt = idleTimeout > 0 and GetGameTimer() + idleTimeout or nil
        if idleTimeout > 0 then
            SetTimeout(idleTimeout, function()
                if heldItems[playerSource] == held and held.expiresAt and GetGameTimer() >= held.expiresAt then service.Clear(playerSource, token) end
            end)
        end
        return true
    end

    function service.Act(playerSource, token, action, direction)
        local held = heldItems[playerSource]
        if not held or held.token ~= token then return false end
        if action == 'cancel' then return service.Clear(playerSource, token) end
        if not held.ready or (held.expiresAt and GetGameTimer() > held.expiresAt) then service.Clear(playerSource); return false end
        local inventory, item = carriedItem(playerSource, held)
        if not item or context.busy(playerSource) or GetEntityHealth(GetPlayerPed(playerSource)) <= 0 then
            service.Clear(playerSource)
            return false, 'Item is no longer available'
        end
        if action == 'use' then
            service.Clear(playerSource)
            return context.use(playerSource, { inventoryId = inventory.id, id = item.id })
        end
        if action == 'charge' then
            if held.chargeStarted then return false end
            held.chargeStarted = GetGameTimer()
            local chargeTimeout = TSSThrowing.Settings().chargeTimeout
            held.expiresAt = chargeTimeout > 0 and GetGameTimer() + chargeTimeout or nil
            if chargeTimeout > 0 then
                SetTimeout(chargeTimeout, function()
                    if heldItems[playerSource] == held then service.Clear(playerSource, token) end
                end)
            end
            return true
        end
        if action ~= 'throw' then return false end
        if not held.chargeStarted then return false end
        if Config.WorldDrops.enable ~= true then service.Clear(playerSource); return false, 'World drops are disabled' end
        if type(direction) ~= 'table' or not finite(direction.x) or not finite(direction.y) or not finite(direction.z) then return false end
        local lengthSquared = direction.x ^ 2 + direction.y ^ 2 + direction.z ^ 2
        if lengthSquared < 0.9 or lengthSquared > 1.1 then return false end
        local settings = TSSThrowing.Settings()
        local power = TSSThrowing.Power(GetGameTimer() - held.chargeStarted)
        local thrown, dropId, origin = context.drops.BeginThrow(playerSource, inventory, item.id)
        if not thrown then service.Clear(playerSource); return false, dropId end
        heldItems[playerSource] = nil
        local flight = { token = token, dropId = dropId, origin = origin, started = GetGameTimer(),
            characterId = held.characterId, bucket = GetPlayerRoutingBucket(playerSource),
            maxDistance = math.max(3.0, settings.maxDistance * power / settings.maxPower),
            maxSpeed = (settings.speed + settings.lift) * math.sqrt(power) + 5.0 }
        flights[playerSource] = flights[playerSource] or {}
        flights[playerSource][token] = flight
        TriggerClientEvent('tss-inventory:throwItem', playerSource, { token = token, direction = direction, power = power })
        -- A disconnected client, missing model or lost landing report cannot lose the item.
        SetTimeout(8000, function()
            context.operation(function()
                if flights[playerSource] and flights[playerSource][token] == flight then
                    context.drops.FinishThrow(dropId, origin)
                    flights[playerSource][token] = nil
                end
            end)
        end)
        return true
    end

    function service.Landed(playerSource, token, coordinates)
        local flight = flights[playerSource] and flights[playerSource][token]
        if not flight or context.identity(playerSource) ~= flight.characterId
            or GetPlayerRoutingBucket(playerSource) ~= flight.bucket then return false end
        local elapsed = GetGameTimer() - flight.started
        if elapsed < 400 or elapsed > 8000 or type(coordinates) ~= 'table' then return false end
        for _, axis in ipairs({ 'x', 'y', 'z' }) do
            if not finite(coordinates[axis]) then return false end
        end
        -- The client supplies only the collision endpoint of a server-authorised throw.
        -- It cannot select contents, quantity, bucket or an arbitrary distant location.
        local maximumDistance = math.min(flight.maxDistance, 3.0 + elapsed / 1000 * flight.maxSpeed)
        if distanceSquared(coordinates, flight.origin) > maximumDistance ^ 2 then return false end
        context.drops.FinishThrow(flight.dropId, { x = coordinates.x, y = coordinates.y, z = coordinates.z })
        flights[playerSource][token] = nil
        return true
    end

    function service.Disconnect(playerSource)
        service.Clear(playerSource)
        for _, flight in pairs(flights[playerSource] or {}) do context.drops.FinishThrow(flight.dropId, flight.origin) end
        flights[playerSource] = nil
    end

    return service
end
