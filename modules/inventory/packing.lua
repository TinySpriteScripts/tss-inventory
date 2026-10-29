-- Bounded rectangle packing. Item identity, stacks and metadata are preserved.
local core = TSSCore
local maximumChecks = 200000

local function layoutScore(items, columns, definitions)
    local bottom, right, positionSum = 0, 0, 0
    for _, item in ipairs(items) do
        local size = definitions[item.name].size
        local width, height = item.rotated and size.y or size.x, item.rotated and size.x or size.y
        bottom = math.max(bottom, item.y + height - 1)
        right = math.max(right, item.x + width - 1)
        positionSum = positionSum + (item.y - 1) * columns + item.x
    end
    return { bottom, right, positionSum }
end

local function betterScore(candidate, previous)
    for index = 1, #candidate do
        if candidate[index] ~= previous[index] then return candidate[index] < previous[index] end
    end
    return false
end

local function contains(outer, inner)
    return inner.x >= outer.x and inner.y >= outer.y
        and inner.x + inner.width <= outer.x + outer.width and inner.y + inner.height <= outer.y + outer.height
end

local function splitSpaces(spaces, occupied, budget)
    local split = {}
    for _, space in ipairs(spaces) do
        if occupied.x >= space.x + space.width or occupied.x + occupied.width <= space.x
            or occupied.y >= space.y + space.height or occupied.y + occupied.height <= space.y then
            split[#split + 1] = space
        else
            if occupied.x > space.x then split[#split + 1] = { x = space.x, y = space.y, width = occupied.x - space.x, height = space.height } end
            if occupied.x + occupied.width < space.x + space.width then
                split[#split + 1] = { x = occupied.x + occupied.width, y = space.y,
                    width = space.x + space.width - occupied.x - occupied.width, height = space.height }
            end
            if occupied.y > space.y then split[#split + 1] = { x = space.x, y = space.y, width = space.width, height = occupied.y - space.y } end
            if occupied.y + occupied.height < space.y + space.height then
                split[#split + 1] = { x = space.x, y = occupied.y + occupied.height,
                    width = space.width, height = space.y + space.height - occupied.y - occupied.height }
            end
        end
    end
    if #split > 256 then return nil end
    local pruned = {}
    for index, space in ipairs(split) do
        local redundant = false
        for otherIndex, other in ipairs(split) do
            budget.checks = budget.checks + 1
            if budget.checks > maximumChecks then return nil end
            if index ~= otherIndex and contains(other, space)
                and (otherIndex < index or not contains(space, other)) then redundant = true; break end
        end
        if not redundant then pruned[#pruned + 1] = space end
    end
    return pruned
end

local function pack(inventory, order, bestFit, budget, definitions)
    local items = {}
    for _, item in ipairs(inventory.items) do
        items[#items + 1] = { id = item.id, name = item.name, x = item.x, y = item.y, rotated = item.rotated }
    end
    table.sort(items, function(first, second)
        local firstDefinition, secondDefinition = definitions[first.name], definitions[second.name]
        local firstSize, secondSize = firstDefinition.size, secondDefinition.size
        local firstValue = order == 'area' and firstSize.x * firstSize.y or math.max(firstSize.x, firstSize.y)
        local secondValue = order == 'area' and secondSize.x * secondSize.y or math.max(secondSize.x, secondSize.y)
        if firstValue ~= secondValue then return firstValue > secondValue end
        return first.id < second.id
    end)
    local spaces = { { x = 1, y = 1, width = inventory.size.x, height = inventory.size.y } }
    for _, item in ipairs(items) do
        local definition = definitions[item.name]
        local placement, placementScore
        for _, space in ipairs(spaces) do
            for _, rotated in ipairs({ false, true }) do
                budget.checks = budget.checks + 1
                if budget.checks > maximumChecks then return nil end
                local width = rotated and definition.size.y or definition.size.x
                local height = rotated and definition.size.x or definition.size.y
                if width <= space.width and height <= space.height then
                    local score = bestFit and { math.min(space.width - width, space.height - height), space.y + height, space.x }
                        or { space.y + height, space.y, space.x }
                    if not placementScore or betterScore(score, placementScore) then
                        placementScore = score
                        placement = { x = space.x, y = space.y, width = width, height = height, rotated = rotated }
                    end
                end
            end
        end
        if not placement then return nil end
        item.x, item.y, item.rotated = placement.x, placement.y, placement.rotated
        spaces = splitSpaces(spaces, placement, budget)
        if not spaces then return nil end
    end
    return items
end

function core.repack(inventory, requireValidLayout)
    if inventory.metadata and inventory.metadata.clothingEquipment then return false, 'Clothing slots have fixed positions' end
    local definitions = {}
    local occupiedCells = 0
    for _, item in ipairs(inventory.items) do
        if not definitions[item.name] then definitions[item.name] = core.definition(item.name) end
        local size = definitions[item.name].size
        occupiedCells = occupiedCells + size.x * size.y
    end
    local bestItems = not requireValidLayout and inventory.items or nil
    local bestScore = bestItems and layoutScore(bestItems, inventory.size.x, definitions) or nil
    if bestScore and occupiedCells == bestScore[1] * inventory.size.x then return true end
    local budget = { checks = 0 }
    for _, order in ipairs({ 'area', 'side' }) do
        for _, bestFit in ipairs({ false, true }) do
            local candidate = pack(inventory, order, bestFit, budget, definitions)
            if candidate then
                local score = layoutScore(candidate, inventory.size.x, definitions)
                if not bestScore or betterScore(score, bestScore) then bestItems, bestScore = candidate, score end
            end
            if budget.checks >= maximumChecks then break end
        end
        if budget.checks >= maximumChecks then break end
    end
    if not bestItems then return false, 'Items do not fit this inventory' end
    local placements = {}
    for _, item in ipairs(bestItems) do placements[item.id] = item end
    for _, item in ipairs(inventory.items) do
        local placement = placements[item.id]
        item.x, item.y, item.rotated = placement.x, placement.y, placement.rotated
    end
    return true
end
