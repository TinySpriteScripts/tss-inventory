local maxMetadataBytes = 8192

local inventoryCore = TSSCore
local database = TSSDatabase
local inventories = {}
local missingInventoryIds = {}
local committedInventories = {}
local sessions = {}
local playerInventoryIds = {}
local requestLimits = {}
local inventoryLocks = {}
local usableItems = {}
local operationBusy = false
local dropService = nil
local shopService = nil
local storageService = nil
local extraInventoryService = nil
local weightService = nil
local craftingService = nil
local moneyService = nil

local inventoryTypes = {
    extra = { label = 'Extra inventory', size = { x = 1, y = 1 } },
    player = inventoryCore.copy(Config.PlayerDefaults),
    stash = inventoryCore.copy(Config.DefaultStash),
    trunk = inventoryCore.copy(Config.VehicleDefaults.trunk),
    glovebox = inventoryCore.copy(Config.VehicleDefaults.glovebox),
}

for typeName, definition in pairs(TSSContainers) do inventoryTypes[typeName] = inventoryCore.copy(definition) end

-- Database awaits yield. Serialize reads and writes so staged changes stay private.
local function runOperation(callback, ...)
    if not database.ready then return false, 'Inventory database is not ready' end
    while operationBusy do Wait(0) end
    operationBusy = true
    local results = table.pack(pcall(callback, ...))
    operationBusy = false
    if not results[1] then
        print('[tss-inventory] Operation failed: ' .. tostring(results[2]))
        return false, 'Inventory operation failed; check server console'
    end
    return table.unpack(results, 2, results.n)
end

local function validInventoryId(inventoryId)
    return type(inventoryId) == 'string' and #inventoryId > 0 and #inventoryId <= 160
        and inventoryId:match('^[%w_:%-%.]+$') ~= nil
end

local function cleanMetadata(value)
    if type(value) ~= 'table' then return nil, 'Metadata must be an object' end
    if value.label ~= nil and (type(value.label) ~= 'string' or #value.label > 100 or not value.label:match('%S')) then return nil, 'Label must be nonempty text up to 100 bytes' end
    local function validValue(fieldValue, depth)
        if depth > 8 then return false end
        if type(fieldValue) == 'table' then
            local namedFieldCount = 0
            local arrayElementCount = 0
            local largestArrayIndex = 0
            for fieldName, nestedValue in pairs(fieldValue) do
                if type(fieldName) == 'string' then
                    if #fieldName > 128 then return false end
                    namedFieldCount = namedFieldCount + 1
                elseif depth > 0 and inventoryCore.integer(fieldName, 1, 100000) then
                    arrayElementCount = arrayElementCount + 1
                    largestArrayIndex = math.max(largestArrayIndex, fieldName)
                else return false end
                if not validValue(nestedValue, depth + 1) then return false end
            end
            if arrayElementCount > 0 then
                return namedFieldCount == 0 and largestArrayIndex == arrayElementCount
            end
            return true
        end
        return type(fieldValue) == 'string' or type(fieldValue) == 'boolean'
            or (type(fieldValue) == 'number' and fieldValue == fieldValue and math.abs(fieldValue) < 1e15)
    end
    if not validValue(value, 0) then return nil, 'Metadata must contain finite JSON-compatible values (maximum depth 8)' end
    local encoded, jsonValue = pcall(json.encode, value)
    if not encoded or #jsonValue > maxMetadataBytes then return nil, 'Metadata too large' end
    return inventoryCore.copy(value)
end

local function cleanCoordinates(coordinates)
    if coordinates == nil or coordinates == false then return nil end
    local coordinateType = type(coordinates)
    if coordinateType ~= 'table' and coordinateType ~= 'vector3' and coordinateType ~= 'vector4' then return nil, 'Invalid coordinates' end
    local result = {}
    for _, axis in ipairs({ 'x', 'y', 'z' }) do
        local value = coordinates[axis]
        if type(value) ~= 'number' or value ~= value or math.abs(value) > 100000 then return nil, 'Invalid coordinates' end
        result[axis] = value
    end
    if coordinates.w ~= nil then
        if type(coordinates.w) ~= 'number' or coordinates.w ~= coordinates.w then return nil, 'Invalid heading' end
        result.w = coordinates.w
    end
    return result
end

local function notifyPlayer(playerSource, message, notificationOnly)
    if playerSource ~= 0 and (message == 'Player character is not loaded'
        or message == 'Owner character is not loaded' or message == 'Inventory database is not ready') then return end
    if playerSource == 0 then print('[tss-inventory] ' .. tostring(message))
    else TriggerClientEvent('tss-inventory:notice', playerSource, tostring(message), notificationOnly == true) end
end

local function loadInventory(inventoryId)
    if not validInventoryId(inventoryId) then return nil, 'Invalid inventory ID' end
    if inventories[inventoryId] then return inventories[inventoryId] end
    if inventoryId:sub(1, 5) == 'drop:' or missingInventoryIds[inventoryId] then return nil end
    local inventory = database.Load(inventoryId)
    if not inventory then missingInventoryIds[inventoryId] = true; return nil end
    if not inventoryCore.size(inventory.size) or not cleanMetadata(inventory.metadata) then error('Invalid saved inventory: ' .. inventoryId) end
    if inventory.type == 'player' and inventory.id ~= 'player_' .. tostring(inventory.owner) then error('Invalid saved player ownership') end
    local placementCheck = inventoryCore.copy(inventory)
    placementCheck.items = {}
    local itemIds = {}
    local highestItemId = 0
    for _, item in ipairs(inventory.items) do
        local definition = inventoryCore.definition(item.name)
        if not definition or not inventoryCore.integer(item.id, 1, 1e12) or itemIds[item.id]
            or not inventoryCore.integer(item.amount, 1, definition.stackSize)
            or (item.rotated ~= nil and type(item.rotated) ~= 'boolean')
            or not cleanMetadata(item.metadata) or not inventoryCore.fits(placementCheck, item, item.x, item.y) then
            error('Saved items do not match item definitions: ' .. inventoryId)
        end
        itemIds[item.id] = true
        highestItemId = math.max(highestItemId, item.id)
        placementCheck.items[#placementCheck.items + 1] = item
    end
    inventory.nextItemId = math.max(inventory.nextItemId, highestItemId + 1)
    inventory.settings = inventory.settings or {}
    inventories[inventoryId] = inventory
    committedInventories[inventoryId] = inventoryCore.copy(inventory)
    return inventory
end

local notificationPositions = {
    ['top-left'] = true, ['top-center'] = true, ['top-right'] = true,
    ['middle-left'] = true, ['middle-right'] = true,
    ['bottom-left'] = true, ['bottom-center'] = true, ['bottom-right'] = true,
}

local function getPlayerPreferences(inventory)
    local preferences = inventory and inventory.settings and inventory.settings.preferences or {}
    return {
        notificationPosition = notificationPositions[preferences.notificationPosition] and preferences.notificationPosition or 'middle-right',
        windowLayoutVersion = tonumber(preferences.windowLayoutVersion) or 0,
    }
end

local function snapshot(inventory, playerSource)
    local result = inventoryCore.inventoryView(inventory)
    result.owner = nil
    result.weight = inventoryCore.weight(inventory)
    result.dynamicContainerWeight = Config.DynamicContainerWeight == true
    result.isOwn = playerSource and inventory.id == database.PlayerInventoryId(playerSource) or false
    local citizenId = playerSource and database.CitizenId(playerSource)
    result.isPlayerExtra = inventory.type == 'extra' and inventory.owner == citizenId
    if database.IsPersistent(inventory) then
        result.layoutSettings = citizenId and inventory.settings and inventory.settings[citizenId] or false
    end
    local ownInventory = playerSource and inventories[database.PlayerInventoryId(playerSource)]
    local preferences = getPlayerPreferences(ownInventory)
    if result.layoutSettings and (result.layoutSettings.layoutVersion or 0) ~= preferences.windowLayoutVersion then
        result.layoutSettings = false
    end
    if result.isOwn then
        result.craftingRecipes = craftingService and craftingService.Recipes() or {}
        result.playerSettings = preferences
        result.itemKeybinds = inventoryCore.copy(inventory.settings.itemKeybinds or {})
    end
    result.settings = nil
    for _, item in ipairs(result.items) do item.definition = inventoryCore.itemDefinition(item) end
    return result
end

local function sendInventories(playerSource)
    local inventorySession = sessions[playerSource]
    if not inventorySession then return end
    local snapshots = {}
    for inventoryId in pairs(inventorySession) do
        local inventory = inventories[inventoryId]
        if inventory then snapshots[#snapshots + 1] = snapshot(inventory, playerSource) end
    end
    table.sort(snapshots, function(firstInventory, secondInventory)
        if firstInventory.isOwn ~= secondInventory.isOwn then return firstInventory.isOwn end
        return firstInventory.id < secondInventory.id
    end)
    TriggerClientEvent('tss-inventory:sync', playerSource, snapshots, Config.VisibleItemMetadata, Config.CellSize)
end

local function restoreInventory(inventoryId)
    local previous = committedInventories[inventoryId]
    local liveInventory = inventories[inventoryId]
    if previous and liveInventory then
        for fieldName in pairs(liveInventory) do liveInventory[fieldName] = nil end
        for fieldName, fieldValue in pairs(inventoryCore.copy(previous)) do liveInventory[fieldName] = fieldValue end
    else inventories[inventoryId] = previous and inventoryCore.copy(previous) or nil end
    if dropService then dropService.RestoreInventory(inventoryId, inventories[inventoryId]) end
    if shopService then shopService.RestoreInventory(inventoryId, inventories[inventoryId]) end
end

local function commit(...)
    local changedInventories = {}
    local processedIds = {}
    for _, inventory in ipairs({ ... }) do
        if not processedIds[inventory.id] and not inventoryCore.equal(inventory, committedInventories[inventory.id]) then
            processedIds[inventory.id] = true
            inventory.revision = inventory.revision + 1
            changedInventories[#changedInventories + 1] = inventory
        end
    end
    if #changedInventories == 0 then return true end
    local cashReceipts, cashError = {}
    if moneyService then cashReceipts, cashError = moneyService.Prepare(changedInventories, committedInventories) end
    if not cashReceipts then
        for _, inventory in ipairs(changedInventories) do restoreInventory(inventory.id) end
        error(cashError or 'Cash transaction failed')
    end
    if weightService and Config.DynamicContainerWeight then
        local overrides = {}
        for _, inventory in ipairs(changedInventories) do overrides[inventory.id] = inventory end
        local validated, valid, validationError = pcall(weightService.Validate, overrides)
        if not validated or not valid then
            for _, inventory in ipairs(changedInventories) do restoreInventory(inventory.id) end
            if moneyService then moneyService.Rollback(cashReceipts) end
            error(validationError or (not validated and valid) or 'Weight limit exceeded')
        end
    end
    local callSucceeded, saved, saveError = pcall(database.Save, changedInventories)
    if not callSucceeded or not saved then
        for _, inventory in ipairs(changedInventories) do restoreInventory(inventory.id) end
        if moneyService then moneyService.Rollback(cashReceipts) end
        error(saveError or (not callSucceeded and saved) or 'Database transaction failed')
    end
    for _, inventory in ipairs(changedInventories) do committedInventories[inventory.id] = inventoryCore.copy(inventory) end
    if dropService then dropService.AfterCommit(changedInventories) end
    if storageService then storageService.RevokeInvalid() end
    for playerSource, inventoryId in pairs(playerInventoryIds) do
        if Config.DynamicContainerWeight and inventories[inventoryId] then
            TriggerClientEvent('tss-inventory:ownSnapshot', playerSource, snapshot(inventories[inventoryId], playerSource))
        end
        for _, inventory in ipairs(changedInventories) do
            if not Config.DynamicContainerWeight and inventory.id == inventoryId then TriggerClientEvent('tss-inventory:ownSnapshot', playerSource, snapshot(inventory, playerSource)) end
        end
    end
    for playerSource, inventorySession in pairs(sessions) do
        if Config.DynamicContainerWeight then sendInventories(playerSource) else
        for _, inventory in ipairs(changedInventories) do if inventorySession[inventory.id] then sendInventories(playerSource); break end end
        end
    end
    return true
end

local function createInventory(inventoryId, typeName, options, linkedInventory)
    options = options or {}
    if not validInventoryId(inventoryId) or not inventoryTypes[typeName] then return false, 'Invalid inventory ID or type' end
    if inventoryId:sub(1, 5) == 'drop:' or typeName == 'drop' then return false, 'World drop IDs are reserved' end
    if typeName ~= 'player' and inventoryId:sub(1, 7) == 'player_' then return false, 'Player inventory IDs are reserved' end
    if loadInventory(inventoryId) then return false, 'Inventory already exists' end
    local definition = inventoryCore.copy(inventoryTypes[typeName])
    for fieldName, fieldValue in pairs(options) do definition[fieldName] = inventoryCore.copy(fieldValue) end
    local owner = definition.owner
    if definition.playerSource then
        owner = database.CitizenId(tonumber(definition.playerSource))
        if not owner then return false, 'Owner character is not loaded' end
    end
    if owner ~= nil and (type(owner) ~= 'string' or #owner == 0 or #owner > 64) then return false, 'Invalid owner citizen ID' end
    if typeName == 'extra' and (not owner or inventoryId:sub(1, #('extra_' .. owner .. ':')) ~= 'extra_' .. owner .. ':') then return false, 'Extra inventory must match its character owner' end
    if typeName == 'player' and (not owner or inventoryId ~= 'player_' .. owner) then return false, 'Player inventory must match its owner citizen ID' end
    if not inventoryCore.size(definition.size) then return false, 'Invalid inventory size' end
    if definition.maxWeight ~= nil and (type(definition.maxWeight) ~= 'number' or definition.maxWeight ~= definition.maxWeight or definition.maxWeight < 0) then return false, 'Invalid weight limit' end
    local metadata, metadataError = cleanMetadata(definition.metadata or {})
    if not metadata then return false, metadataError end
    local coordinates, coordinateError = cleanCoordinates(definition.coords)
    if coordinateError then return false, coordinateError end
    local inventory = {
        id = inventoryId, type = typeName, owner = owner, label = definition.label or typeName,
        size = definition.size, items = {}, metadata = metadata, settings = {}, coords = coordinates,
        whitelist = definition.whitelist or {}, blacklist = definition.blacklist or {},
        maxWeight = definition.maxWeight, nextItemId = 1, revision = 0,
    }
    if type(inventory.label) ~= 'string' or #inventory.label > 100 then return false, 'Invalid inventory label' end
    inventories[inventoryId] = inventory
    if linkedInventory then commit(inventory, linkedInventory) else commit(inventory) end
    return true, inventoryCore.inventoryView(inventory)
end

local function ensurePlayerInventory(playerSource)
    local citizenId = database.CitizenId(playerSource)
    if not citizenId then return nil, 'Player character is not loaded' end
    local inventoryId = 'player_' .. citizenId
    if playerInventoryIds[playerSource] and playerInventoryIds[playerSource] ~= inventoryId then
        sessions[playerSource] = nil
        TriggerClientEvent('tss-inventory:close', playerSource)
    end
    local inventory = loadInventory(inventoryId)
    if not inventory then
        local created, creationError = createInventory(inventoryId, 'player', { owner = citizenId, label = database.PlayerLabel(playerSource) })
        if not created then return nil, creationError end
        inventory = inventories[inventoryId]
    end
    if database.CitizenId(playerSource) ~= citizenId then return nil, 'Player character changed while loading' end
    playerInventoryIds[playerSource] = inventoryId
    if moneyService then moneyService.Reconcile(playerSource, inventory) end
    return inventory
end

local function openInventory(playerSource, inventoryId)
    local ownInventory, playerError = ensurePlayerInventory(playerSource)
    if not ownInventory then return false, playerError end
    local inventory = loadInventory(inventoryId or ownInventory.id)
    if not inventory then return false, 'Inventory not found' end
    if inventory.type == 'drop' and not dropService.IsNearby(playerSource, inventory.id) then return false, 'Move closer to the world drop' end
    if storageService and not storageService.CanAccess(playerSource, inventory.id) then return false, 'Storage access denied' end
    sessions[playerSource] = sessions[playerSource] or {}
    sessions[playerSource][ownInventory.id] = true
    sessions[playerSource][inventory.id] = true
    if extraInventoryService then
        local granted, grantError = extraInventoryService.Grant(playerSource)
        if not granted then return false, grantError end
    end
    dropService.RefreshSession(playerSource, false)
    sendInventories(playerSource)
    return true
end

local function mutateInventory(inventoryId, callback, ...)
    local inventory = loadInventory(inventoryId)
    if not inventory then return false, 'Inventory not found' end
    if inventory.type == 'shop' or inventoryLocks[inventoryId] then return false, 'Inventory is read-only or busy' end
    local changed, changeError = callback(inventory, ...)
    if changed and weightService and Config.DynamicContainerWeight then
        local valid, weightError = weightService.Validate({ [inventory.id] = inventory })
        if not valid then restoreInventory(inventory.id); return false, weightError end
    end
    if changed then commit(inventory) end
    return changed, changeError
end

local function registerExport(exportName, callback)
    exports(exportName, function(...) return runOperation(callback, ...) end)
end

local function getInventoryCopy(inventoryId)
    local inventory = loadInventory(inventoryId)
    return inventory and inventoryCore.inventoryView(inventory) or nil
end

local function resolveInventoryIdentifier(identifier)
    if type(identifier) ~= 'number' then return identifier end
    local inventory, playerError = ensurePlayerInventory(identifier)
    return inventory and inventory.id or nil, playerError
end

local function legacyInventoryOptions(data)
    if type(data) ~= 'table' then return nil, 'Invalid inventory data' end
    if data.owner or data.groups then return nil, 'Authorize owner/group restrictions in the calling server script' end
    local size = data.size
    if not size then
        local slots = data.slots or 48
        if not inventoryCore.integer(slots, 1, Config.MaxCells) then return nil, 'Invalid slot count' end
        local columns = math.min(8, slots)
        size = { x = columns, y = math.ceil(slots / columns) }
    end
    return { label = data.label or 'Stash', size = size, maxWeight = data.maxweight or data.maxWeight, metadata = data.metadata or {} }
end

registerExport('GetInventory', getInventoryCopy)
registerExport('GetPlayerInventory', function(playerSource)
    local inventory, playerError = ensurePlayerInventory(tonumber(playerSource))
    return inventory and inventoryCore.inventoryView(inventory) or nil, playerError
end)

registerExport('GetItemDefinition', inventoryCore.definition)
registerExport('GetItemDefinitions', function()
    local definitions = {}
    for itemName in pairs(TSSItems) do definitions[itemName] = inventoryCore.definition(itemName) end
    return definitions
end)

registerExport('GetInventoryWeight', function(inventoryId)
    local inventory = loadInventory(inventoryId)
    return inventory and inventoryCore.weight(inventory)
end)

registerExport('CreateInventory', function(inventoryId, typeName, options)
    if type(typeName) == 'table' then
        local translated, translationError = legacyInventoryOptions(typeName)
        if not translated then return false, translationError end
        local existing = loadInventory(inventoryId)
        if existing then return true, inventoryCore.inventoryView(existing) end
        return createInventory(inventoryId, 'stash', translated)
    end
    return createInventory(inventoryId, typeName, options)
end)
registerExport('CreateContainer', function(typeName, options)
    options = options or {}
    if typeName == 'player' or typeName == 'drop' or typeName == 'shop' or typeName == 'extra' then return false, 'Use the dedicated creation API for this type' end
    local inventoryId = options.inventoryId or ('%s_%x%x'):format(typeName, os.time(), math.random(1, 0x7fffffff))
    return createInventory(inventoryId, typeName, options)
end)

registerExport('GetContainer', function(inventoryId)
    local inventory = loadInventory(inventoryId)
    if not inventory or inventory.type == 'player' or inventory.type == 'drop' then return nil end
    return inventoryCore.inventoryView(inventory)
end)

registerExport('GetContainersByOwner', function(citizenId)
    local results = {}
    for _, inventory in ipairs(database.ContainersForOwner(citizenId)) do results[#results + 1] = inventoryCore.inventoryView(inventory) end
    return results
end)

registerExport('DeleteContainer', function(inventoryId)
    local inventory = loadInventory(inventoryId)
    if not inventory or inventory.type == 'player' or inventory.type == 'drop' or inventory.type == 'shop' or inventory.type == 'extra' then return false, 'Invalid container; use RemoveExtraInventory for extra slots' end
    if not database.Delete(inventory) then return false, 'Database deletion failed' end
    inventories[inventoryId] = nil
    committedInventories[inventoryId] = nil
    for playerSource, inventorySession in pairs(sessions) do
        if inventorySession[inventoryId] then inventorySession[inventoryId] = nil; sendInventories(playerSource) end
    end
    return true
end)

registerExport('SetInventoryOwner', function(inventoryId, citizenId)
    if citizenId ~= nil and (type(citizenId) ~= 'string' or #citizenId == 0 or #citizenId > 64) then return false, 'Invalid citizen ID' end
    return mutateInventory(inventoryId, function(inventory)
        if inventory.type == 'player' or inventory.type == 'drop' or inventory.type == 'extra' then return false, 'This inventory owner cannot change' end
        inventory.owner = citizenId
        return true
    end)
end)

registerExport('SetInventoryCoords', function(inventoryId, coordinates)
    local cleaned, coordinateError = cleanCoordinates(coordinates)
    if coordinateError then return false, coordinateError end
    return mutateInventory(inventoryId, function(inventory)
        if inventory.type == 'player' or inventory.type == 'drop' then return false, 'Use the appropriate world API for this inventory' end
        inventory.coords = cleaned
        return true
    end)
end)

registerExport('OpenInventory', function(playerSource, inventoryId, data)
    if inventoryId and data and not loadInventory(inventoryId) then
        local translated, translationError = legacyInventoryOptions(data)
        if not translated then return false, translationError end
        local created, creationError = createInventory(inventoryId, 'stash', translated)
        if not created then return false, creationError end
    end
    return openInventory(tonumber(playerSource), inventoryId)
end)

registerExport('CloseInventory', function(playerSource, inventoryId)
    playerSource = tonumber(playerSource)
    if inventoryId and sessions[playerSource] then
        sessions[playerSource][inventoryId] = nil
        sendInventories(playerSource)
    else
        sessions[playerSource] = nil
        TriggerClientEvent('tss-inventory:close', playerSource)
    end
    return true
end)

local function sendItemBox(playerSource, itemName, action, amount)
    playerSource = tonumber(playerSource)
    amount = amount or 1
    local definition = inventoryCore.definition(itemName)
    if not playerSource or not GetPlayerName(playerSource) or not definition
        or (action ~= 'added' and action ~= 'removed') or not inventoryCore.integer(amount, 1, 100000) then
        return false, 'Invalid item notification'
    end
    TriggerClientEvent('tss-inventory:itemBox', playerSource, definition, action, amount)
    return true
end

-- Independent of database readiness: this only displays a notification.
exports('ItemBox', sendItemBox)

local function notifyItemChange(inventoryId, itemName, action, amount, notification)
    if type(notification) == 'number' then
        sendItemBox(notification, itemName, action, amount)
    elseif notification == true then
        local inventory = loadInventory(inventoryId)
        for playerSource, ownInventoryId in pairs(playerInventoryIds) do
            if (ownInventoryId == inventoryId or (inventory and inventory.type == 'extra' and ownInventoryId == 'player_' .. tostring(inventory.owner)))
                and database.PlayerInventoryId(playerSource) == ownInventoryId then
                sendItemBox(playerSource, itemName, action, amount)
            end
        end
    end
end

registerExport('AddItem', function(identifier, itemName, amount, metadata, notification, reason)
    local qbStyle = type(identifier) == 'number' or type(metadata) == 'boolean' or type(metadata) == 'number'
        or (metadata == nil and type(notification) == 'table') or reason ~= nil
    local preferredSlot
    if qbStyle then
        preferredSlot, metadata, notification = metadata, notification or nil, nil
        if preferredSlot ~= nil and preferredSlot ~= false and not inventoryCore.integer(preferredSlot, 1, 1e12) then return false, 'Invalid preferred slot' end
    end
    local inventoryId, playerError = resolveInventoryIdentifier(identifier)
    if not inventoryId then return false, playerError end
    local definition = inventoryCore.definition(itemName)
    if not definition then return false, 'Unknown item' end
    local cleaned, metadataError = cleanMetadata(metadata or definition.metadata)
    if not cleaned then return false, metadataError end
    local added, addError
    if preferredSlot and preferredSlot ~= false then
        added, addError = mutateInventory(inventoryId, function(inventory)
            local item = inventoryCore.find(inventory, preferredSlot)
            if not item or item.name ~= itemName or not definition.stack or not inventoryCore.equal(item.metadata, cleaned)
                or not inventoryCore.integer(amount, 1, definition.stackSize - item.amount) then return false, 'Preferred stack cannot accept item' end
            if inventory.maxWeight and inventoryCore.weight(inventory) + definition.weight * amount > inventory.maxWeight then return false, 'Weight limit exceeded' end
            item.amount = item.amount + amount
            return true
        end)
    else added, addError = mutateInventory(inventoryId, inventoryCore.add, itemName, amount, cleaned) end
    if added then notifyItemChange(inventoryId, itemName, 'added', amount, notification) end
    return added, addError
end)

registerExport('RemoveItem', function(identifier, itemId, amount, notification, reason)
    local inventoryId, playerError = resolveInventoryIdentifier(identifier)
    if not inventoryId then return false, playerError end
    if type(itemId) == 'string' then
        local itemName, slot = itemId, notification
        if slot ~= nil and slot ~= false and not inventoryCore.integer(slot, 1, 1e12) then return false, 'Invalid item slot' end
        return mutateInventory(inventoryId, function(inventory)
            if not inventoryCore.integer(amount, 1, 100000) then return false, 'Invalid amount' end
            local planned, remaining = inventoryCore.copy(inventory), amount
            for _, item in ipairs(inventory.items) do
                if item.name == itemName and (slot == nil or slot == false or item.id == slot) then
                    local removedAmount = math.min(remaining, item.amount)
                    inventoryCore.remove(planned, item.id, removedAmount)
                    remaining = remaining - removedAmount
                end
                if remaining == 0 then break end
            end
            if remaining > 0 then return false, 'Not enough matching items' end
            inventory.items = planned.items
            return true
        end)
    end
    local inventory = loadInventory(inventoryId)
    local item = inventory and inventoryCore.find(inventory, itemId)
    local itemName = item and item.name
    local removed, removeError = mutateInventory(inventoryId, inventoryCore.remove, itemId, amount)
    if removed then notifyItemChange(inventoryId, itemName, 'removed', amount, notification) end
    return removed, removeError
end)

registerExport('CanCarryItem', function(inventoryId, itemName, amount, metadata)
    local inventory = loadInventory(inventoryId)
    local definition = inventoryCore.definition(itemName)
    if not inventory or not definition then return false, 'Unknown inventory or item' end
    local cleaned, metadataError = cleanMetadata(metadata or definition.metadata)
    if not cleaned then return false, metadataError end
    return inventoryCore.add(inventoryCore.copy(inventory), itemName, amount, cleaned)
end)

registerExport('GetItemCount', function(identifier, itemName, metadata)
    local inventoryId = resolveInventoryIdentifier(identifier)
    local inventory = inventoryId and loadInventory(inventoryId)
    if not inventory then return 0 end
    local names = {}
    if type(itemName) == 'string' then names[itemName] = true
    elseif type(itemName) == 'table' then
        for nameKey, nameValue in pairs(itemName) do
            local name = type(nameKey) == 'number' and nameValue or nameKey
            if type(name) == 'string' then names[name] = true end
        end
    end
    local total = 0
    for _, item in ipairs(inventory.items) do
        if names[item.name] and (metadata == nil or inventoryCore.equal(item.metadata, metadata)) then total = total + item.amount end
    end
    return total
end)

registerExport('RemoveItemsByName', function(inventoryId, itemName, amount, filter, itemId)
    return mutateInventory(inventoryId, function(inventory)
        if not inventoryCore.integer(amount, 1, 100000) then return false, 'Invalid amount' end
        local plannedInventory = inventoryCore.copy(inventory)
        local remaining = amount
        for _, item in ipairs(inventory.items) do
            local matches = true
            if type(filter) == 'string' then matches = item.metadata.type == filter
            elseif type(filter) == 'table' then
                for fieldName, fieldValue in pairs(filter) do if not inventoryCore.equal(item.metadata[fieldName], fieldValue) then matches = false end end
            elseif filter ~= nil then matches = false end
            if item.name == itemName and matches and (itemId == nil or item.id == itemId) then
                local removedAmount = math.min(remaining, item.amount)
                inventoryCore.remove(plannedInventory, item.id, removedAmount)
                remaining = remaining - removedAmount
            end
            if remaining == 0 then break end
        end
        if remaining > 0 then return false, 'Not enough matching items' end
        inventory.items = plannedInventory.items
        return true
    end)
end)

registerExport('AddItemToSlot', function(inventoryId, itemName, amount, metadata, itemId)
    local definition = inventoryCore.definition(itemName)
    if not definition then return false, 'Unknown item' end
    local cleaned, metadataError = cleanMetadata(metadata or definition.metadata)
    if not cleaned then return false, metadataError end
    return mutateInventory(inventoryId, function(inventory)
        local item = inventoryCore.find(inventory, itemId)
        if not item or item.name ~= itemName or not definition.stack or not inventoryCore.equal(item.metadata, cleaned)
            or not inventoryCore.integer(amount, 1, definition.stackSize - item.amount) then return false, 'Preferred stack cannot accept this item' end
        if inventory.maxWeight and inventoryCore.weight(inventory) + definition.weight * amount > inventory.maxWeight then return false, 'Weight limit exceeded' end
        item.amount = item.amount + amount
        return true
    end)
end)

registerExport('MoveItem', function(sourceId, targetId, itemId, amount, column, row, isRotated)
    local sourceInventory = loadInventory(sourceId)
    local targetInventory = loadInventory(targetId)
    if not sourceInventory or not targetInventory then return false, 'Inventory not found' end
    if sourceInventory.type == 'shop' or targetInventory.type == 'shop'
        or inventoryLocks[sourceId] or inventoryLocks[targetId] then return false, 'Inventory is read-only or busy' end
    local sourceItem = inventoryCore.find(sourceInventory, itemId)
    if sourceItem and storageService and not storageService.CanMove(sourceItem, targetId) then return false, 'A container cannot be stored inside itself' end
    local moved, moveError = inventoryCore.move(sourceInventory, targetInventory, itemId, amount, column, row, isRotated)
    if moved then commit(sourceInventory, targetInventory) end
    return moved, moveError
end)

registerExport('ResizeInventory', function(inventoryId, size, shouldRepack) return mutateInventory(inventoryId, inventoryCore.resize, size, shouldRepack == true) end)

local function updateInventoryDetails(inventoryId, callback)
    local inventory = loadInventory(inventoryId)
    if not inventory then return false, 'Inventory not found' end
    if inventoryLocks[inventoryId] then return false, 'Inventory is busy' end
    local updated, updateError = callback(inventory)
    if updated then commit(inventory) end
    return updated, updateError
end

registerExport('SetInventoryMetadata', function(inventoryId, metadata)
    local cleaned, metadataError = cleanMetadata(metadata)
    if not cleaned then return false, metadataError end
    return updateInventoryDetails(inventoryId, function(inventory)
        if inventory.metadata.containerItem then cleaned.containerItem = inventory.metadata.containerItem end
        inventory.metadata = cleaned
        return true
    end)
end)

registerExport('SetItemMetadata', function(inventoryId, itemId, metadata)
    local cleaned, metadataError = cleanMetadata(metadata)
    if not cleaned then return false, metadataError end
    return mutateInventory(inventoryId, function(inventory)
        local item = inventoryCore.find(inventory, itemId)
        if not item then return false, 'Item not found' end
        if item.metadata.containerId then cleaned.containerId = item.metadata.containerId end
        item.metadata = cleaned
        return true
    end)
end)

registerExport('SetItemLabel', function(inventoryId, itemId, label)
    if label ~= nil and label ~= false and (type(label) ~= 'string' or #label > 100 or not label:match('%S')) then return false, 'Invalid label' end
    return updateInventoryDetails(inventoryId, function(inventory)
        local item = inventoryCore.find(inventory, itemId)
        if not item then return false, 'Item not found' end
        local metadata = inventoryCore.copy(item.metadata)
        metadata.label = label or nil
        local cleaned, metadataError = cleanMetadata(metadata)
        if not cleaned then return false, metadataError end
        item.metadata = cleaned
        return true
    end)
end)

registerExport('SetInventoryLabel', function(inventoryId, label)
    if label ~= nil and label ~= false and (type(label) ~= 'string' or #label > 100 or not label:match('%S')) then return false, 'Invalid label' end
    return updateInventoryDetails(inventoryId, function(inventory)
        local metadata = inventoryCore.copy(inventory.metadata)
        metadata.label = label or nil
        local cleaned, metadataError = cleanMetadata(metadata)
        if not cleaned then return false, metadataError end
        inventory.metadata = cleaned
        return true
    end)
end)

registerExport('SetInventoryRules', function(inventoryId, rules)
    if type(rules) ~= 'table' then return false, 'Invalid rules' end
    for _, listName in ipairs({ 'whitelist', 'blacklist' }) do
        if rules[listName] then
            if type(rules[listName]) ~= 'table' then return false, 'Invalid item list' end
            for _, itemName in ipairs(rules[listName]) do if not inventoryCore.definition(itemName) then return false, 'Unknown item in list' end end
        end
    end
    if rules.maxWeight ~= nil and (type(rules.maxWeight) ~= 'number' or rules.maxWeight ~= rules.maxWeight or rules.maxWeight < 0) then return false, 'Invalid weight limit' end
    return mutateInventory(inventoryId, function(inventory)
        local planned = inventoryCore.copy(inventory)
        for _, fieldName in ipairs({ 'whitelist', 'blacklist', 'maxWeight' }) do if rules[fieldName] ~= nil then planned[fieldName] = inventoryCore.copy(rules[fieldName]) end end
        for _, item in ipairs(planned.items) do if not inventoryCore.allowed(planned, item.name) then return false, 'Existing items violate new rules' end end
        if planned.maxWeight and inventoryCore.weight(planned) > planned.maxWeight then return false, 'Existing items exceed weight limit' end
        inventory.whitelist = planned.whitelist
        inventory.blacklist = planned.blacklist
        inventory.maxWeight = planned.maxWeight
        return true
    end)
end)

registerExport('RegisterInventoryType', function(typeName, definition)
    if type(typeName) ~= 'string' or #typeName > 64 or not inventoryCore.size(definition and definition.size) then return false, 'Invalid inventory type' end
    inventoryTypes[typeName] = inventoryCore.copy(definition)
    return true
end)

registerExport('GetInventoryType', function(typeName) return inventoryTypes[typeName] and inventoryCore.copy(inventoryTypes[typeName]) end)

exports('RegisterUsableItem', function(itemName, callback, ownerResource)
    local callable = type(callback) == 'function' or (type(callback) == 'table' and rawget(callback, '__cfx_functionReference') ~= nil)
    if not inventoryCore.definition(itemName) or not callable then return false, 'Invalid item or callback' end
    usableItems[itemName] = { handler = callback, resource = ownerResource or GetInvokingResource() }
    return true
end)

registerExport('RegisterShop', function(shopId, definition) return shopService.Register(shopId, definition) end)

registerExport('CreateShop', function(data)
    if type(data) ~= 'table' or type(data.name) ~= 'string' or type(data.items) ~= 'table' then return false, 'Invalid shop data' end
    local stock = {}
    for _, item in ipairs(data.items) do
        if type(item.name) ~= 'string' or stock[item.name] then return false, 'Invalid or duplicate shop product' end
        stock[item.name] = { price = item.price, amount = item.amount ~= nil and item.amount or item.count, metadata = item.info or item.metadata }
    end
    return shopService.Register(data.name, { label = data.label, coords = data.coords, distance = data.distance,
        account = data.account, groups = data.groups, size = data.size or { x = 8 }, stock = stock })
end)

registerExport('OpenShop', function(playerSource, shopId) return shopService.Open(tonumber(playerSource), shopId) end)

registerExport('DropItem', function(playerSource, itemId, quantity, isRotated)
    playerSource = tonumber(playerSource)
    local inventory, playerError = ensurePlayerInventory(playerSource)
    if not inventory then return false, playerError end
    return dropService.Drop(playerSource, inventory, itemId, quantity, isRotated)
end)

registerExport('RegisterExtraInventory', function(slotName, definition) return extraInventoryService.Register(slotName, definition) end)

registerExport('GetExtraInventoryDefinitions', function(playerSource) return extraInventoryService.Definitions(playerSource and tonumber(playerSource)) end)

registerExport('CreateExtraInventory', function(playerSource, slotName, definition) return extraInventoryService.Create(tonumber(playerSource), slotName, definition) end)

registerExport('UpdateExtraInventory', function(playerSource, slotName, changes, shouldRepack) return extraInventoryService.Update(tonumber(playerSource), slotName, changes, shouldRepack) end)

registerExport('ResizeExtraInventory', function(playerSource, slotName, size, shouldRepack) return extraInventoryService.Update(tonumber(playerSource), slotName, { size = size }, shouldRepack) end)

registerExport('RemoveExtraInventory', function(playerSource, slotName) return extraInventoryService.Remove(tonumber(playerSource), slotName) end)

registerExport('GetExtraInventory', function(playerSource, slotName)
    local inventory, inventoryError = extraInventoryService.Get(tonumber(playerSource), slotName)
    return inventory and inventoryCore.inventoryView(inventory) or nil, inventoryError
end)

registerExport('GetExtraInventories', function(playerSource)
    local inventories, inventoryError = extraInventoryService.Roots(tonumber(playerSource), true)
    if not inventories then return nil, inventoryError end
    local results = {}
    for _, inventory in ipairs(inventories) do results[#results + 1] = inventoryCore.inventoryView(inventory) end
    return results
end)

registerExport('OpenExtraInventory', function(playerSource, slotName)
    playerSource = tonumber(playerSource)
    local inventory, inventoryError = extraInventoryService.Get(playerSource, slotName)
    if not inventory then return false, inventoryError end
    return openInventory(playerSource, inventory.id)
end)

registerExport('OpenVehicleInventory', function(playerSource, networkId, compartment) return storageService.OpenVehicle(tonumber(playerSource), networkId, compartment) end)

registerExport('OpenItemContainer', function(playerSource, inventoryId, itemId)
    local inventory = loadInventory(inventoryId)
    if not inventory then return false, 'Inventory not found' end
    return storageService.OpenItem(tonumber(playerSource), inventory, itemId)
end)

registerExport('CreateDrop', function(options) return dropService.Create(options) end)

registerExport('GetDrops', function() return dropService.List() end)

registerExport('RemoveDrop', function(inventoryId) return dropService.Remove(inventoryId) end)

local validDockSlots = { ['left-top'] = true, ['left-bottom'] = true, ['right-top'] = true, ['right-bottom'] = true,
    ['top-left'] = true, ['top-right'] = true, ['bottom-left'] = true, ['bottom-right'] = true }

local function cleanLayout(layout)
    if type(layout) ~= 'table' or not inventoryCore.integer(layout.x, 0, 16384)
        or not inventoryCore.integer(layout.y, 0, 16384)
        or (layout.dock ~= nil and layout.dock ~= false and not validDockSlots[layout.dock])
        or type(layout.minimised) ~= 'boolean' then return nil end
    return { x = layout.x, y = layout.y, dock = layout.dock or false, minimised = layout.minimised,
        active = layout.active == true }
end

registerExport('GetInventorySettings', function(inventoryId, citizenId)
    if type(citizenId) ~= 'string' then return nil end
    local inventory = loadInventory(inventoryId)
    local layout = inventory and (inventory.settings or {})[citizenId]
    local ownInventory = loadInventory('player_' .. citizenId)
    if not layout or (layout.layoutVersion or 0) ~= getPlayerPreferences(ownInventory).windowLayoutVersion then return nil end
    return inventoryCore.copy(layout)
end)

registerExport('SetInventorySettings', function(inventoryId, citizenId, settings)
    local inventory = loadInventory(inventoryId)
    local layout = cleanLayout(settings)
    if not inventory or not database.IsPersistent(inventory) or not layout
        or type(citizenId) ~= 'string' or #citizenId == 0 or #citizenId > 64 then return false, 'Invalid inventory settings' end
    inventory.settings = inventory.settings or {}
    local ownInventory = loadInventory('player_' .. citizenId)
    layout.layoutVersion = getPlayerPreferences(ownInventory).windowLayoutVersion
    inventory.settings[citizenId] = layout
    commit(inventory)
    return true
end)

local function saveViewerLayouts(playerSource, layouts)
    if type(layouts) ~= 'table' then return false, 'Invalid layout settings' end
    local citizenId = database.CitizenId(playerSource)
    if not citizenId or not sessions[playerSource] then return false, 'Inventory access denied' end
    local changes = {}
    for inventoryId, layout in pairs(layouts) do
        if #changes >= 64 or type(layout) ~= 'table' or not sessions[playerSource][inventoryId] then return false, 'Layout access denied' end
        local inventory = loadInventory(inventoryId)
        if not inventory or not database.IsPersistent(inventory) then return false, 'Temporary inventory layouts are not saved' end
        if not storageService.CanAccess(playerSource, inventoryId) then return false, 'Storage access denied' end
        local cleanedLayout = cleanLayout(layout)
        if not cleanedLayout then return false, 'Invalid window layout' end
        changes[#changes + 1] = { inventory = inventory, layout = cleanedLayout }
    end
    local changedInventories = {}
    for _, change in ipairs(changes) do
        change.inventory.settings = change.inventory.settings or {}
        change.layout.layoutVersion = getPlayerPreferences(inventories[database.PlayerInventoryId(playerSource)]).windowLayoutVersion
        change.inventory.settings[citizenId] = change.layout
        changedInventories[#changedInventories + 1] = change.inventory
    end
    commit(table.unpack(changedInventories))
    return true
end

local function isRateLimited(playerSource)
    local now = GetGameTimer()
    local limit = requestLimits[playerSource]
    if not limit or now - limit.started > 1000 then
        limit = { started = now, count = 0 }
        requestLimits[playerSource] = limit
    end
    limit.count = limit.count + 1
    return limit.count > 25
end

local function usableItemCallback(playerSource, inventoryId, itemSnapshot, definition, registration)
    return function()
        -- Release inventory focus before the item's handler opens its own UI.
        if definition.shouldClose == true then
            sessions[playerSource] = nil
            TriggerClientEvent('tss-inventory:close', playerSource, true)
        end
        return registration.handler(playerSource, itemSnapshot, inventoryId)
    end
end

local function handleAction(playerSource, request)
    if type(request) ~= 'table' then return false, 'Invalid request' end
    if request.kind == 'cancelCraft' then return craftingService.Cancel(playerSource) end
    if craftingService.Active(playerSource) then return false, 'Finish or cancel crafting first' end
    if playerInventoryIds[playerSource] ~= database.PlayerInventoryId(playerSource) then return false, 'Character session changed' end
    if request.kind == 'preferences' or request.kind == 'resetWindows' then
        local ownInventory, playerError = ensurePlayerInventory(playerSource)
        if not ownInventory then return false, playerError end
        local preferences = getPlayerPreferences(ownInventory)
        if request.kind == 'preferences' then
            if type(request.settings) ~= 'table' or not notificationPositions[request.settings.notificationPosition] then
                return false, 'Invalid notification position'
            end
            preferences.notificationPosition = request.settings.notificationPosition
        else
            preferences.windowLayoutVersion = preferences.windowLayoutVersion + 1
        end
        ownInventory.settings.preferences = preferences
        commit(ownInventory)
        if request.kind == 'resetWindows' then TriggerClientEvent('tss-inventory:resetLayouts', playerSource) end
        return true
    end
    if request.kind == 'layout' then return saveViewerLayouts(playerSource, request.layouts) end
    local inventorySession = sessions[playerSource]
    if not inventorySession or not inventorySession[request.from] then return false, 'Inventory access denied' end
    local sourceInventory = loadInventory(request.from)
    if not sourceInventory then return false, 'Inventory not found' end
    if not storageService.CanAccess(playerSource, sourceInventory.id) then return false, 'Storage is no longer accessible' end
    if sourceInventory.type == 'drop' and not dropService.IsNearby(playerSource, sourceInventory.id) then return false, 'Move closer to the drop' end
    if sourceInventory.revision ~= request.revision then sendInventories(playerSource); return false, 'Inventory changed; try again' end
    if inventoryLocks[sourceInventory.id] then return false, 'Inventory is busy' end
    if request.kind == 'craft' then return craftingService.Start(playerSource, sourceInventory, request) end
    if request.kind == 'buy' then
        if sourceInventory.type ~= 'shop' or not inventorySession[request.to] then return false, 'Shop access denied' end
        return shopService.Buy(playerSource, request)
    end
    if sourceInventory.type == 'shop' then return false, 'Shop catalogue is read-only' end
    if request.kind == 'drop' then return dropService.Drop(playerSource, sourceInventory, request.itemId, request.amount, request.rotated) end
    if request.kind == 'bindKey' or request.kind == 'unbindKey' then
        local item = inventoryCore.find(sourceInventory, request.itemId)
        local definition = item and inventoryCore.definition(item.name)
        if not definition or (request.kind == 'bindKey' and not definition.useable) then return false, 'Item cannot be used' end
        if request.kind == 'bindKey' and (not inventoryCore.integer(request.keyCode, 8, 254) or request.keyCode == 27
            or type(request.keyLabel) ~= 'string' or #request.keyLabel == 0 or #request.keyLabel > 32) then return false, 'Invalid key' end
        local ownInventory, playerError = ensurePlayerInventory(playerSource)
        if not ownInventory then return false, playerError end
        ownInventory.settings.itemKeybinds = ownInventory.settings.itemKeybinds or {}
        for keyCode, binding in pairs(ownInventory.settings.itemKeybinds) do
            if binding.itemName == item.name then ownInventory.settings.itemKeybinds[keyCode] = nil end
        end
        if request.kind == 'bindKey' then
            ownInventory.settings.itemKeybinds[tostring(request.keyCode)] = { itemName = item.name, keyLabel = request.keyLabel }
        end
        commit(ownInventory)
        return true
    end
    if request.kind == 'use' then
        local item = inventoryCore.find(sourceInventory, request.itemId)
        local definition = item and inventoryCore.definition(item.name)
        if definition and definition.container then
            local opened, openError = storageService.OpenItem(playerSource, sourceInventory, request.itemId)
            if opened and definition.shouldClose == true then
                sessions[playerSource] = nil
                TriggerClientEvent('tss-inventory:close', playerSource, true)
            end
            return opened, openError
        end
        if sourceInventory.id ~= playerInventoryIds[playerSource]
            and not (sourceInventory.type == 'extra' and extraInventoryService.CanAccess(playerSource, sourceInventory.id)) then return false, 'Use items from your own inventory' end
        local registration = item and usableItems[item.name]
        if not definition or not definition.useable or not registration then return false, 'Item cannot be used' end
        local itemSnapshot = inventoryCore.itemView(item)
        return true, nil, usableItemCallback(playerSource, sourceInventory.id, itemSnapshot, definition, registration)
    end
    if (request.kind ~= 'move' and request.kind ~= 'quickMove') or not inventorySession[request.to] then return false, 'Invalid destination' end
    local targetInventory = loadInventory(request.to)
    if not targetInventory or targetInventory.type == 'shop' then return false, 'Invalid destination' end
    if not storageService.CanAccess(playerSource, targetInventory.id) then return false, 'Destination is no longer accessible' end
    local movedItem = inventoryCore.find(sourceInventory, request.itemId)
    if movedItem and not storageService.CanMove(movedItem, targetInventory.id) then return false, 'A container cannot be stored inside itself' end
    if targetInventory.type == 'drop' and not dropService.IsNearby(playerSource, targetInventory.id) then return false, 'Move closer to the drop' end
    if inventoryLocks[targetInventory.id] then return false, 'Inventory is busy' end
    if targetInventory.revision ~= request.targetRevision then sendInventories(playerSource); return false, 'Inventory changed; try again' end
    if request.kind == 'quickMove' then
        local amount = movedItem and (request.half == true and math.floor(movedItem.amount / 2) or movedItem.amount) or 0
        if amount < 1 then return false, 'Stack cannot be split' end
        local moved, moveError = inventoryCore.quickMove(sourceInventory, targetInventory, request.itemId, amount)
        if moved then commit(sourceInventory, targetInventory) end
        return moved, moveError
    end
    local moved, moveError = inventoryCore.move(sourceInventory, targetInventory, request.itemId, request.amount, request.x, request.y, request.rotated)
    if moved then commit(sourceInventory, targetInventory) end
    return moved, moveError
end

RegisterNetEvent('tss-inventory:action', function(requestId, request)
    local playerSource = source
    if not inventoryCore.integer(requestId, 1, 1e12) then return end
    if isRateLimited(playerSource) then TriggerClientEvent('tss-inventory:result', playerSource, requestId, false, 'Too many requests'); return end
    local succeeded, message, deferredCallback = runOperation(handleAction, playerSource, request)
    if succeeded and deferredCallback then
        local callbackSucceeded, callbackError = pcall(deferredCallback)
        if not callbackSucceeded then
            print('[tss-inventory] Usable callback failed: ' .. tostring(callbackError))
            succeeded, message = false, 'Item action failed'
        end
    end
    TriggerClientEvent('tss-inventory:result', playerSource, requestId, succeeded, message)
end)

local function registerPlayerEvent(eventName, callback)
    RegisterNetEvent(eventName, function(...)
        local playerSource = source
        -- Background cache polling must not notify players during startup/failure.
        if eventName == 'tss-inventory:requestOwn' and not database.ready then return end
        if isRateLimited(playerSource) then return end
        local succeeded, message = runOperation(callback, playerSource, ...)
        if eventName ~= 'tss-inventory:requestOwn' and succeeded == false and message then notifyPlayer(playerSource, message) end
    end)
end

local function findCarriedItem(playerSource, selector)
    local ownInventory, playerError = ensurePlayerInventory(playerSource)
    if not ownInventory then return nil, nil, nil, playerError end
    local requestedName, requestedId, requestedInventory
    if type(selector) == 'string' then requestedName = selector
    elseif type(selector) == 'number' then requestedId = selector
    elseif type(selector) == 'table' then
        requestedName, requestedId, requestedInventory = selector.name, selector.id or selector.slot, selector.inventoryId
    else return nil, nil, nil, 'Invalid item selector' end
    if requestedName == nil and requestedId == nil then return nil, nil, nil, 'Invalid item selector' end
    local visited = {}
    local function findCarried(inventory, depth)
        if depth > 8 or visited[inventory.id] then return nil end
        visited[inventory.id] = true
        for _, item in ipairs(inventory.items) do
            if (requestedName == nil or item.name == requestedName) and (requestedId == nil or item.id == requestedId)
                and (requestedInventory == nil or inventory.id == requestedInventory) then return inventory, item end
        end
        for _, item in ipairs(inventory.items) do
            local definition = inventoryCore.definition(item.name)
            local containerId = definition and definition.container and item.metadata.containerId
            local container = type(containerId) == 'string' and loadInventory(containerId)
            if container and container.type == definition.container and container.metadata.containerItem == item.name then
                local foundInventory, foundItem = findCarried(container, depth + 1)
                if foundItem then return foundInventory, foundItem end
            end
        end
    end
    local sourceInventory, item = findCarried(ownInventory, 0)
    if not item then
        for _, extraInventory in ipairs(extraInventoryService.RootsForInventory(ownInventory)) do
            sourceInventory, item = findCarried(extraInventory, 0)
            if item then break end
        end
    end
    return sourceInventory, item, ownInventory
end

local function prepareCarriedUse(playerSource, selector)
    if craftingService.Active(playerSource) then return false, 'Finish or cancel crafting first' end
    local sourceInventory, item, ownInventory, playerError = findCarriedItem(playerSource, selector)
    if not item then return false, playerError or 'Item is not carried' end
    local definition = inventoryCore.definition(item.name)
    if not definition or not definition.useable then return false, 'Item cannot be used' end
    if definition.container then
        local opened, openError = openInventory(playerSource, sourceInventory.id)
        if not opened then return false, openError end
        if database.PlayerInventoryId(playerSource) ~= ownInventory.id then return false, 'Character changed' end
        local containerOpened, containerError = storageService.OpenItem(playerSource, sourceInventory, item.id)
        if containerOpened and definition.shouldClose == true then
            sessions[playerSource] = nil
            TriggerClientEvent('tss-inventory:close', playerSource, true)
        end
        return containerOpened, containerError
    end
    local registration = usableItems[item.name]
    if not registration then return false, 'Item cannot be used' end
    local itemSnapshot = inventoryCore.itemView(item)
    return true, nil, usableItemCallback(playerSource, sourceInventory.id, itemSnapshot, definition, registration)
end

local function useBoundItem(playerSource, keyCode)
    if not inventoryCore.integer(keyCode, 8, 254) or keyCode == 27 then return false, 'Invalid key' end
    local ownInventory, playerError = ensurePlayerInventory(playerSource)
    if not ownInventory then return false, playerError end
    local binding = (ownInventory.settings.itemKeybinds or {})[tostring(keyCode)]
    if not binding then return false end
    return prepareCarriedUse(playerSource, binding.itemName)
end

exports('UseItem', function(playerOrName, selectorOrSource, item)
    local playerSource, selector = playerOrName, selectorOrSource
    if type(playerOrName) == 'string' then
        playerSource, selector = selectorOrSource, item or playerOrName
        if type(selector) == 'table' then
            if selector.name and selector.name ~= playerOrName then return false, 'Item name mismatch' end
            selector = inventoryCore.copy(selector)
            selector.name = playerOrName
        end
    end
    local succeeded, message, callback = runOperation(prepareCarriedUse, tonumber(playerSource), selector)
    if succeeded and callback then
        local called, callbackError = pcall(callback)
        if not called then print('[tss-inventory] Usable callback failed: ' .. tostring(callbackError)); return false, 'Item action failed' end
    end
    return succeeded, message
end)

RegisterNetEvent('tss-inventory:useItemKey', function(keyCode)
    local playerSource = source
    if isRateLimited(playerSource) then return end
    local succeeded, message, deferredCallback = runOperation(useBoundItem, playerSource, keyCode)
    if succeeded and deferredCallback then
        local callbackSucceeded, callbackError = pcall(deferredCallback)
        if not callbackSucceeded then print('[tss-inventory] Bound item callback failed: ' .. tostring(callbackError)) end
    elseif succeeded == false and message then notifyPlayer(playerSource, message) end
end)

registerPlayerEvent('tss-inventory:openSettings', function(playerSource)
    local ownInventory, playerError = ensurePlayerInventory(playerSource)
    if not ownInventory then return false, playerError end
    TriggerClientEvent('tss-inventory:settings', playerSource, getPlayerPreferences(ownInventory))
    return true
end)

registerPlayerEvent('tss-inventory:openVehicle', function(playerSource, networkId, compartment) return storageService.OpenVehicle(playerSource, networkId, compartment) end)

registerPlayerEvent('tss-inventory:openSelf', function(playerSource, nearbyTrunkNetworkId)
    local opened, openError = openInventory(playerSource)
    if opened then
        local gloveboxOpened = storageService.OpenCurrentGlovebox(playerSource)
        if not gloveboxOpened and nearbyTrunkNetworkId then
            storageService.OpenVehicle(playerSource, nearbyTrunkNetworkId, 'trunk')
        end
    end
    return opened, openError
end)
registerPlayerEvent('tss-inventory:requestOwn', function(playerSource)
    local inventory, playerError = ensurePlayerInventory(playerSource)
    if not inventory then return false, playerError end
    TriggerClientEvent('tss-inventory:ownSnapshot', playerSource, snapshot(inventory, playerSource))
    return true
end)
registerPlayerEvent('tss-inventory:openShop', function(playerSource, shopId) return shopService.Open(playerSource, shopId) end)
registerPlayerEvent('tss-inventory:requestWorldDrops', function(playerSource) dropService.SyncPlayer(playerSource); return true end)
registerPlayerEvent('tss-inventory:openWorldDrop', function(playerSource, inventoryId) return dropService.Open(playerSource, inventoryId) end)
registerPlayerEvent('tss-inventory:closeSession', function(playerSource, inventoryId)
    if craftingService.Active(playerSource) then return false, 'Finish or cancel crafting first' end
    if inventoryId and sessions[playerSource] then sessions[playerSource][inventoryId] = nil
    else sessions[playerSource] = nil end
    return true
end)

local commandBridge = exports.tss_bridge:GetModules({ 'Commands' }, Config.TSS).Commands
local adminCommandDefinitions = {
    inventoryhelp = { description = 'Show inventory admin commands.', arguments = {} },
    additem = { description = 'Give an item to a player.', arguments = {
        { name = 'player', type = 'integer', help = 'Online player ID' },
        { name = 'item', help = 'Item name, such as radio' },
        { name = 'amount', type = 'integer', optional = true, help = 'Amount to add; defaults to 1' },
        { name = 'metadata', type = 'rest', optional = true, help = 'Optional JSON object, such as {"rarity":"rare"}; specify amount first' },
    } },
    removeitem = { description = 'Remove an item instance from an inventory.', arguments = {
        { name = 'inventory', help = 'Inventory ID, online player ID, or self' },
        { name = 'item', type = 'integer', help = 'Item instance ID' },
        { name = 'amount', type = 'integer', optional = true, help = 'Amount to remove; defaults to 1' },
    } },
    createinventory = { description = 'Create an inventory.', arguments = {
        { name = 'inventory', help = 'New inventory ID' },
        { name = 'type', optional = true, help = 'Inventory type; defaults to stash' },
    } },
    openinventory = { description = 'Open an inventory for inspection.', arguments = {
        { name = 'inventory', optional = true, help = 'Inventory ID, online player ID, or self' },
    } },
    resizeinventory = { description = 'Change inventory grid dimensions.', arguments = {
        { name = 'inventory', help = 'Inventory ID, online player ID, or self' },
        { name = 'columns', type = 'integer', help = 'Grid width (1–100)' },
        { name = 'rows', type = 'integer', help = 'Grid height (1–100)' },
    } },
    setinventorymetadata = { description = 'Replace inventory metadata.', arguments = {
        { name = 'inventory', help = 'Inventory ID, online player ID, or self' },
        { name = 'metadata', type = 'rest', help = 'JSON object' },
    } },
    setitemmetadata = { description = 'Replace item instance metadata.', arguments = {
        { name = 'inventory', help = 'Inventory ID, online player ID, or self' },
        { name = 'item', type = 'integer', help = 'Item instance ID' },
        { name = 'metadata', type = 'rest', help = 'JSON object' },
    } },
    inspectinventory = { description = 'Print inventory data.', arguments = {
        { name = 'inventory', optional = true, help = 'Inventory ID, online player ID, or self' },
    } },
}

adminCommandDefinitions.additem.permission = { 'command.additem', 'command.giveitem' }
adminCommandDefinitions.giveitem = adminCommandDefinitions.additem

local function adminCommand(commandName, callback)
    local definition = adminCommandDefinitions[commandName]
    local registered, registrationError = commandBridge.Register(commandName, {
        description = definition.description,
        arguments = definition.arguments,
        category = 'Inventory admin',
        permission = definition.permission or ('command.' .. commandName),
        allowConsole = true,
    }, function(playerSource, parsedArguments, rawCommand, arguments)
        local succeeded, message = runOperation(callback, playerSource, arguments, rawCommand)
        if succeeded and message == false then return end
        notifyPlayer(playerSource, message or (succeeded and 'Done' or 'Command failed'), true)
    end)
    if not registered then
        print(('[tss-inventory] Could not register /%s: %s'):format(commandName, tostring(registrationError)))
    end
end

local function commandInventory(playerSource, suppliedId)
    if tonumber(suppliedId) then return database.PlayerInventoryId(tonumber(suppliedId)) end
    if suppliedId and suppliedId ~= 'self' then return suppliedId end
    return database.PlayerInventoryId(playerSource)
end

adminCommand('inventoryhelp', function()
    return true, 'giveitem/additem [player ID] [item] [amount] [JSON metadata]; removeitem [inventory/self] [item ID] [amount]; createinventory [ID] [type]; openinventory [ID]; resizeinventory [ID/self] [columns] [rows]; setinventorymetadata [ID/self] [JSON]; setitemmetadata [ID/self] [item ID] [JSON]; inspectinventory [ID/self]'
end)
local function commandItemFeedback(playerSource, inventory, itemName, itemLabel, amount, action)
    notifyItemChange(inventory.id, itemName, action, amount, true)
    if inventory.id == database.PlayerInventoryId(playerSource) then return true, false end

    local targetName = inventory.label or inventory.id
    for targetSource, inventoryId in pairs(playerInventoryIds) do
        if inventoryId == inventory.id and database.PlayerInventoryId(targetSource) == inventoryId then
            targetName = GetPlayerName(targetSource) or targetName
            break
        end
    end
    if action == 'added' then return true, ('Gave %s %d x %s'):format(targetName, amount, itemLabel) end
    return true, ('Removed %d x %s from %s'):format(amount, itemLabel, targetName)
end

local function giveItemCommand(playerSource, arguments, rawCommand)
    local inventory, playerError = ensurePlayerInventory(tonumber(arguments[1]))
    if not inventory then return false, playerError end
    local itemName = arguments[2]
    local amount = tonumber(arguments[3]) or 1
    local definition = inventoryCore.definition(itemName)
    if not definition then return false, 'Unknown item' end
    local metadata = inventoryCore.copy(definition.metadata)
    local encodedMetadata = rawCommand:match('^%S+%s+%S+%s+%S+%s+%S+%s+(.+)$')
    if encodedMetadata then
        local decoded, decodedMetadata = pcall(json.decode, encodedMetadata)
        if not decoded or type(decodedMetadata) ~= 'table' then return false, 'Metadata must be a valid JSON object' end
        local metadataError
        metadata, metadataError = cleanMetadata(decodedMetadata)
        if not metadata then return false, metadataError end
    end
    local added, addError = mutateInventory(inventory.id, inventoryCore.add, itemName, amount, metadata)
    if not added then return false, addError end
    return commandItemFeedback(playerSource, inventory, itemName, metadata.label or definition.label, amount, 'added')
end

adminCommand('additem', giveItemCommand)
adminCommand('giveitem', giveItemCommand)

adminCommand('removeitem', function(playerSource, arguments)
    local inventoryId = commandInventory(playerSource, arguments[1])
    local inventory = loadInventory(inventoryId)
    local itemId = tonumber(arguments[2])
    local item = inventory and inventoryCore.find(inventory, itemId)
    if not item then return false, 'Item not found' end
    local amount = tonumber(arguments[3]) or 1
    local itemName = item.name
    local itemLabel = inventoryCore.itemDefinition(item).label
    local removed, removeError = mutateInventory(inventoryId, inventoryCore.remove, itemId, amount)
    if not removed then return false, removeError end
    return commandItemFeedback(playerSource, inventory, itemName, itemLabel, amount, 'removed')
end)

adminCommand('createinventory', function(_, arguments) return createInventory(arguments[1], arguments[2] or 'stash') end)
adminCommand('openinventory', function(playerSource, arguments) return openInventory(playerSource, commandInventory(playerSource, arguments[1])) end)
adminCommand('resizeinventory', function(playerSource, arguments)
    return mutateInventory(commandInventory(playerSource, arguments[1]), inventoryCore.resize, { x = tonumber(arguments[2]), y = tonumber(arguments[3]) })
end)
adminCommand('setinventorymetadata', function(playerSource, arguments, rawCommand)
    local encodedMetadata = rawCommand:match('^%S+%s+%S+%s+(.+)$')
    local decoded, value = pcall(json.decode, encodedMetadata or '')
    local metadata, metadataError = cleanMetadata(decoded and value or nil)
    if not metadata then return false, metadataError end
    return mutateInventory(commandInventory(playerSource, arguments[1]), function(inventory)
        if inventory.metadata.containerItem then metadata.containerItem = inventory.metadata.containerItem end
        inventory.metadata = metadata
        return true
    end)
end)
adminCommand('setitemmetadata', function(playerSource, arguments, rawCommand)
    local decoded, value = pcall(json.decode, rawCommand:match('^%S+%s+%S+%s+%S+%s+(.+)$') or '')
    local metadata, metadataError = cleanMetadata(decoded and value or nil)
    if not metadata then return false, metadataError end
    return mutateInventory(commandInventory(playerSource, arguments[1]), function(inventory)
        local item = inventoryCore.find(inventory, tonumber(arguments[2]))
        if not item then return false, 'Item not found' end
        if item.metadata.containerId then metadata.containerId = item.metadata.containerId end
        item.metadata = metadata
        return true
    end)
end)
adminCommand('inspectinventory', function(playerSource, arguments)
    local inventory = getInventoryCopy(commandInventory(playerSource, arguments[1]))
    return inventory ~= nil, inventory and json.encode(inventory) or 'Inventory not found'
end)

local inventoryContext = {
    load = loadInventory,
    player = ensurePlayerInventory,
    identity = database.PlayerInventoryId,
    open = openInventory,
    send = sendInventories,
    commit = commit,
    metadata = cleanMetadata,
    locks = inventoryLocks,
    sessions = sessions,
    put = function(inventory) inventories[inventory.id] = inventory end,
    forget = function(inventoryId) inventories[inventoryId] = nil; committedInventories[inventoryId] = nil end,
}

inventoryContext.extraAccess = function(playerSource, inventoryId)
    return extraInventoryService and extraInventoryService.CanAccess(playerSource, inventoryId) or false
end
inventoryContext.extraRoots = function(playerSource)
    return extraInventoryService and extraInventoryService.Roots(playerSource, false) or {}
end
inventoryContext.restore = restoreInventory
inventoryContext.create = createInventory
inventoryContext.createLinked = function(playerSource, parentInventory, item, typeName, containerId)
    local previousMetadata = inventoryCore.copy(item.metadata)
    local containerMetadata = inventoryCore.copy(TSSContainers[typeName].metadata or {})
    containerMetadata.containerItem = item.name
    item.metadata.containerId = containerId
    local created, creationError = createInventory(containerId, typeName, {
        playerSource = playerSource,
        metadata = containerMetadata,
    }, parentInventory)
    if not created then item.metadata = previousMetadata end
    return created, creationError
end

moneyService = TSSCreateMoneyService({
    players = playerInventoryIds, identity = database.PlayerInventoryId, load = loadInventory,
    locks = inventoryLocks, commit = commit,
})
craftingService = TSSCreateCraftingService({
    identity = database.PlayerInventoryId, load = loadInventory, locks = inventoryLocks,
    commit = commit, operation = runOperation, notify = notifyPlayer,
})
extraInventoryService = TSSCreateExtraInventoryService(inventoryContext)
weightService = TSSCreateWeightService({
    load = loadInventory,
    inventories = inventories,
    committed = committedInventories,
    extraRoots = extraInventoryService.RootsForInventory,
})
storageService = TSSCreateStorageService(inventoryContext)
dropService = TSSCreateWorldDropService(inventoryContext)
shopService = TSSCreateShopService(inventoryContext)

local function unloadCharacter(playerSource)
    craftingService.Cancel(playerSource)
    sessions[playerSource] = nil
    playerInventoryIds[playerSource] = nil
    requestLimits[playerSource] = nil
    dropService.PlayerDisconnected(playerSource)
    storageService.PlayerDisconnected(playerSource)
    TriggerClientEvent('tss-inventory:ownSnapshot', playerSource, nil)
    TriggerClientEvent('tss-inventory:close', playerSource)
end

TSSRegisterItemExports({
    export = registerExport, player = ensurePlayerInventory, load = loadInventory,
    metadata = cleanMetadata, mutate = mutateInventory, handlers = usableItems,
})

database.Start({
    onReady = function()
        for shopId, definition in pairs(TSSShops) do
            local registered, registrationError = runOperation(shopService.Register, shopId, definition)
            if not registered then print(('[tss-inventory] Shop %s failed: %s'):format(shopId, tostring(registrationError))) end
        end
    end,
    onCharacterLoaded = function(playerSource)
        runOperation(function()
            local inventory = ensurePlayerInventory(playerSource)
            if inventory then TriggerClientEvent('tss-inventory:ownSnapshot', playerSource, snapshot(inventory, playerSource)) end
        end)
    end,
    onCharacterUnloaded = function(playerSource) runOperation(unloadCharacter, playerSource) end,
})

AddEventHandler('onResourceStop', function(resourceName)
    for itemName, registration in pairs(usableItems) do
        if registration.resource == resourceName then usableItems[itemName] = nil end
    end
end)

CreateThread(function()
    while true do
        Wait(1000)
        if database.ready then runOperation(function() moneyService.Tick(); shopService.RevokeDistant(); dropService.Tick(); storageService.RevokeInvalid() end) end
    end
end)
