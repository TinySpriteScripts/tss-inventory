-- Loot is rolled once on creation and never persisted.
function TSSCreateLootService(context)
    local service = {}
    local core = TSSCore

    local function range(value, defaultValue, minimum, maximum, label)
        value = value == nil and defaultValue or value
        local lower = type(value) == 'table' and value.min or value
        local upper = type(value) == 'table' and value.max or value
        if not core.integer(lower, minimum, maximum) or not core.integer(upper, minimum, maximum) or lower > upper then
            return nil, 'Invalid ' .. label
        end
        return { min = lower, max = upper }
    end

    local function roll(bounds)
        if bounds.min == bounds.max then return bounds.min end
        return math.random(bounds.min, bounds.max)
    end

    function service.Create(options, link)
        if type(options) ~= 'table' or type(options.items) ~= 'table' then return false, 'Loot items must be a table' end
        local size = options.size or { x = 8 }
        if type(size) ~= 'table' or not core.integer(size.x, 1, Config.MaxDimension) then return false, 'Invalid loot width' end
        local maximumRows = math.min(Config.MaxDimension, math.floor(Config.MaxCells / size.x))
        if size.y ~= nil and not core.integer(size.y, 1, maximumRows) then return false, 'Invalid loot height' end
        if options.deleteOnEmpty ~= nil and type(options.deleteOnEmpty) ~= 'boolean' then return false, 'Invalid deleteOnEmpty' end
        if options.inventoryId ~= nil and type(options.inventoryId) ~= 'string' then return false, 'Invalid inventory ID' end
        if options.inventoryId and context.load(options.inventoryId) then return false, 'Inventory already exists' end
        local candidates = {}
        for itemName, definition in pairs(options.items) do
            if not core.definition(itemName) or type(definition) ~= 'table' then return false, 'Unknown loot item: ' .. tostring(itemName) end
            local amount, amountError = range(definition.amount, 1, 1, 100000, 'amount for ' .. itemName)
            if not amount then return false, amountError end
            local chance = definition.chance == nil and 100 or definition.chance
            if type(chance) ~= 'number' or chance ~= chance or chance < 0 or chance > 100 then return false, 'Invalid chance for ' .. itemName end
            local metadata, metadataError = context.metadata(definition.metadata or {})
            if not metadata then return false, metadataError end
            candidates[#candidates + 1] = { name = itemName, amount = amount, chance = chance, metadata = metadata }
        end
        local maximumItems, maximumError = range(options.maxItems, #candidates, 0, 100000, 'maxItems')
        if not maximumItems then return false, maximumError end
        -- Sort before shuffling so a map's iteration order does not bias capped rolls.
        table.sort(candidates, function(first, second) return first.name < second.name end)
        for index = #candidates, 2, -1 do
            local swapIndex = math.random(index)
            candidates[index], candidates[swapIndex] = candidates[swapIndex], candidates[index]
        end
        local selected, maximumSelected = 0, roll(maximumItems)
        local plan = { id = options.inventoryId or 'loot_roll', type = 'loot', size = { x = size.x, y = size.y or maximumRows },
            items = {}, metadata = {}, settings = {}, nextItemId = 1, revision = 0 }
        for _, candidate in ipairs(candidates) do
            if selected >= maximumSelected then break end
            if candidate.chance == 100 or candidate.chance > 0 and math.random() * 100 < candidate.chance then
                local amount = roll(candidate.amount)
                local added, addError = core.add(plan, candidate.name, amount, candidate.metadata, false)
                if not added then added, addError = core.add(plan, candidate.name, amount, candidate.metadata, true) end
                if not added then return false, addError end
                selected = selected + 1
            end
        end
        if #plan.items == 0 and options.deleteOnEmpty ~= false then return false, 'Loot roll produced no items' end
        if size.y == nil then
            local repacked, repackError = core.repack(plan, true)
            if not repacked then return false, repackError end
            plan.size.y = 1
            for _, item in ipairs(plan.items) do
                local _, height = core.footprint(item)
                plan.size.y = math.max(plan.size.y, item.y + height - 1)
            end
        end
        local prepared = core.copy(options)
        prepared.size = plan.size
        prepared.inventoryId = prepared.inventoryId or ('loot_%x%x'):format(os.time(), math.random(1, 0x7fffffff))
        return context.create(prepared, plan.items, plan.nextItemId, link)
    end

    function service.Delete(inventory, afterCommit)
        if not inventory.isLoot and inventory.type ~= 'loot' then return false, 'Not a loot container' end
        if context.locks[inventory.id] and not afterCommit then return false, 'Inventory is busy' end
        context.forget(inventory.id)
        for playerSource, session in pairs(context.sessions) do
            if session[inventory.id] then session[inventory.id] = nil; context.send(playerSource) end
        end
        return true
    end

    -- Remove the linked item in the same transaction as taking the last loot.
    function service.Prepare(changedInventories)
        local plans, included, processed, pending = {}, {}, {}, {}
        for _, inventory in ipairs(changedInventories) do
            included[inventory.id] = true
            pending[#pending + 1] = inventory
        end
        local pendingIndex = 1
        while pendingIndex <= #pending do
            local inventory = pending[pendingIndex]
            pendingIndex = pendingIndex + 1
            if inventory.isLoot and inventory.metadata.containerItem and inventory.deleteOnEmpty
                and #inventory.items == 0 and not processed[inventory.id] then
                processed[inventory.id] = true
                for _, parent in ipairs(context.parents(inventory.id)) do
                    if context.locks[parent.inventory.id] and not included[parent.inventory.id] then return false, 'Container inventory is busy' end
                    local plan = plans[parent.inventory.id] or core.copy(parent.inventory)
                    local removed, removeError = core.remove(plan, parent.itemId, 1)
                    if not removed then return false, removeError end
                    plans[parent.inventory.id] = plan
                    pending[#pending + 1] = plan
                end
            end
        end
        for inventoryId, plan in pairs(plans) do
            local inventory = context.load(inventoryId)
            inventory.items, inventory.nextItemId = plan.items, plan.nextItemId
            if not included[inventoryId] then changedInventories[#changedInventories + 1] = inventory end
        end
        return true
    end

    function service.AfterCommit(changedInventories)
        for _, inventory in ipairs(changedInventories) do
            if (inventory.isLoot or inventory.type == 'loot') and inventory.deleteOnEmpty and #inventory.items == 0 then service.Delete(inventory, true) end
        end
    end

    return service
end
