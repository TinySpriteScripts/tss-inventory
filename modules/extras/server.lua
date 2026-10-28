-- Character-owned extension windows. Definitions live in config or personal settings.
function TSSCreateExtraInventoryService(context)
    local inventoryCore = TSSCore
    local definitions = inventoryCore.copy(Config.ExtraInventories or {})
    local service = {}

    local function validName(slotName)
        return type(slotName) == 'string' and #slotName > 0 and #slotName <= 64 and slotName:match('^[%w_-]+$') ~= nil
    end

    local function validateDefinition(definition)
        if type(definition) ~= 'table' or not inventoryCore.size(definition.size) then return nil, 'Invalid extra inventory size' end
        if type(definition.label) ~= 'string' or #definition.label > 100 then return nil, 'Invalid extra inventory label' end
        local metadata, metadataError = context.metadata(definition.metadata or {})
        if not metadata then return nil, metadataError end
        for _, fieldName in ipairs({ 'whitelist', 'blacklist' }) do
            if definition[fieldName] ~= nil and type(definition[fieldName]) ~= 'table' then return nil, 'Invalid item restrictions' end
            for _, itemName in ipairs(definition[fieldName] or {}) do
                if not inventoryCore.definition(itemName) then return nil, 'Unknown restricted item: ' .. tostring(itemName) end
            end
        end
        if definition.maxWeight ~= nil and (type(definition.maxWeight) ~= 'number' or definition.maxWeight ~= definition.maxWeight
            or definition.maxWeight < 0 or definition.maxWeight == math.huge) then return nil, 'Invalid weight limit' end
        return { label = definition.label, size = inventoryCore.copy(definition.size), metadata = metadata,
            whitelist = inventoryCore.copy(definition.whitelist or {}), blacklist = inventoryCore.copy(definition.blacklist or {}), maxWeight = definition.maxWeight }
    end

    local function effectiveDefinitions(ownInventory, includeDisabled)
        local result = inventoryCore.copy(definitions)
        for slotName, definition in pairs(ownInventory.settings.extraInventoryDefinitions or {}) do result[slotName] = inventoryCore.copy(definition) end
        if not includeDisabled then
            for slotName, disabled in pairs(ownInventory.settings.disabledExtraInventories or {}) do if disabled then result[slotName] = nil end end
        end
        return result
    end

    local function inventoryId(ownInventory, slotName) return 'extra_' .. ownInventory.owner .. ':' .. slotName end

    local function ensureInventory(playerSource, ownInventory, slotName, definition, linkedInventory)
        if not validName(slotName) then return nil, 'Invalid extra inventory name' end
        local validated, validationError = validateDefinition(definition)
        if not validated then return nil, validationError end
        local identifier = inventoryId(ownInventory, slotName)
        local inventory = context.load(identifier)
        if not inventory then
            validated.playerSource = playerSource
            local created, creationError = context.create(identifier, 'extra', validated, linkedInventory)
            if not created then return nil, creationError end
            inventory = context.load(identifier)
        end
        if inventory.type ~= 'extra' or inventory.owner ~= ownInventory.owner then return nil, 'Extra inventory ownership conflict' end
        return inventory
    end

    function service.Definitions(playerSource)
        if not playerSource then return inventoryCore.copy(definitions) end
        local ownInventory, playerError = context.player(playerSource)
        if not ownInventory then return nil, playerError end
        return effectiveDefinitions(ownInventory)
    end

    function service.Get(playerSource, slotName)
        local ownInventory, playerError = context.player(playerSource)
        if not ownInventory then return nil, playerError end
        local definition = effectiveDefinitions(ownInventory)[slotName]
        if not definition then return nil, 'Extra inventory is not enabled' end
        return ensureInventory(playerSource, ownInventory, slotName, definition)
    end

    function service.Roots(playerSource, createMissing)
        local ownInventory, playerError = context.player(playerSource)
        if not ownInventory then return {}, playerError end
        local inventories = {}
        for slotName, definition in pairs(effectiveDefinitions(ownInventory)) do
            local inventory, inventoryError
            if createMissing then inventory, inventoryError = ensureInventory(playerSource, ownInventory, slotName, definition)
            else inventory = context.load(inventoryId(ownInventory, slotName)) end
            if inventoryError then return nil, inventoryError end
            if inventory and inventory.type == 'extra' and inventory.owner == ownInventory.owner then inventories[#inventories + 1] = inventory end
        end
        table.sort(inventories, function(firstInventory, secondInventory) return firstInventory.id < secondInventory.id end)
        return inventories
    end

    function service.RootsForInventory(ownInventory)
        local inventories = {}
        for slotName in pairs(effectiveDefinitions(ownInventory)) do
            local inventory = context.load(inventoryId(ownInventory, slotName))
            if inventory and inventory.type == 'extra' and inventory.owner == ownInventory.owner then inventories[#inventories + 1] = inventory end
        end
        return inventories
    end

    function service.CanAccess(playerSource, identifier)
        local citizenId = TSSDatabase.CitizenId(playerSource)
        local inventory = context.load(identifier)
        if not citizenId or not inventory or inventory.type ~= 'extra' or inventory.owner ~= citizenId then return false end
        local ownInventory = context.load('player_' .. citizenId)
        if not ownInventory then return false end
        for slotName in pairs(effectiveDefinitions(ownInventory)) do
            if identifier == inventoryId(ownInventory, slotName) then return true end
        end
        return false
    end

    function service.Grant(playerSource)
        local inventories, inventoryError = service.Roots(playerSource, true)
        if not inventories then return false, inventoryError end
        for _, inventory in ipairs(inventories) do context.sessions[playerSource][inventory.id] = true end
        return true
    end

    function service.Register(slotName, definition)
        if not validName(slotName) then return false, 'Invalid extra inventory name' end
        local validated, validationError = validateDefinition(definition)
        if not validated then return false, validationError end
        local count = 0
        for _ in pairs(definitions) do count = count + 1 end
        if not definitions[slotName] and count >= 32 then return false, 'Too many extra inventory definitions' end
        definitions[slotName] = validated
        return true
    end

    function service.Update(playerSource, slotName, changes, shouldRepack)
        if not validName(slotName) or type(changes) ~= 'table' then return false, 'Invalid extra inventory definition' end
        local ownInventory, playerError = context.player(playerSource)
        if not ownInventory then return false, playerError end
        local currentDefinitions = effectiveDefinitions(ownInventory, true)
        local definition = inventoryCore.copy(currentDefinitions[slotName] or {})
        local inventory = context.load(inventoryId(ownInventory, slotName))
        if inventory then
            for _, fieldName in ipairs({ 'label', 'size', 'metadata', 'whitelist', 'blacklist', 'maxWeight' }) do
                definition[fieldName] = inventoryCore.copy(inventory[fieldName])
            end
        end
        if not currentDefinitions[slotName] then
            local count = 0
            for _ in pairs(currentDefinitions) do count = count + 1 end
            if count >= 32 then return false, 'Too many extra inventories' end
        end
        for fieldName, value in pairs(changes) do definition[fieldName] = inventoryCore.copy(value) end
        local validated, validationError = validateDefinition(definition)
        if not validated then return false, validationError end
        if inventory then
            if inventory.type ~= 'extra' or inventory.owner ~= ownInventory.owner then return false, 'Extra inventory ownership conflict' end
            local planned = inventoryCore.copy(inventory)
            local resized, resizeError = inventoryCore.resize(planned, validated.size, shouldRepack == true)
            if not resized then return false, resizeError end
            planned.whitelist, planned.blacklist, planned.maxWeight = validated.whitelist, validated.blacklist, validated.maxWeight
            for _, item in ipairs(planned.items) do if not inventoryCore.allowed(planned, item.name) then return false, 'Existing items violate restrictions' end end
            if planned.maxWeight and inventoryCore.weight(planned) > planned.maxWeight then return false, 'Existing items exceed weight limit' end
            inventory.items, inventory.size = planned.items, planned.size
            inventory.label, inventory.metadata = validated.label, validated.metadata
            inventory.whitelist, inventory.blacklist, inventory.maxWeight = validated.whitelist, validated.blacklist, validated.maxWeight
        end
        ownInventory.settings.extraInventoryDefinitions = ownInventory.settings.extraInventoryDefinitions or {}
        ownInventory.settings.extraInventoryDefinitions[slotName] = validated
        ownInventory.settings.disabledExtraInventories = ownInventory.settings.disabledExtraInventories or {}
        ownInventory.settings.disabledExtraInventories[slotName] = nil
        if inventory then context.commit(ownInventory, inventory)
        else
            local creationError
            inventory, creationError = ensureInventory(playerSource, ownInventory, slotName, validated, ownInventory)
            if not inventory then context.restore(ownInventory.id); return false, creationError end
        end
        if context.sessions[playerSource] then service.Grant(playerSource); context.send(playerSource) end
        return true, inventoryCore.copy(inventory)
    end

    function service.Create(playerSource, slotName, definition)
        return service.Update(playerSource, slotName, definition or {})
    end

    function service.Remove(playerSource, slotName)
        if not validName(slotName) then return false, 'Invalid extra inventory name' end
        local ownInventory, playerError = context.player(playerSource)
        if not ownInventory then return false, playerError end
        if not effectiveDefinitions(ownInventory)[slotName] then return false, 'Extra inventory is not enabled' end
        local inventory = context.load(inventoryId(ownInventory, slotName))
        if inventory and #inventory.items > 0 then return false, 'Empty the extra inventory before removing it' end
        ownInventory.settings.disabledExtraInventories = ownInventory.settings.disabledExtraInventories or {}
        ownInventory.settings.disabledExtraInventories[slotName] = true
        context.commit(ownInventory)
        return true
    end

    return service
end
