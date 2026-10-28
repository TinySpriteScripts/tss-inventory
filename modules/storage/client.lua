local bridge = exports.tss_bridge:GetModules({ 'Targets', 'Notify' }, Config.TSS)
local loadedVehicles, vehicleModules = pcall(function()
    return exports.tss_bridge:GetModules({ 'Vehicles' }, Config.TSS)
end)
bridge.Vehicles = loadedVehicles and vehicleModules.Vehicles or nil
local vehicleBridgeReady = bridge.Vehicles ~= nil
for _, methodName in ipairs({ 'Nearby', 'Current', 'Inspect', 'TrunkPosition' }) do
    if not bridge.Vehicles or type(bridge.Vehicles[methodName]) ~= 'function' then vehicleBridgeReady = false end
end
if not vehicleBridgeReady then
    print('[tss-inventory] Vehicle storage unavailable: restart updated tss_bridge, then tss-inventory. Personal inventory remains available.')
end
local targetedVehicles = {}

local function showNotice(message)
    bridge.Notify.Send({ title = 'Inventory', description = message, type = 'inform' })
end

local function trunkIsNearby(vehicle)
    if not vehicleBridgeReady then return false end
    if bridge.Vehicles.Current() then return false end
    local info = bridge.Vehicles.Inspect(vehicle)
    if not info or info.locked then return false end
    local trunkPosition = bridge.Vehicles.TrunkPosition(vehicle)
    if not trunkPosition then return false end
    local playerPosition = GetEntityCoords(PlayerPedId())
    return #(playerPosition - trunkPosition) <= Config.VehicleStorage.interactionDistance
end

local function requestVehicle(vehicle, compartment)
    if not vehicleBridgeReady then return showNotice('Vehicle bridge needs updating') end
    local info = bridge.Vehicles.Inspect(vehicle)
    if not info or info.networkId <= 0 then return showNotice('Vehicle is unavailable') end
    TriggerServerEvent('tss-inventory:openVehicle', info.networkId, compartment)
end

TSSInventoryClient = TSSInventoryClient or {}

function TSSInventoryClient.NearbyTrunkNetworkId()
    if not vehicleBridgeReady then return nil end
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
    if not vehicleBridgeReady then return end
    while true do
        local nearbyVehicles = {}
        for _, vehicle in ipairs(bridge.Vehicles.Nearby(Config.VehicleStorage.targetScanDistance)) do
            nearbyVehicles[vehicle] = true
            if bridge.Targets.System() and not targetedVehicles[vehicle] then
                local targetVehicle = vehicle
                local target = bridge.Targets.Entity(targetVehicle, {
                    {
                        name = 'tss_inventory_trunk', label = 'Open trunk', icon = 'fas fa-box-open',
                        canInteract = function() return trunkIsNearby(targetVehicle) end,
                        onSelect = function() requestVehicle(targetVehicle, 'trunk') end,
                    },
                    {
                        name = 'tss_inventory_glovebox', label = 'Open glovebox', icon = 'fas fa-box',
                        canInteract = function() return bridge.Vehicles.Current() == targetVehicle end,
                        onSelect = function() requestVehicle(targetVehicle, 'glovebox') end,
                    },
                }, Config.VehicleStorage.interactionDistance)
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
    for vehicle in pairs(targetedVehicles) do bridge.Targets.RemoveEntity(vehicle) end
end)
