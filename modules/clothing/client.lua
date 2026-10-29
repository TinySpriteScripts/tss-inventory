if not Config.EnableClothingSystem then return end

TSSInventoryClient = TSSInventoryClient or {}
local clothingClient = {}
TSSInventoryClient.Clothing = clothingClient
local state, baseline, lastPed, lastModel
local managed = { components = {}, props = {} }
local desired = { components = {}, props = {} }
local pending = false
local baselineSent = false
local invalidNotices = {}

function clothingClient.Clear()
    state, baseline, lastPed, lastModel = nil, nil, nil, nil
    managed, desired = { components = {}, props = {} }, { components = {}, props = {} }
    pending, baselineSent, invalidNotices = false, false, {}
    SendNUIMessage({ type = 'clothing', state = false })
end

local function captureBaseline(playerPed, gender)
    local captured = { gender = gender, components = {}, props = {} }
    for componentId in pairs(TSSClothingData.ComponentIds) do
        captured.components[tostring(componentId)] = { drawable = GetPedDrawableVariation(playerPed, componentId),
            texture = GetPedTextureVariation(playerPed, componentId), palette = GetPedPaletteVariation(playerPed, componentId) }
    end
    for propId in pairs(TSSClothingData.PropIds) do
        captured.props[tostring(propId)] = { drawable = GetPedPropIndex(playerPed, propId),
            texture = math.max(0, GetPedPropTextureIndex(playerPed, propId)), palette = 0 }
    end
    return captured
end

local function buildDesired(gender)
    local result = { components = {}, props = {} }
    local variations = {}
    for _, item in ipairs(state.inventory and state.inventory.items or {}) do
        local variation = TSSClothingData.Validate(item)
        if variation and variation.gender == gender then
            variations[#variations + 1] = variation
            if variation.slot == 'top' then
                if variation.arms then result.components['3'] = variation.arms end
                if variation.undershirt then result.components['8'] = variation.undershirt end
            end
        end
    end
    -- Explicit equipment slots take precedence over a top's supporting pieces.
    for _, variation in ipairs(variations) do
        local slot = TSSClothingData.Slots[variation.slot]
        local fieldName = slot.prop ~= nil and 'props' or 'components'
        result[fieldName][tostring(slot.prop or slot.component)] = variation
    end
    return result
end

local function applyVariation(playerPed, fieldName, componentId, variation)
    if fieldName == 'props' then
        if variation.drawable == -1 then
            if GetPedPropIndex(playerPed, componentId) ~= -1 then ClearPedProp(playerPed, componentId) end
            return true
        end
        if variation.drawable >= GetNumberOfPedPropDrawableVariations(playerPed, componentId)
            or variation.texture >= GetNumberOfPedPropTextureVariations(playerPed, componentId, variation.drawable) then return false end
        if GetPedPropIndex(playerPed, componentId) ~= variation.drawable or GetPedPropTextureIndex(playerPed, componentId) ~= variation.texture then
            SetPedPropIndex(playerPed, componentId, variation.drawable, variation.texture, true)
        end
    else
        if variation.drawable >= GetNumberOfPedDrawableVariations(playerPed, componentId)
            or variation.texture >= GetNumberOfPedTextureVariations(playerPed, componentId, variation.drawable) then return false end
        if GetPedDrawableVariation(playerPed, componentId) ~= variation.drawable or GetPedTextureVariation(playerPed, componentId) ~= variation.texture
            or GetPedPaletteVariation(playerPed, componentId) ~= variation.palette then
            SetPedComponentVariation(playerPed, componentId, variation.drawable, variation.texture, variation.palette)
        end
    end
    return true
end

local function updateAppearance()
    if not state then return end
    local playerPed = PlayerPedId()
    if not DoesEntityExist(playerPed) then return end
    local model = GetEntityModel(playerPed)
    local gender = TSSClothingData.Gender(model)
    if not gender or state.gender ~= gender then return end
    if lastPed ~= playerPed or lastModel ~= model then
        managed = { components = {}, props = {} }
        baseline = type(state.baseline) == 'table' and state.baseline or nil
        baselineSent = false
        lastPed, lastModel, pending = playerPed, model, true
    end
    if pending then desired = buildDesired(gender); pending = false end
    local hasItems = state.inventory and #state.inventory.items > 0
    if hasItems and not baseline then baseline = captureBaseline(playerPed, gender) end
    if hasItems and baseline and state.baseline == false and not baselineSent then
        baselineSent = true
        TriggerServerEvent('tss-inventory:clothingBaseline', state.playerInventoryId, baseline)
    end
    for _, fieldName in ipairs({ 'components', 'props' }) do
        for key in pairs(managed[fieldName]) do
            if not desired[fieldName][key] then
                local original = baseline and baseline[fieldName][key]
                if original then applyVariation(playerPed, fieldName, tonumber(key), original) end
                managed[fieldName][key] = nil
            end
        end
        for key, variation in pairs(desired[fieldName]) do
            if applyVariation(playerPed, fieldName, tonumber(key), variation) then managed[fieldName][key] = true
            elseif not invalidNotices[tostring(state.inventory.revision) .. ':' .. fieldName .. ':' .. key] then
                invalidNotices[tostring(state.inventory.revision) .. ':' .. fieldName .. ':' .. key] = true
                SendNUIMessage({ type = 'notice', message = 'Clothing variation is unavailable for this character' })
            end
        end
    end
    if not hasItems then baseline, baselineSent = nil, false end
end

RegisterNetEvent('tss-inventory:clothing', function(payload)
    if source ~= 65535 then return end
    if type(payload) ~= 'table' then clothingClient.Clear(); return end
    if state and state.playerInventoryId ~= payload.playerInventoryId then clothingClient.Clear() end
    state = payload
    if type(payload.baseline) == 'table' then baseline = payload.baseline end
    pending = true
    SendNUIMessage({ type = 'clothing', state = payload })
    updateAppearance()
end)

CreateThread(function()
    while true do
        Wait(500)
        updateAppearance()
    end
end)
