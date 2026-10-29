-- Pure inventory operations: no networking, framework calls or database access.
TSSCore = {}
local inventoryCore = TSSCore

function inventoryCore.copy(value, visitedTables)
    if type(value) ~= 'table' then return value end
    visitedTables = visitedTables or {}
    if visitedTables[value] then error('Cyclic table') end
    visitedTables[value] = true

    local copiedValue = {}
    for fieldName, fieldValue in pairs(value) do
        copiedValue[fieldName] = inventoryCore.copy(fieldValue, visitedTables)
    end

    visitedTables[value] = nil
    return copiedValue
end

function inventoryCore.equal(firstValue, secondValue)
    if type(firstValue) ~= type(secondValue) then return false end
    if type(firstValue) ~= 'table' then return firstValue == secondValue end

    for fieldName, fieldValue in pairs(firstValue) do
        if not inventoryCore.equal(fieldValue, secondValue[fieldName]) then return false end
    end
    for fieldName in pairs(secondValue) do
        if firstValue[fieldName] == nil then return false end
    end
    return true
end

function inventoryCore.integer(value, minimum, maximum)
    return type(value) == 'number' and value == value and value % 1 == 0
        and value >= minimum and value <= maximum
end

function inventoryCore.size(size)
    return type(size) == 'table' and inventoryCore.integer(size.x, 1, Config.MaxDimension)
        and inventoryCore.integer(size.y, 1, Config.MaxDimension) and size.x * size.y <= Config.MaxCells
end

function inventoryCore.definition(itemName)
    if type(itemName) ~= 'string' or not TSSItems[itemName] then return nil end
    local definition = inventoryCore.copy(Config.ItemDefaults)
    for fieldName, fieldValue in pairs(TSSItems[itemName]) do definition[fieldName] = inventoryCore.copy(fieldValue) end
    definition.name = itemName
    if Config.MoneyAsItem and itemName == 'cash' then
        definition.stack = true
        definition.stackSize = 2147483647
        definition.weight = 0
    end
    definition.stackSize = definition.stack and definition.stackSize or 1
    return definition
end

-- Resolve display labels on copies; shared item definitions stay unchanged.
function inventoryCore.itemDefinition(item)
    local definition = inventoryCore.definition(item.name)
    if definition then
        definition.label = TSSItemExports.Label(item.metadata, definition.label or item.name)
        if TSSWeaponData then definition.weight = definition.weight + TSSWeaponData.AttachedWeight(item) end
        if definition.container and TSSContainers and TSSContainers[definition.container] then
            local container = TSSContainers[definition.container]
            definition.containerRules = { whitelist = inventoryCore.copy(container.whitelist or {}),
                blacklist = inventoryCore.copy(container.blacklist or {}) }
        end
    end
    return definition
end

function inventoryCore.itemView(item)
    local result = inventoryCore.copy(item)
    local definition = inventoryCore.definition(item.name)
    result.label = TSSItemExports.Label(item.metadata, definition and definition.label or item.name)
    return result
end

function inventoryCore.inventoryView(inventory)
    local result = inventoryCore.copy(inventory)
    result.label = TSSItemExports.Label(inventory.metadata, inventory.label)
    for itemIndex, item in ipairs(inventory.items) do result.items[itemIndex] = inventoryCore.itemView(item) end
    return result
end

function inventoryCore.allowed(inventory, itemName)
    local function listContains(itemList)
        for _, listedName in ipairs(itemList or {}) do if listedName == itemName then return true end end
        return false
    end

    if inventory.whitelist and #inventory.whitelist > 0 and not listContains(inventory.whitelist) then return false end
    return not listContains(inventory.blacklist)
end

function inventoryCore.footprint(item)
    local definition = inventoryCore.definition(item.name)
    if not definition then return nil end
    if item.rotated == true then return definition.size.y, definition.size.x end
    return definition.size.x, definition.size.y
end

function inventoryCore.fits(inventory, item, column, row, ignoredItemId)
    local itemWidth, itemHeight = inventoryCore.footprint(item)
    if not itemWidth or not inventoryCore.integer(column, 1, inventory.size.x)
        or not inventoryCore.integer(row, 1, inventory.size.y) then return false end
    if column + itemWidth - 1 > inventory.size.x or row + itemHeight - 1 > inventory.size.y then return false end

    for _, otherItem in ipairs(inventory.items) do
        if otherItem.id ~= ignoredItemId then
            local otherWidth, otherHeight = inventoryCore.footprint(otherItem)
            if not otherWidth then return false end
            if column < otherItem.x + otherWidth and column + itemWidth > otherItem.x
                and row < otherItem.y + otherHeight and row + itemHeight > otherItem.y then return false end
        end
    end
    return true
end

function inventoryCore.space(inventory, item)
    for row = 1, inventory.size.y do
        for column = 1, inventory.size.x do
            if inventoryCore.fits(inventory, item, column, row) then return column, row end
        end
    end
end

function inventoryCore.find(inventory, itemId)
    for itemIndex, item in ipairs(inventory.items) do if item.id == itemId then return item, itemIndex end end
end

function inventoryCore.weight(inventory, overrides, visitedInventories)
    overrides = overrides or {}
    inventory = overrides[inventory.id] or inventory
    visitedInventories = visitedInventories or {}
    if visitedInventories[inventory.id] then return 0 end
    visitedInventories[inventory.id] = true
    local totalWeight = 0
    for _, item in ipairs(inventory.items) do
        local definition = inventoryCore.definition(item.name)
        totalWeight = totalWeight + (definition.weight + (TSSWeaponData and TSSWeaponData.AttachedWeight(item) or 0)) * item.amount
        local containerId = definition.container and item.metadata and item.metadata.containerId
        if Config.DynamicContainerWeight and type(containerId) == 'string' and inventoryCore.resolveInventory then
            local container = overrides[containerId] or inventoryCore.resolveInventory(containerId)
            if container and container.type == definition.container and container.metadata.containerItem == item.name then
                totalWeight = totalWeight + inventoryCore.weight(container, overrides, visitedInventories)
            end
        end
    end
    if Config.DynamicContainerWeight and inventory.type == 'player' and inventoryCore.extraInventories then
        for _, extraInventory in ipairs(inventoryCore.extraInventories(inventory)) do
            totalWeight = totalWeight + inventoryCore.weight(extraInventory, overrides, visitedInventories)
        end
    end
    return totalWeight
end

local function validatePlannedWeight(plannedInventories)
    if Config.DynamicContainerWeight and inventoryCore.validateWeights then return inventoryCore.validateWeights(plannedInventories) end
    for _, inventory in pairs(plannedInventories) do
        if inventory.maxWeight and inventoryCore.weight(inventory) > inventory.maxWeight then return false, 'Weight limit exceeded' end
    end
    return true
end

function inventoryCore.add(inventory, itemName, amount, metadata, isRotated, weightOverrides)
    local definition = inventoryCore.definition(itemName)
    if not definition then return false, 'Unknown item' end
    if not inventoryCore.integer(amount, 1, 100000) then return false, 'Invalid amount' end
    if isRotated ~= nil and type(isRotated) ~= 'boolean' then return false, 'Invalid rotation' end
    if not inventoryCore.allowed(inventory, itemName) then return false, 'Item is not allowed in this inventory' end

    local plannedInventory = inventoryCore.copy(inventory)
    local defaultMetadata = inventoryCore.copy(definition.metadata or {})
    for metadataKey, metadataValue in pairs(metadata or {}) do
        defaultMetadata[metadataKey] = inventoryCore.copy(metadataValue)
    end
    metadata = defaultMetadata

    for _, item in ipairs(plannedInventory.items) do
        if definition.stack and item.name == itemName and inventoryCore.equal(item.metadata, metadata) then
            local movedAmount = math.min(amount, math.max(0, definition.stackSize - item.amount))
            item.amount = item.amount + movedAmount
            amount = amount - movedAmount
            if amount == 0 then break end
        end
    end

    while amount > 0 do
        local item = { name = itemName, amount = math.min(amount, definition.stackSize),
            metadata = inventoryCore.copy(metadata), rotated = isRotated == true }
        local column, row = inventoryCore.space(plannedInventory, item)
        if not column then return false, 'Not enough grid space' end
        item.id = plannedInventory.nextItemId
        item.x = column
        item.y = row
        plannedInventory.nextItemId = plannedInventory.nextItemId + 1
        plannedInventory.items[#plannedInventory.items + 1] = item
        amount = amount - item.amount
    end

    local plannedWeights = {}
    for inventoryId, planned in pairs(weightOverrides or {}) do plannedWeights[inventoryId] = planned end
    plannedWeights[plannedInventory.id] = plannedInventory
    local weightValid, weightError = validatePlannedWeight(plannedWeights)
    if not weightValid then return false, weightError end
    inventory.items = plannedInventory.items
    inventory.nextItemId = plannedInventory.nextItemId
    return true
end

function inventoryCore.remove(inventory, itemId, amount)
    local item, itemIndex = inventoryCore.find(inventory, itemId)
    if not item or not inventoryCore.integer(amount, 1, item.amount) then return false, 'Invalid item or amount' end
    if amount == item.amount then table.remove(inventory.items, itemIndex) else item.amount = item.amount - amount end
    return true
end

function inventoryCore.move(sourceInventory, targetInventory, itemId, amount, column, row, isRotated)
    local sourceItem = inventoryCore.find(sourceInventory, itemId)
    if not sourceItem or not inventoryCore.integer(amount, 1, sourceItem.amount) then return false, 'Invalid item or amount' end
    if isRotated ~= nil and type(isRotated) ~= 'boolean' then return false, 'Invalid rotation' end
    if isRotated == nil then isRotated = sourceItem.rotated == true end
    if not inventoryCore.integer(column, 1, targetInventory.size.x)
        or not inventoryCore.integer(row, 1, targetInventory.size.y) then return false, 'Invalid position' end
    if not inventoryCore.allowed(targetInventory, sourceItem.name) then return false, 'Item is not allowed here' end

    local definition = inventoryCore.definition(sourceItem.name)

    local plannedSource = inventoryCore.copy(sourceInventory)
    local plannedTarget = sourceInventory == targetInventory and plannedSource or inventoryCore.copy(targetInventory)
    local plannedItem = inventoryCore.find(plannedSource, itemId)
    local targetStack = nil

    for _, targetItem in ipairs(plannedTarget.items) do
        local targetWidth, targetHeight = inventoryCore.footprint(targetItem)
        if column >= targetItem.x and column < targetItem.x + targetWidth
            and row >= targetItem.y and row < targetItem.y + targetHeight
            and not (sourceInventory == targetInventory and targetItem.id == itemId) then
            targetStack = targetItem
            break
        end
    end

    if targetStack then
        if not definition.stack or targetStack.name ~= plannedItem.name
            or not inventoryCore.equal(targetStack.metadata, plannedItem.metadata)
            or targetStack.amount + amount > definition.stackSize then return false, 'Items cannot stack here' end
        targetStack.amount = targetStack.amount + amount
        inventoryCore.remove(plannedSource, itemId, amount)
    else
        local movedItem = inventoryCore.copy(plannedItem)
        inventoryCore.remove(plannedSource, itemId, amount)
        movedItem.amount = amount
        movedItem.x = column
        movedItem.y = row
        movedItem.rotated = isRotated
        if not inventoryCore.fits(plannedTarget, movedItem, column, row) then return false, 'Space is occupied or outside grid' end
        if sourceInventory ~= targetInventory or amount < sourceItem.amount then
            movedItem.id = plannedTarget.nextItemId
            plannedTarget.nextItemId = plannedTarget.nextItemId + 1
        end
        plannedTarget.items[#plannedTarget.items + 1] = movedItem
    end

    local weightValid, weightError = validatePlannedWeight({ [plannedSource.id] = plannedSource, [plannedTarget.id] = plannedTarget })
    if not weightValid then return false, weightError end
    sourceInventory.items = plannedSource.items
    sourceInventory.nextItemId = plannedSource.nextItemId
    if sourceInventory ~= targetInventory then
        targetInventory.items = plannedTarget.items
        targetInventory.nextItemId = plannedTarget.nextItemId
    end
    return true
end

-- Fill compatible stacks, then use free grid footprints. Publish only the complete plan.
function inventoryCore.quickMove(sourceInventory, targetInventory, itemId, amount)
    if sourceInventory.id == targetInventory.id then return false, 'Choose another inventory' end
    local sourceItem = inventoryCore.find(sourceInventory, itemId)
    if not sourceItem or not inventoryCore.integer(amount, 1, sourceItem.amount) then return false, 'Invalid transfer amount' end
    local definition = inventoryCore.definition(sourceItem.name)
    local plannedSource = inventoryCore.copy(sourceInventory)
    local plannedTarget = inventoryCore.copy(targetInventory)
    local remaining = amount
    if definition.stack then
        for _, targetItem in ipairs(plannedTarget.items) do
            if targetItem.name == sourceItem.name and inventoryCore.equal(targetItem.metadata, sourceItem.metadata) then
                local transferAmount = math.min(remaining, definition.stackSize - targetItem.amount)
                if transferAmount > 0 then
                    local moved, moveError = inventoryCore.move(plannedSource, plannedTarget, itemId, transferAmount, targetItem.x, targetItem.y, sourceItem.rotated)
                    if not moved then return false, moveError end
                    remaining = remaining - transferAmount
                end
            end
            if remaining == 0 then break end
        end
    end
    while remaining > 0 do
        local placementItem = inventoryCore.copy(sourceItem)
        local column, row = inventoryCore.space(plannedTarget, placementItem)
        if not column then
            placementItem.rotated = not (placementItem.rotated == true)
            column, row = inventoryCore.space(plannedTarget, placementItem)
        end
        if not column then return false, 'Not enough grid space' end
        local transferAmount = math.min(remaining, definition.stackSize)
        local moved, moveError = inventoryCore.move(plannedSource, plannedTarget, itemId, transferAmount, column, row, placementItem.rotated)
        if not moved then return false, moveError end
        remaining = remaining - transferAmount
    end
    sourceInventory.items, sourceInventory.nextItemId = plannedSource.items, plannedSource.nextItemId
    targetInventory.items, targetInventory.nextItemId = plannedTarget.items, plannedTarget.nextItemId
    return true
end

function inventoryCore.resize(inventory, size, shouldRepack)
    if not inventoryCore.size(size) then return false, 'Invalid dimensions' end
    local plannedInventory = inventoryCore.copy(inventory)
    plannedInventory.size = inventoryCore.copy(size)

    if shouldRepack then
        local existingItems = plannedInventory.items
        plannedInventory.items = {}
        table.sort(existingItems, function(firstItem, secondItem)
            local firstDefinition = inventoryCore.definition(firstItem.name)
            local secondDefinition = inventoryCore.definition(secondItem.name)
            return firstDefinition.size.x * firstDefinition.size.y > secondDefinition.size.x * secondDefinition.size.y
        end)
        for _, item in ipairs(existingItems) do
            local column, row = inventoryCore.space(plannedInventory, item)
            if not column then return false, 'Items do not fit; inventory unchanged' end
            item.x = column
            item.y = row
            plannedInventory.items[#plannedInventory.items + 1] = item
        end
    else
        for _, item in ipairs(plannedInventory.items) do
            if not inventoryCore.fits(plannedInventory, item, item.x, item.y, item.id) then
                return false, 'Items outside new bounds; try repack'
            end
        end
    end

    inventory.size = plannedInventory.size
    inventory.items = plannedInventory.items
    return true
end
