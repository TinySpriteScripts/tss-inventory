-- Persistent vehicle compartments and item-bound containers. SQL stays in database.lua.
function TSSCreateStorageService(context)
    local inventoryCore = TSSCore
    local loadedBridge, bridge = pcall(function()
        return exports.tss_bridge:GetModules({ 'Vehicles' }, Config.TSS)
    end)
    local vehicles = loadedBridge and bridge.Vehicles
    local vehicleBridgeReady = vehicles and type(vehicles.FromNetworkId) == 'function'
        and type(vehicles.Inspect) == 'function' and type(vehicles.Current) == 'function'
    if not vehicleBridgeReady then
        print('[tss-inventory] Vehicle storage unavailable: restart updated tss_bridge, then tss-inventory. Personal inventories and database startup remain available.')
    end
    local vehicleGrants = {}
    local storageService = {}
    local modelOverrides = {}
    local classNames = {}

    for className, classNumber in pairs(Config.VehicleClasses) do classNames[classNumber] = className end
    for modelName, definition in pairs(TSSVehicles) do
        if Config.VehicleClasses[modelName] == nil then modelOverrides[joaat(modelName)] = definition end
    end

    local function vehicleDefinition(vehicleInfo, compartment)
        local modelOverride = modelOverrides[vehicleInfo.model]
        local vehicleClass = modelOverride and modelOverride.class or TSSVehicleModelClasses[vehicleInfo.model]
        if vehicleClass == nil then
            local typeClasses = { bike = 8, boat = 14, heli = 15, plane = 16, train = 21, trailer = 20, submarine = 14 }
            vehicleClass = typeClasses[vehicleInfo.vehicleType]
        end
        local definition = modelOverride or TSSVehicles[classNames[vehicleClass]]
        if definition then return definition[compartment] or false, vehicleClass end
        return Config.VehicleDefaults[compartment], vehicleClass
    end

    local function validateVehicle(playerSource, networkId, compartment, expectedPlate)
        if not vehicleBridgeReady then return nil, 'Vehicle bridge needs updating; restart tss_bridge then tss-inventory' end
        if compartment ~= 'trunk' and compartment ~= 'glovebox' then return nil, 'Invalid compartment' end
        local vehicle = bridge.Vehicles.FromNetworkId(networkId)
        local info = vehicle and bridge.Vehicles.Inspect(vehicle)
        local playerPed = GetPlayerPed(playerSource)
        if not info or not playerPed or playerPed == 0 or #info.plate == 0 or #info.plate > 16
            or (expectedPlate and info.plate ~= expectedPlate)
            or GetPlayerRoutingBucket(playerSource) ~= info.bucket then return nil, 'Vehicle is unavailable' end
        local position = GetEntityCoords(playerPed)
        local distanceSquared = (position.x - info.coords.x) ^ 2 + (position.y - info.coords.y) ^ 2 + (position.z - info.coords.z) ^ 2
        if distanceSquared > Config.VehicleStorage.serverDistance ^ 2 then return nil, 'Move closer to the vehicle' end
        local occupiedVehicle = bridge.Vehicles.Current(playerSource)
        if compartment == 'glovebox' then
            if occupiedVehicle ~= vehicle then return nil, 'You must be inside this vehicle' end
        else
            if occupiedVehicle then return nil, 'Exit the vehicle to open its trunk' end
            if info.locked then return nil, 'Vehicle is locked' end
        end
        return info
    end

    local function plateIdentifier(plate)
        return (plate:gsub('.', function(character) return ('%02x'):format(character:byte()) end))
    end

    function storageService.OpenVehicle(playerSource, networkId, compartment)
        local ownInventory, playerError = context.player(playerSource)
        if not ownInventory then return false, playerError end
        local info, accessError = validateVehicle(playerSource, networkId, compartment)
        if not info then return false, accessError end
        local definition, vehicleClass = vehicleDefinition(info, compartment)
        if not definition then return false, 'This vehicle has no ' .. compartment end
        local inventoryId = compartment .. '_' .. plateIdentifier(info.plate)
        local inventory = context.load(inventoryId)
        if not inventory then
            local options = inventoryCore.copy(definition)
            options.playerSource = playerSource
            options.coords = info.coords
            options.metadata = options.metadata or {}
            options.metadata.vehicle = { plate = info.plate, model = info.model, class = vehicleClass }
            local created, creationError = context.create(inventoryId, compartment, options)
            if not created then return false, creationError end
            inventory = context.load(inventoryId)
        end
        if inventory.type ~= compartment then return false, 'Vehicle inventory ID conflicts with another inventory' end
        -- SQL can yield; check the entity and character again before granting access.
        local stillAvailable, validationError = validateVehicle(playerSource, networkId, compartment, info.plate)
        if not stillAvailable or context.identity(playerSource) ~= ownInventory.id then return false, validationError or 'Character changed' end
        inventory.coords = stillAvailable.coords
        context.commit(inventory)
        vehicleGrants[playerSource] = vehicleGrants[playerSource] or {}
        vehicleGrants[playerSource][inventoryId] = { networkId = networkId, compartment = compartment, plate = info.plate, model = info.model }
        return context.open(playerSource, inventoryId)
    end

    function storageService.OpenCurrentGlovebox(playerSource)
        if not vehicleBridgeReady then return false end
        local vehicle = bridge.Vehicles.Current(playerSource)
        local info = vehicle and bridge.Vehicles.Inspect(vehicle)
        if info then return storageService.OpenVehicle(playerSource, info.networkId, 'glovebox') end
        return false
    end

    -- Follow only server-stored item links from the holder's personal inventory.
    local function carriesContainer(playerSource, targetId)
        local ownInventory = context.player(playerSource)
        if not ownInventory then return false end
        local visitedInventories = {}
        local function search(inventory, depth)
            if depth > 8 or visitedInventories[inventory.id] then return false end
            visitedInventories[inventory.id] = true
            for _, item in ipairs(inventory.items) do
                local definition = inventoryCore.definition(item.name)
                local containerId = definition and definition.container and item.metadata.containerId
                if type(containerId) == 'string' then
                    local container = context.load(containerId)
                    if container and container.type == definition.container and container.metadata.containerItem == item.name then
                        if containerId == targetId or search(container, depth + 1) then return true end
                    end
                end
            end
            return false
        end
        if search(ownInventory, 0) then return true end
        for _, extraInventory in ipairs(context.extraRoots(playerSource) or {}) do
            if search(extraInventory, 0) then return true end
        end
        return false
    end

    function storageService.CanAccess(playerSource, inventoryId)
        local inventory = context.load(inventoryId)
        if not inventory then return false end
        if inventory.type == 'extra' then return context.extraAccess(playerSource, inventoryId) end
        if inventory.metadata.containerItem then return carriesContainer(playerSource, inventoryId) end
        local grant = vehicleGrants[playerSource] and vehicleGrants[playerSource][inventoryId]
        if grant then
            local info = validateVehicle(playerSource, grant.networkId, grant.compartment, grant.plate)
            return info ~= nil and info.model == grant.model
        end
        -- Vehicle storage always needs an entity-backed grant; other containers use trusted server grants.
        return inventory.type ~= 'trunk' and inventory.type ~= 'glovebox'
    end

    function storageService.OpenItem(playerSource, sourceInventory, itemId)
        if not context.sessions[playerSource] or not context.sessions[playerSource][sourceInventory.id]
            or not storageService.CanAccess(playerSource, sourceInventory.id) then return false, 'Inventory access denied' end
        local item = inventoryCore.find(sourceInventory, itemId)
        local definition = item and inventoryCore.definition(item.name)
        if not definition or not definition.useable or not definition.container or not TSSContainers[definition.container] then return false, 'Item is not a container' end
        if definition.stack or item.amount ~= 1 then return false, 'Container items must not stack' end
        -- Only carried items may open storage, including a wallet inside a carried backpack.
        if sourceInventory.id ~= context.identity(playerSource) and not sourceInventory.metadata.containerItem
            and not (sourceInventory.type == 'extra' and context.extraAccess(playerSource, sourceInventory.id)) then return false, 'Carry the item before opening it' end
        local containerId = item.metadata.containerId
        if containerId == nil then
            containerId = ('%s_%x%x'):format(definition.container, os.time(), math.random(1, 0x7fffffff))
            local created, creationError = context.createLinked(playerSource, sourceInventory, item, definition.container, containerId)
            if not created then return false, creationError end
        end
        local container = type(containerId) == 'string' and context.load(containerId)
        if not container or container.type ~= definition.container or container.metadata.containerItem ~= item.name then return false, 'Container link is invalid' end
        if not carriesContainer(playerSource, container.id) then return false, 'You no longer carry this container' end
        return context.open(playerSource, container.id)
    end

    function storageService.CanMove(item, targetId)
        local definition = inventoryCore.definition(item.name)
        local linkedId = definition and definition.container and item.metadata.containerId
        if type(linkedId) ~= 'string' then return true end
        local visitedInventories = {}
        local function containsTarget(inventoryId, depth)
            if inventoryId == targetId then return true end
            if depth > 8 then return true end
            if visitedInventories[inventoryId] then return false end
            visitedInventories[inventoryId] = true
            local inventory = context.load(inventoryId)
            if not inventory then return false end
            for _, childItem in ipairs(inventory.items) do
                local childDefinition = inventoryCore.definition(childItem.name)
                local childId = childDefinition and childDefinition.container and childItem.metadata.containerId
                if type(childId) == 'string' and containsTarget(childId, depth + 1) then return true end
            end
            return false
        end
        return not containsTarget(linkedId, 0)
    end

    function storageService.RevokeInvalid()
        for playerSource, inventorySession in pairs(context.sessions) do
            local changed = false
            for inventoryId in pairs(inventorySession) do
                if not storageService.CanAccess(playerSource, inventoryId) then inventorySession[inventoryId] = nil; changed = true end
            end
            if changed then context.send(playerSource) end
        end
    end

    function storageService.PlayerDisconnected(playerSource) vehicleGrants[playerSource] = nil end

    return storageService
end
