-- Drop contents and locations live only in this resource's server memory.
-- The inventory storage layer independently rejects drop persistence.
function TSSCreateWorldDropService(inventoryContext)
    local inventoryCore = TSSCore
    local worldDrops = {}
    local knownPlayerBuckets = {}
    local nextDropNumber = 0
    local resourceSession = ('%x-%x'):format(os.time(), math.random(1, 0x7fffffff))
    local dropService = {}

    local function getPoolDistance()
        local configuredDistance = Config.WorldDrops.poolDistance
        if type(configuredDistance) ~= 'number' or configuredDistance ~= configuredDistance
            or configuredDistance <= 0 or configuredDistance == math.huge then
            return 5.0
        end

        return configuredDistance
    end

    local function getPlayerLocation(playerSource)
        if not GetPlayerName(playerSource) then return nil end
        local playerPed = GetPlayerPed(playerSource)
        if not playerPed or playerPed == 0 then return nil end

        local coordinates = GetEntityCoords(playerPed)
        if not coordinates then return nil end

        return {
            coords = { x = coordinates.x, y = coordinates.y, z = coordinates.z },
            bucket = GetPlayerRoutingBucket(playerSource),
        }
    end

    local function distanceSquared(firstPosition, secondPosition)
        return (firstPosition.x - secondPosition.x) ^ 2
            + (firstPosition.y - secondPosition.y) ^ 2
            + (firstPosition.z - secondPosition.z) ^ 2
    end

    local function isNearby(playerLocation, worldDrop)
        return playerLocation and playerLocation.bucket == worldDrop.bucket
            and distanceSquared(playerLocation.coords, worldDrop.coords) <= getPoolDistance() ^ 2
    end

    function dropService.IsNearby(playerSource, inventoryId)
        local worldDrop = worldDrops[inventoryId]
        return Config.WorldDrops.enable == true and worldDrop ~= nil
            and isNearby(getPlayerLocation(playerSource), worldDrop) or false
    end

    function dropService.SyncPlayer(playerSource)
        if not GetPlayerName(playerSource) then return end
        local routingBucket = GetPlayerRoutingBucket(playerSource)
        local visibleDrops = {}

        for inventoryId, worldDrop in pairs(worldDrops) do
            if worldDrop.bucket == routingBucket then
                visibleDrops[#visibleDrops + 1] = { id = inventoryId, coords = inventoryCore.copy(worldDrop.coords) }
            end
        end

        knownPlayerBuckets[playerSource] = routingBucket
        TriggerClientEvent('tss-inventory:worldDrops', playerSource, visibleDrops)
    end

    local function syncWorldDrops()
        for _, playerId in ipairs(GetPlayers()) do
            dropService.SyncPlayer(tonumber(playerId))
        end
    end

    function dropService.RefreshSession(playerSource, shouldSend)
        local inventorySession = inventoryContext.sessions[playerSource]
        if not inventorySession then return end

        local playerLocation = getPlayerLocation(playerSource)
        local sessionChanged = false

        for inventoryId in pairs(inventorySession) do
            if inventoryId:sub(1, 5) == 'drop:' then
                local worldDrop = worldDrops[inventoryId]
                if not worldDrop or not isNearby(playerLocation, worldDrop) then
                    inventorySession[inventoryId] = nil
                    sessionChanged = true
                end
            end
        end

        if Config.WorldDrops.enable == true and Config.WorldDrops.openWithTarget ~= true then
            for inventoryId, worldDrop in pairs(worldDrops) do
                if isNearby(playerLocation, worldDrop) and not inventorySession[inventoryId] then
                    inventorySession[inventoryId] = true
                    sessionChanged = true
                end
            end
        end

        if sessionChanged and shouldSend then inventoryContext.send(playerSource) end
    end

    function dropService.Open(playerSource, inventoryId)
        if type(inventoryId) ~= 'string' or not dropService.IsNearby(playerSource, inventoryId) then
            return false, 'Move closer to the world drop'
        end

        return inventoryContext.open(playerSource, inventoryId)
    end

    local function expandForItem(dropInventory, item)
        local itemWidth, itemHeight = inventoryCore.footprint(item)
        while dropInventory.size.x < itemWidth do
            local expandedSize = { x = dropInventory.size.x + 1, y = dropInventory.size.y }
            if not inventoryCore.size(expandedSize) then return nil end
            dropInventory.size = expandedSize
        end
        while dropInventory.size.y < itemHeight do
            local expandedSize = { x = dropInventory.size.x, y = dropInventory.size.y + 1 }
            if not inventoryCore.size(expandedSize) then return nil end
            dropInventory.size = expandedSize
        end
        local itemColumn, itemRow = inventoryCore.space(dropInventory, item)

        while not itemColumn do
            local canGrowDown = dropInventory.size.y < Config.MaxDimension
                and dropInventory.size.x * (dropInventory.size.y + 1) <= Config.MaxCells
            local canGrowAcross = dropInventory.size.x < Config.MaxDimension
                and (dropInventory.size.x + 1) * dropInventory.size.y <= Config.MaxCells

            if canGrowDown then
                dropInventory.size.y = dropInventory.size.y + 1
            elseif canGrowAcross then
                dropInventory.size.x = dropInventory.size.x + 1
            else
                return nil
            end

            itemColumn, itemRow = inventoryCore.space(dropInventory, item)
        end

        return itemColumn, itemRow
    end

    local function planDropTransfer(sourceInventory, dropInventory, itemId, quantity, isRotated)
        local plannedSource = inventoryCore.copy(sourceInventory)
        local plannedDrop = inventoryCore.copy(dropInventory)
        local sourceItem = inventoryCore.find(plannedSource, itemId)
        local placementItem = inventoryCore.copy(sourceItem)
        if isRotated ~= nil then placementItem.rotated = isRotated end
        local itemDefinition = inventoryCore.definition(sourceItem.name)
        local remainingQuantity = quantity

        if itemDefinition.stack then
            for _, targetItem in ipairs(plannedDrop.items) do
                if targetItem.name == sourceItem.name and inventoryCore.equal(targetItem.metadata, sourceItem.metadata) then
                    local transferAmount = math.min(remainingQuantity, itemDefinition.stackSize - targetItem.amount)
                    if transferAmount > 0 then
                        local transferred, transferError = inventoryCore.move(
                            plannedSource, plannedDrop, itemId, transferAmount, targetItem.x, targetItem.y
                        )
                        if not transferred then return nil, nil, transferError end
                        remainingQuantity = remainingQuantity - transferAmount
                    end
                end

                if remainingQuantity == 0 then break end
            end
        end

        if remainingQuantity > 0 then
            local itemColumn, itemRow = expandForItem(plannedDrop, placementItem)
            if not itemColumn then return nil, nil, 'World drop is full' end

            local transferred, transferError = inventoryCore.move(
                plannedSource, plannedDrop, itemId, remainingQuantity, itemColumn, itemRow, isRotated
            )
            if not transferred then return nil, nil, transferError end
        end

        return plannedSource, plannedDrop
    end

    local function makeEmptyDrop(sourceItem, playerLocation)
        local configuredSize = Config.WorldDrops.size or { x = 8, y = 10 }
        if not inventoryCore.size(configuredSize) then return nil, 'Invalid world drop grid size' end
        local itemWidth, itemHeight = inventoryCore.footprint(sourceItem)
        local dropSize = {
            x = math.max(configuredSize.x, itemWidth),
            y = math.max(configuredSize.y, itemHeight),
        }

        if not inventoryCore.size(dropSize) then return nil, 'Invalid world drop grid size' end

        nextDropNumber = nextDropNumber + 1
        return {
            id = ('drop:%s:%s'):format(resourceSession, nextDropNumber),
            type = 'drop',
            persistent = false,
            label = 'World Drop',
            size = dropSize,
            metadata = {},
            items = {},
            nextItemId = 1,
            revision = 0,
            coords = inventoryCore.copy(playerLocation.coords),
            bucket = playerLocation.bucket,
        }
    end

    function dropService.Drop(playerSource, sourceInventory, itemId, quantity, isRotated)
        if inventoryContext.identity(playerSource) ~= sourceInventory.id or sourceInventory.type ~= 'player' then
            return false, 'Only items in your own inventory can be dropped'
        end

        local sourceItem = inventoryCore.find(sourceInventory, itemId)
        if not sourceItem or not inventoryCore.integer(quantity, 1, sourceItem.amount) then
            return false, 'Invalid item or drop quantity'
        end
        if isRotated ~= nil and type(isRotated) ~= 'boolean' then return false, 'Invalid rotation' end
        if inventoryContext.locks[sourceInventory.id] then return false, 'Inventory is busy' end

        if Config.WorldDrops.enable ~= true then
            inventoryCore.remove(sourceInventory, itemId, quantity)
            inventoryContext.commit(sourceInventory)
            return true
        end

        local playerLocation = getPlayerLocation(playerSource)
        if not playerLocation then return false, 'Player position is unavailable' end

        local nearbyDrops = {}
        for inventoryId, worldDrop in pairs(worldDrops) do
            if isNearby(playerLocation, worldDrop) and not inventoryContext.locks[inventoryId] then
                nearbyDrops[#nearbyDrops + 1] = worldDrop
            end
        end

        table.sort(nearbyDrops, function(firstDrop, secondDrop)
            return distanceSquared(playerLocation.coords, firstDrop.coords)
                < distanceSquared(playerLocation.coords, secondDrop.coords)
        end)

        local plannedSource, plannedDrop
        for _, worldDrop in ipairs(nearbyDrops) do
            plannedSource, plannedDrop = planDropTransfer(sourceInventory, worldDrop.inventory, itemId, quantity, isRotated)
            if plannedDrop then break end
        end

        local isNewDrop = plannedDrop == nil
        if isNewDrop then
            local placementItem = inventoryCore.copy(sourceItem)
            if isRotated ~= nil then placementItem.rotated = isRotated end
            local emptyDrop, creationError = makeEmptyDrop(placementItem, playerLocation)
            if not emptyDrop then return false, creationError end
            local transferError
            plannedSource, plannedDrop, transferError = planDropTransfer(sourceInventory, emptyDrop, itemId, quantity, isRotated)
            if not plannedDrop then return false, transferError end
        end

        sourceInventory.items = plannedSource.items
        sourceInventory.nextItemId = plannedSource.nextItemId
        inventoryContext.put(plannedDrop)
        worldDrops[plannedDrop.id] = {
            inventory = plannedDrop,
            coords = plannedDrop.coords,
            bucket = plannedDrop.bucket,
        }

        inventoryContext.commit(sourceInventory, plannedDrop)
        if isNewDrop then syncWorldDrops() end
        return true
    end

    function dropService.AfterCommit(changedInventories)
        local removedDropIds = {}

        for _, inventory in ipairs(changedInventories) do
            if inventory.type == 'drop' and worldDrops[inventory.id] then
                worldDrops[inventory.id].inventory = inventory
                if #inventory.items == 0 then
                    removedDropIds[inventory.id] = true
                    worldDrops[inventory.id] = nil
                    inventoryContext.forget(inventory.id)
                end
            end
        end

        for playerSource, inventorySession in pairs(inventoryContext.sessions) do
            local removedVisibleDrop = false
            for inventoryId in pairs(removedDropIds) do
                if inventorySession[inventoryId] then
                    inventorySession[inventoryId] = nil
                    removedVisibleDrop = true
                end
            end

            dropService.RefreshSession(playerSource, true)
            if removedVisibleDrop then inventoryContext.send(playerSource) end
        end

        if next(removedDropIds) then syncWorldDrops() end
    end

    function dropService.Tick()
        for _, playerId in ipairs(GetPlayers()) do
            local playerSource = tonumber(playerId)
            if knownPlayerBuckets[playerSource] ~= GetPlayerRoutingBucket(playerSource) then
                dropService.SyncPlayer(playerSource)
            end
            dropService.RefreshSession(playerSource, true)
        end
    end

    function dropService.PlayerDisconnected(playerSource)
        knownPlayerBuckets[playerSource] = nil
    end

    return dropService
end
