-- Export conveniences only. No framework object, core patching or duplicate storage.
function TSSRegisterItemExports(context)
    local core = TSSCore
    local helpers = TSSItemExports

    local function inventoryFor(identifier)
        if type(identifier) == 'number' then return context.player(identifier) end
        return context.load(identifier)
    end

    local function view(item) return item and helpers.Item(core.copy(item), core.definition(item.name)) or nil end

    local function matchingItems(identifier, itemName)
        local inventory = inventoryFor(identifier)
        local items = {}
        if not inventory or type(itemName) ~= 'string' then return items end
        for _, item in ipairs(inventory.items) do if item.name:lower() == itemName:lower() then items[#items + 1] = view(item) end end
        return items
    end

    context.export('HasItem', function(identifier, requirements, amount)
        local inventory = inventoryFor(identifier)
        return inventory and helpers.HasItem(inventory.items, requirements, amount) or false
    end)

    context.export('CanAddItem', function(identifier, itemName, amount, metadata)
        local inventory = inventoryFor(identifier)
        local definition = core.definition(itemName)
        if not inventory or not definition then return false, 'Unknown inventory or item' end
        if inventory.type == 'shop' then return false, 'Shop catalogue is read-only' end
        local cleaned, metadataError = context.metadata(metadata or definition.metadata)
        if not cleaned then return false, metadataError end
        return core.add(core.copy(inventory), itemName, amount or 1, cleaned)
    end)

    context.export('GetItemBySlot', function(identifier, slot)
        local inventory = inventoryFor(identifier)
        return inventory and view(core.find(inventory, tonumber(slot))) or nil
    end)

    context.export('GetItemByName', function(identifier, itemName) return matchingItems(identifier, itemName)[1] end)
    context.export('GetItemsByName', matchingItems)

    context.export('GetTotalWeight', function(items)
        if type(items) ~= 'table' then return 0 end
        local total = 0
        for _, item in pairs(items) do
            if type(item) == 'table' then
                local definition = core.definition(item.name)
                total = total + (definition and definition.weight or tonumber(item.weight) or 0) * (tonumber(item.amount or item.count) or 0)
            end
        end
        return total
    end)

    context.export('GetFreeWeight', function(identifier)
        local inventory = inventoryFor(identifier)
        if not inventory then return 0 end
        if inventory.maxWeight == nil then return math.huge end
        return math.max(0, inventory.maxWeight - core.weight(inventory))
    end)

    local function slotsByItem(items, itemName)
        local slots = {}
        if type(items) ~= 'table' or type(itemName) ~= 'string' then return slots end
        for _, item in pairs(items) do
            if type(item) == 'table' and type(item.name) == 'string' and item.name:lower() == itemName:lower() then
                local slot = tonumber(item.slot or item.id)
                if slot then slots[#slots + 1] = slot end
            end
        end
        table.sort(slots)
        return slots
    end

    context.export('GetSlotsByItem', slotsByItem)
    context.export('GetFirstSlotByItem', function(items, itemName) return slotsByItem(items, itemName)[1] end)

    context.export('GetSlots', function(identifier)
        local inventory = inventoryFor(identifier)
        if not inventory then return 0, 0 end
        local used = 0
        for _, item in ipairs(inventory.items) do
            local width, height = core.footprint(item)
            used = used + width * height
        end
        return used, inventory.size.x * inventory.size.y - used
    end)

    context.export('SetItemData', function(identifier, itemName, key, value, slot)
        local inventory = inventoryFor(identifier)
        if not inventory or type(key) ~= 'string' or #key == 0 then return false, 'Invalid item data' end
        local selected = slot and slot ~= false and core.find(inventory, tonumber(slot)) or nil
        if not selected then
            if slot and slot ~= false then return false, 'Slot not found' end
            for _, item in ipairs(inventory.items) do if item.name == itemName then selected = item; break end end
        end
        if not selected or selected.name ~= itemName then return false, 'Item not found' end
        local metadata = core.copy(selected.metadata)
        if key == 'info' or key == 'metadata' then metadata = value else metadata[key] = value end
        local cleaned, metadataError = context.metadata(metadata)
        if not cleaned then return false, metadataError end
        if selected.metadata.containerId then cleaned.containerId = selected.metadata.containerId end
        return context.mutate(inventory.id, function(current)
            local item = core.find(current, selected.id)
            item.metadata = cleaned
            return true
        end)
    end)

    local function clearInventory(identifier, filter)
        local inventory = inventoryFor(identifier)
        if not inventory then return false, 'Inventory not found' end
        local keep = {}
        if type(filter) == 'string' then keep[filter] = true
        elseif type(filter) == 'table' then
            for _, name in ipairs(filter) do if type(name) ~= 'string' then return false, 'Invalid filter' end; keep[name] = true end
        elseif filter ~= nil then return false, 'Invalid filter' end
        return context.mutate(inventory.id, function(current)
            local retained = {}
            for _, item in ipairs(current.items) do if keep[item.name] then retained[#retained + 1] = item end end
            current.items = retained
            return true
        end)
    end

    context.export('ClearInventory', clearInventory)
    context.export('ClearStash', function(identifier)
        local inventory = context.load(identifier)
        if not inventory or inventory.type == 'player' or inventory.type == 'shop' or inventory.type == 'drop' then return false, 'Invalid stash' end
        return clearInventory(identifier)
    end)

    local function registerUsable(itemName, callback)
        if type(callback) == 'table' and rawget(callback, '__cfx_functionReference') == nil then
            callback = callback.func or callback.cb or callback.callback
        end
        local isCallable = type(callback) == 'function' or (type(callback) == 'table' and rawget(callback, '__cfx_functionReference') ~= nil)
        if not core.definition(itemName) or not isCallable then return false, 'Invalid usable item' end
        context.handlers[itemName] = {
            resource = GetInvokingResource(),
            handler = function(playerSource, item, inventoryId) callback(playerSource, view(item), inventoryId) end,
        }
        return true
    end

    -- Registration must also work before the database is ready.
    exports('CreateUsableItem', registerUsable)
    exports('CreateUseableItem', registerUsable)
    exports('GetUsableItem', function(itemName)
        local registration = context.handlers[itemName]
        return registration and { func = registration.handler, resource = registration.resource } or nil
    end)
end
