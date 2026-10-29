TSSClothingData = { Slots = {}, ComponentIds = { [3] = true }, PropIds = {} }
local clothing = TSSClothingData

for index, slot in ipairs(TSSClothingSlots or {}) do
    slot.x, slot.y = (index - 1) % 4 + 1, math.floor((index - 1) / 4) + 1
    clothing.Slots[slot.id] = slot
    if slot.component then clothing.ComponentIds[slot.component] = true end
    if slot.prop then clothing.PropIds[slot.prop] = true end
end

local function integer(value, minimum, maximum)
    return type(value) == 'number' and value == value and value % 1 == 0 and value >= minimum and value <= maximum
end

function clothing.Variation(value, prop)
    if type(value) ~= 'table' or not integer(value.drawable, prop and -1 or 0, 8191)
        or not integer(value.texture or 0, 0, 255) or not integer(value.palette or 0, 0, 3) then return nil end
    return { drawable = value.drawable, texture = value.texture or 0, palette = value.palette or 0 }
end

function clothing.Validate(item)
    local definition = item and TSSItems[item.name]
    local slot = definition and clothing.Slots[definition.clothingSlot]
    local data = item and type(item.metadata) == 'table' and item.metadata.clothing
    if not slot or type(data) ~= 'table' or (data.slot ~= nil and data.slot ~= slot.id)
        or (data.gender ~= 'male' and data.gender ~= 'female') then return nil, 'Invalid clothing slot or gender' end
    local variation = clothing.Variation(data, slot.prop ~= nil)
    if not variation then return nil, 'Invalid clothing variation' end
    variation.slot, variation.gender = slot.id, data.gender
    if slot.id == 'top' then
        for _, support in ipairs({ 'arms', 'undershirt' }) do
            if data[support] ~= nil then
                variation[support] = clothing.Variation(data[support], false)
                if not variation[support] then return nil, 'Invalid ' .. support .. ' variation' end
            end
        end
    end
    return variation
end

function clothing.Gender(model)
    if model == joaat('mp_m_freemode_01') then return 'male' end
    if model == joaat('mp_f_freemode_01') then return 'female' end
end
