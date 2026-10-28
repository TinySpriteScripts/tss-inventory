-- Derived weights are never persisted; resolve current item links on the server.
function TSSCreateWeightService(context)
    local core = TSSCore
    local service = {}

    core.resolveInventory = context.load
    core.extraInventories = context.extraRoots

    local function loadParents(inventory, overrides, visited)
        if visited[inventory.id] then return end
        visited[inventory.id] = true
        if inventory.type == 'extra' and inventory.owner then
            local playerInventory = context.load('player_' .. inventory.owner)
            if playerInventory then loadParents(playerInventory, overrides, visited) end
        end
        if not inventory.metadata or not inventory.metadata.containerItem then return end
        local foundParent = false
        local parentIds = {}
        for identifier, cached in pairs(context.inventories) do
            local candidate = overrides[identifier] or cached
            for _, item in ipairs(candidate.items) do
                local definition = core.definition(item.name)
                if definition and definition.container == inventory.type and inventory.metadata.containerItem == item.name and item.metadata.containerId == inventory.id then
                    parentIds[identifier] = true
                    foundParent = true
                end
            end
        end
        for identifier, candidate in pairs(overrides) do
            for _, item in ipairs(candidate.items) do
                local definition = core.definition(item.name)
                if definition and definition.container == inventory.type and inventory.metadata.containerItem == item.name and item.metadata.containerId == inventory.id then parentIds[identifier] = true; foundParent = true end
            end
        end
        if not foundParent then
            for _, identifier in ipairs(TSSDatabase.ParentInventoryIds(inventory.id)) do parentIds[identifier] = true end
        end
        for identifier in pairs(parentIds) do
            local parent = overrides[identifier] or context.load(identifier)
            if parent then loadParents(parent, overrides, visited) end
        end
    end

    function service.Validate(overrides)
        if not Config.DynamicContainerWeight then return true end
        local visited = {}
        for _, inventory in pairs(overrides) do loadParents(inventory, overrides, visited) end
        local candidates = {}
        for identifier, inventory in pairs(context.inventories) do candidates[identifier] = overrides[identifier] or inventory end
        for identifier, inventory in pairs(overrides) do candidates[identifier] = inventory end
        for identifier, inventory in pairs(candidates) do
            if inventory.maxWeight then
                local newWeight = core.weight(inventory, overrides)
                local previous = context.committed[identifier]
                local previousWeight = previous and core.weight(previous, context.committed) or 0
                if newWeight > inventory.maxWeight and (not previous or newWeight > previousWeight or inventory.maxWeight ~= previous.maxWeight) then
                    return false, 'Weight limit exceeded'
                end
            end
        end
        return true
    end

    core.validateWeights = service.Validate
    return service
end
