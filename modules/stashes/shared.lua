-- Container definitions with coordinates are fixed stashes, not carried storage types.
TSSStaticStashes = {}

for stashName, definition in pairs(TSSContainers or {}) do
    if definition.coords then TSSStaticStashes[stashName] = definition end
end

function TSSStashDistance(definition)
    local distance = definition.distance
    if type(distance) ~= 'number' or distance ~= distance or distance <= 0 or distance == math.huge then return 2.0 end
    return distance
end

function TSSStashCoordinates(definition)
    local coordinates = definition.coords
    local coordinateType = type(coordinates)
    if coordinateType ~= 'table' and coordinateType ~= 'vector3' and coordinateType ~= 'vector4' then return nil end
    local result = {}
    for _, axis in ipairs({ 'x', 'y', 'z' }) do
        local value = coordinates[axis]
        if type(value) ~= 'number' or value ~= value or math.abs(value) > 100000 then return nil end
        result[axis] = value
    end
    return result
end
