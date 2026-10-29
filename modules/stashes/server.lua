function TSSCreateStashService(context)
    local service = {}
    local core = TSSCore

    local function baseId(stashName) return 'stash_' .. stashName end

    local function inventoryId(stashName, definition, owner)
        if definition.shared ~= false then return baseId(stashName) end
        return owner and (baseId(stashName) .. ':' .. owner) or nil
    end

    local function isNearby(playerSource, definition)
        local coordinates = TSSStashCoordinates(definition)
        local playerPed = GetPlayerPed(playerSource)
        if not coordinates or not playerPed or playerPed == 0 then return false end
        if definition.bucket ~= nil and GetPlayerRoutingBucket(playerSource) ~= definition.bucket then return false end
        local position = GetEntityCoords(playerPed)
        local distance = (position.x - coordinates.x) ^ 2 + (position.y - coordinates.y) ^ 2 + (position.z - coordinates.z) ^ 2
        return distance <= TSSStashDistance(definition) ^ 2
    end

    function service.CanAccess(playerSource, inventory)
        if inventory.id:sub(1, 6) ~= 'stash_' then return nil end
        for stashName, definition in pairs(TSSStaticStashes) do
            local prefix = baseId(stashName)
            if inventory.id == prefix or inventory.id:sub(1, #prefix + 1) == prefix .. ':' then
                local owner = context.citizen(playerSource)
                return owner ~= nil and inventory.type == 'stash' and inventory.metadata.staticStash == stashName
                    and (definition.shared ~= false or inventory.owner == owner)
                    and inventory.id == inventoryId(stashName, definition, owner) and isNearby(playerSource, definition)
            end
        end
        return nil
    end

    function service.Open(playerSource, stashName)
        if not core.integer(playerSource, 1, 65535) then return false, 'Invalid player' end
        local definition = TSSStaticStashes[stashName]
        if not definition or type(stashName) ~= 'string' or #stashName > 64 or not stashName:match('^[%w_-]+$') then return false, 'Unknown configured stash' end
        if not core.size(definition.size) then return false, 'Invalid configured stash size' end
        if definition.maxWeight ~= nil and (type(definition.maxWeight) ~= 'number' or definition.maxWeight ~= definition.maxWeight
            or definition.maxWeight < 0 or definition.maxWeight == math.huge) then return false, 'Invalid configured stash weight limit' end
        if definition.label ~= nil and (type(definition.label) ~= 'string' or #definition.label > 100) then return false, 'Invalid configured stash label' end
        if definition.shared ~= nil and type(definition.shared) ~= 'boolean' then return false, 'Invalid stash sharing option' end
        for _, fieldName in ipairs({ 'whitelist', 'blacklist' }) do
            if definition[fieldName] ~= nil and type(definition[fieldName]) ~= 'table' then return false, 'Invalid configured stash item rules' end
        end
        if not isNearby(playerSource, definition) then return false, 'Move closer to the stash' end
        local own, playerError = context.player(playerSource)
        if not own then return false, playerError end
        local identifier = inventoryId(stashName, definition, own.owner)
        local inventory = context.load(identifier)
        if not inventory then
            local options = core.copy(definition)
            options.coords = TSSStashCoordinates(definition)
            options.owner = definition.shared == false and own.owner or nil
            options.playerSource = nil
            options.metadata = options.metadata or {}
            options.metadata.staticStash = stashName
            local created, creationError = context.create(identifier, 'stash', options)
            if not created then return false, creationError end
            inventory = context.load(identifier)
        end
        if inventory.type ~= 'stash' or inventory.metadata.staticStash ~= stashName
            or definition.shared == false and inventory.owner ~= own.owner then return false, 'Configured stash ID conflicts with another inventory' end
        if context.locks[inventory.id] then return false, 'Inventory is busy' end
        -- Apply configured size and rules without discarding saved contents or layouts.
        local planned = core.copy(inventory)
        if not core.equal(planned.size, definition.size) then
            local resized, resizeError = core.resize(planned, definition.size, true)
            if not resized then return false, resizeError end
        end
        planned.label = definition.label or stashName
        planned.coords = TSSStashCoordinates(definition)
        planned.whitelist, planned.blacklist = core.copy(definition.whitelist or {}), core.copy(definition.blacklist or {})
        planned.maxWeight = definition.maxWeight
        if planned.maxWeight and core.weight(planned) > planned.maxWeight then return false, 'Existing items exceed the configured stash weight limit' end
        if context.identity(playerSource) ~= own.id or not isNearby(playerSource, definition) then return false, 'Stash is no longer accessible' end
        for _, fieldName in ipairs({ 'label', 'coords', 'size', 'items', 'whitelist', 'blacklist' }) do inventory[fieldName] = planned[fieldName] end
        inventory.maxWeight = planned.maxWeight
        context.commit(inventory)
        return context.open(playerSource, inventory.id)
    end

    function service.OpenNearby(playerSource)
        for stashName, definition in pairs(TSSStaticStashes) do
            if definition.openWhenNearby ~= false and isNearby(playerSource, definition) then service.Open(playerSource, stashName) end
        end
    end

    return service
end
