-- Small item helpers shared by exports on client and server.
TSSItemExports = {}
local helpers = TSSItemExports

function helpers.Label(metadata, fallback)
    local label = type(metadata) == 'table' and metadata.label
    if type(label) == 'string' and #label <= 100 and label:match('%S') then return label end
    return fallback
end

function helpers.HasItem(items, requirements, amount)
    local requested = {}
    local function validAmount(value) return type(value) == 'number' and value % 1 == 0 and value >= 1 and value <= 1000000 end
    if amount ~= nil and not validAmount(amount) then return false end
    if type(requirements) == 'string' and #requirements > 0 then requested[requirements:lower()] = amount or 1
    elseif type(requirements) == 'table' then
        for itemKey, value in pairs(requirements) do
            local itemName, requiredAmount
            if type(itemKey) == 'number' then itemName, requiredAmount = value, amount or 1
            else itemName, requiredAmount = itemKey, value end
            if type(itemName) ~= 'string' or #itemName == 0 or not validAmount(requiredAmount) then return false end
            requested[itemName:lower()] = math.max(requested[itemName:lower()] or 0, requiredAmount)
        end
    else return false end
    if not next(requested) then return false end
    local counts = {}
    for _, item in pairs(items or {}) do
        if type(item) == 'table' and type(item.name) == 'string' then
            local name = item.name:lower()
            counts[name] = (counts[name] or 0) + (tonumber(item.amount or item.count) or 0)
        end
    end
    for itemName, required in pairs(requested) do if (counts[itemName] or 0) < required then return false end end
    return true
end

function helpers.Item(item, definition)
    local result = {}
    for fieldName, value in pairs(item) do result[fieldName] = value end
    result.slot = item.id
    result.info = item.metadata
    result.label = helpers.Label(item.metadata, definition.label or item.name)
    result.description = definition.description
    result.weight = definition.weight
    result.image = definition.image or (item.name .. '.png')
    result.unique = not definition.stack
    result.useable = definition.useable
    result.type = definition.category == 'weapon' and 'weapon' or 'item'
    result.shouldClose = true
    return result
end

function helpers.IsLootContainerType(typeName)
    local definition = TSSContainers and TSSContainers[typeName]
    return definition ~= nil and definition.items ~= nil and not definition.coords
end

function helpers.CheckItems(inventory)
    local items = {}
    for _, item in ipairs(inventory and inventory.items or {}) do items[#items + 1] = item end
    for _, item in ipairs(inventory and inventory.extraInventoryItems or {}) do items[#items + 1] = item end
    return items
end
