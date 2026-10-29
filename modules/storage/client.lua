local bridge = exports.tss_bridge:GetModules({ 'Targets', 'Notify' }, Config.TSS)
local function isBridgeFunction(callback)
    return type(callback) == 'function'
        or (type(callback) == 'table' and rawget(callback, '__cfx_functionReference') ~= nil)
end

local vehicleBridgeReady = false

local function ensureVehicleBridge()
    if vehicleBridgeReady then return true end

    local loadedVehicles, vehicleModules = pcall(function()
        return exports.tss_bridge:GetModules({ 'Vehicles' }, Config.TSS)
    end)
    local vehicles = loadedVehicles and type(vehicleModules) == 'table' and vehicleModules.Vehicles
    if not vehicles then return false end

    for _, methodName in ipairs({ 'Nearby', 'Current', 'Inspect', 'TrunkPosition' }) do
        if not isBridgeFunction(vehicles[methodName]) then return false end
    end

    bridge.Vehicles = vehicles
    vehicleBridgeReady = true
    return true
end

ensureVehicleBridge()

local targetedVehicles = {}
local trunkBoneRegistered = false
local openedTrunks = {}

local function showNotice(message)
    bridge.Notify.Send({ title = 'Inventory', description = message, type = 'inform' })
end

local function trunkIsNearby(vehicle)
    if not ensureVehicleBridge() then return false end
    if bridge.Vehicles.Current() then return false end
    local info = bridge.Vehicles.Inspect(vehicle)
    if not info or info.locked then return false end
    local trunkPosition = bridge.Vehicles.TrunkPosition(vehicle)
    if not trunkPosition then return false end
    local playerPosition = GetEntityCoords(PlayerPedId())
    return #(playerPosition - trunkPosition) <= Config.VehicleStorage.interactionDistance
end

local function requestVehicle(vehicle, compartment)
    if not ensureVehicleBridge() then return showNotice('Vehicle storage is temporarily unavailable') end
    local info = bridge.Vehicles.Inspect(vehicle)
    if not info or info.networkId <= 0 then return showNotice('Vehicle is unavailable') end
    TriggerServerEvent('tss-inventory:openVehicle', info.networkId, compartment)
end

RegisterNetEvent('tss-inventory:trunkDoor', function(networkId, shouldOpen, plate, model)
    if source ~= 65535 or not ensureVehicleBridge() or not isBridgeFunction(bridge.Vehicles.SetTrunkOpen)
        or not isBridgeFunction(bridge.Vehicles.FromNetworkId) then return end
    local vehicle = bridge.Vehicles.FromNetworkId(networkId)
    local info = vehicle and bridge.Vehicles.Inspect(vehicle)
    local previous = openedTrunks[networkId]
    if not shouldOpen and previous and previous.plate == plate and previous.model == model then openedTrunks[networkId] = nil end
    if not info or info.plate ~= plate or info.model ~= model then return end
    if previous and (previous.plate ~= plate or previous.model ~= model or previous.vehicle ~= vehicle) then
        openedTrunks[networkId] = nil
        previous = nil
    end
    if shouldOpen then
        if previous then return end
        local succeeded, wasOpen = bridge.Vehicles.SetTrunkOpen(vehicle, true)
        if succeeded then openedTrunks[networkId] = { vehicle = vehicle, plate = plate, model = model, wasOpen = wasOpen } end
    elseif previous then
        if not previous.wasOpen and previous.vehicle == vehicle then bridge.Vehicles.SetTrunkOpen(vehicle, false) end
        openedTrunks[networkId] = nil
    else
        -- A client may have streamed the vehicle in after the open event.
        bridge.Vehicles.SetTrunkOpen(vehicle, false)
    end
end)

TSSInventoryClient = TSSInventoryClient or {}

function TSSInventoryClient.NearbyTrunkNetworkId()
    if not ensureVehicleBridge() then return nil end
    if bridge.Vehicles.Current() then return nil end
    local nearestNetworkId, nearestDistance
    local playerPosition = GetEntityCoords(PlayerPedId())
    for _, vehicle in ipairs(bridge.Vehicles.Nearby(Config.VehicleStorage.targetScanDistance)) do
        if trunkIsNearby(vehicle) then
            local info = bridge.Vehicles.Inspect(vehicle)
            local distance = #(playerPosition - bridge.Vehicles.TrunkPosition(vehicle))
            if info and info.networkId > 0 and (not nearestDistance or distance < nearestDistance) then
                nearestNetworkId, nearestDistance = info.networkId, distance
            end
        end
    end
    return nearestNetworkId
end

CreateThread(function()
    while true do
        while not ensureVehicleBridge() do Wait(1500) end
        if not trunkBoneRegistered and isBridgeFunction(bridge.Targets.Bone) and bridge.Targets.Supports('bones') then
            trunkBoneRegistered = bridge.Targets.Bone({ 'boot' }, {
                {
                    name = 'tss_inventory_trunk', label = 'Open trunk', icon = 'fas fa-box-open',
                    canInteract = function(vehicle) return trunkIsNearby(vehicle) end,
                    onSelect = function(selection)
                        local vehicle = type(selection) == 'table' and selection.entity or selection
                        if vehicle and trunkIsNearby(vehicle) then requestVehicle(vehicle, 'trunk') end
                    end,
                },
            }, Config.VehicleStorage.interactionDistance) == true
        end
        local nearbyVehicles = {}
        for _, vehicle in ipairs(bridge.Vehicles.Nearby(Config.VehicleStorage.targetScanDistance)) do
            nearbyVehicles[vehicle] = true
            if bridge.Targets.System() and not targetedVehicles[vehicle] then
                local targetVehicle = vehicle
                local options = {}
                if not trunkBoneRegistered then
                    options[#options + 1] = {
                        name = 'tss_inventory_trunk', label = 'Open trunk', icon = 'fas fa-box-open',
                        bones = { 'boot' },
                        canInteract = function() return trunkIsNearby(targetVehicle) end,
                        onSelect = function() requestVehicle(targetVehicle, 'trunk') end,
                    }
                end
                options[#options + 1] = {
                    name = 'tss_inventory_glovebox', label = 'Open glovebox', icon = 'fas fa-box',
                    canInteract = function() return bridge.Vehicles.Current() == targetVehicle end,
                    onSelect = function() requestVehicle(targetVehicle, 'glovebox') end,
                }
                local target = bridge.Targets.Entity(targetVehicle, options, Config.VehicleStorage.interactionDistance)
                if target ~= false then targetedVehicles[targetVehicle] = true end
            end
        end
        for vehicle in pairs(targetedVehicles) do
            if not nearbyVehicles[vehicle] then bridge.Targets.RemoveEntity(vehicle); targetedVehicles[vehicle] = nil end
        end
        Wait(1500)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if trunkBoneRegistered then bridge.Targets.RemoveBone({ 'boot' }) end
    for networkId, record in pairs(openedTrunks) do
        local info = bridge.Vehicles.Inspect(record.vehicle)
        if not record.wasOpen and info and info.networkId == networkId and info.plate == record.plate and info.model == record.model then
            bridge.Vehicles.SetTrunkOpen(record.vehicle, false)
        end
    end
    for vehicle in pairs(targetedVehicles) do bridge.Targets.RemoveEntity(vehicle) end
end)
