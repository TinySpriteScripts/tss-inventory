local bridge = exports.tss_bridge:GetModules({ 'Targets' }, Config.TSS)
local zones = {}

local function isNearby(definition)
    local coordinates = TSSStashCoordinates(definition)
    if not coordinates then return false end
    local position = GetEntityCoords(PlayerPedId())
    return (position.x - coordinates.x) ^ 2 + (position.y - coordinates.y) ^ 2 + (position.z - coordinates.z) ^ 2
        <= TSSStashDistance(definition) ^ 2
end

CreateThread(function()
    while true do
        local pending = false
        for stashName, definition in pairs(TSSStaticStashes) do
            if definition.target ~= false and not zones[stashName] then
                pending = true
                local coordinates = TSSStashCoordinates(definition)
                if coordinates and bridge.Targets.System() then
                    local selectedName, selectedDefinition = stashName, definition
                    local zone = bridge.Targets.Circle({ name = 'tss_inventory_stash_' .. stashName,
                        coords = vec3(coordinates.x, coordinates.y, coordinates.z), radius = 0.6 }, {{
                        name = 'tss_inventory_stash_' .. stashName,
                        label = 'Open ' .. (definition.label or stashName), icon = 'fas fa-box-open',
                        canInteract = function() return isNearby(selectedDefinition) end,
                        onSelect = function() TriggerServerEvent('tss-inventory:openStash', selectedName) end,
                    }}, TSSStashDistance(definition))
                    if zone ~= nil and zone ~= false then zones[stashName] = zone end
                end
            end
        end
        if not pending then break end
        Wait(1500)
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for _, zone in pairs(zones) do bridge.Targets.RemoveZone(zone) end
end)

-- Only nearby-opening stashes without a target use markers.
CreateThread(function()
    local settings = Config.FixedStash or {}
    if type(settings.Marker) ~= 'number' or settings.Marker % 1 ~= 0 or settings.Marker < 0 then return end
    local drawDistance = settings.drawDistance
    if type(drawDistance) ~= 'number' or drawDistance ~= drawDistance or drawDistance <= 0 or drawDistance == math.huge then drawDistance = 5.0 end
    local markerStashes = {}
    for _, definition in pairs(TSSStaticStashes) do
        if definition.target == false and definition.openWhenNearby ~= false then
            local coordinates = TSSStashCoordinates(definition)
            if coordinates then markerStashes[#markerStashes + 1] = coordinates end
        end
    end
    if #markerStashes == 0 then return end
    while true do
        local position = GetEntityCoords(PlayerPedId())
        local visible = false
        for _, coordinates in ipairs(markerStashes) do
            local distance = (position.x - coordinates.x) ^ 2 + (position.y - coordinates.y) ^ 2 + (position.z - coordinates.z) ^ 2
            if distance <= drawDistance ^ 2 then
                DrawMarker(settings.Marker, coordinates.x, coordinates.y, coordinates.z + 0.15,
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.25, 0.25, 0.25,
                    217, 74, 80, 175, false, true, 2, false, nil, nil, false)
                visible = true
            end
        end
        Wait(visible and 0 or 500)
    end
end)
