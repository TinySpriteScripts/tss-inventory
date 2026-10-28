local isOpen = false
local nextRequestId = 0
local pendingRequests = {}
local ownInventory = nil
local readyInventoryId = nil
local itemKeybinds = {}
local pressedItemKeys = {}
local bridge = exports.tss_bridge:GetModules({ 'Notify' }, Config.TSS)

local function copyValue(value)
    if type(value) ~= 'table' then return value end
    local copiedValue = {}
    for fieldName, fieldValue in pairs(value) do copiedValue[fieldName] = copyValue(fieldValue) end
    return copiedValue
end

local function closeInventory(shouldNotifyServer)
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'close' })
    if shouldNotifyServer ~= false then TriggerServerEvent('tss-inventory:closeSession') end
end

local function requestOwnInventory()
    local nearbyTrunkNetworkId = TSSInventoryClient and TSSInventoryClient.NearbyTrunkNetworkId()
    TriggerServerEvent('tss-inventory:openSelf', nearbyTrunkNetworkId)
end

RegisterCommand('inv', function()
    if isOpen then closeInventory() else requestOwnInventory() end
end, false)

RegisterCommand('inventorysettings', function() TriggerServerEvent('tss-inventory:openSettings') end, false)

RegisterKeyMapping('inv', 'Open inventory', 'keyboard', Config.OpenKey)

RegisterNetEvent('tss-inventory:sync', function(inventories, visibleMetadata, cellSize)
    if source ~= 65535 then return end
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ type = 'sync', inventories = inventories, visibleMetadata = visibleMetadata, cellSize = cellSize })
end)

RegisterNetEvent('tss-inventory:close', function()
    if source == 65535 then closeInventory(false) end
end)

local function showItemBox(definition, action, amount)
    if type(definition) ~= 'table' or (action ~= 'added' and action ~= 'removed') then return false end
    amount = amount or 1
    if type(amount) ~= 'number' or amount % 1 ~= 0 or amount < 1 or amount > 100000 then return false end
    SendNUIMessage({ type = 'itemBox', definition = definition, action = action, amount = amount })
    return true
end

RegisterNetEvent('tss-inventory:itemBox', function(definition, action, amount)
    if source == 65535 then showItemBox(definition, action, amount) end
end)

exports('ItemBox', function(itemName, action, amount)
    if not TSSItems[itemName] then return false end
    local definition = copyValue(Config.ItemDefaults)
    for fieldName, fieldValue in pairs(TSSItems[itemName]) do definition[fieldName] = copyValue(fieldValue) end
    definition.name = itemName
    return showItemBox(definition, action, amount)
end)

RegisterNetEvent('tss-inventory:notice', function(message)
    if source ~= 65535 then return end
    SendNUIMessage({ type = 'notice', message = tostring(message) })
    bridge.Notify.Send({ title = 'Inventory', description = tostring(message), type = 'inform' })
end)

RegisterNetEvent('tss-inventory:result', function(requestId, succeeded, message)
    if source ~= 65535 then return end
    local callback = pendingRequests[requestId]
    if callback then
        pendingRequests[requestId] = nil
        callback({ ok = succeeded, message = message })
    end
end)

RegisterNetEvent('tss-inventory:ownSnapshot', function(inventory)
    if source ~= 65535 then return end
    ownInventory = inventory
    itemKeybinds = inventory and inventory.itemKeybinds or {}
    SendNUIMessage({ type = 'itemKeybinds', bindings = itemKeybinds })
    if not inventory then
        readyInventoryId = nil
    elseif inventory.id ~= readyInventoryId then
        readyInventoryId = inventory.id
        bridge.Notify.Send({ title = 'Inventory', description = 'Inventory ready', type = 'success' })
    end
    SendNUIMessage({ type = 'preferences', settings = inventory and inventory.playerSettings or {} })
end)

RegisterNetEvent('tss-inventory:settings', function(settings)
    if source ~= 65535 then return end
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ type = 'openSettings', settings = settings })
end)

RegisterNetEvent('tss-inventory:resetLayouts', function()
    if source == 65535 then SendNUIMessage({ type = 'resetLayouts' }) end
end)

RegisterNUICallback('settingsClosed', function(request, callback)
    isOpen = request.inventoryOpen == true
    SetNuiFocus(isOpen, isOpen)
    callback({ ok = true })
end)

RegisterNUICallback('useItemKey', function(request, callback)
    TriggerServerEvent('tss-inventory:useItemKey', request.keyCode)
    callback({ ok = true })
end)

RegisterNUICallback('close', function(_, callback)
    closeInventory()
    callback({ ok = true })
end)

RegisterNUICallback('closeInventory', function(request, callback)
    TriggerServerEvent('tss-inventory:closeSession', request.id)
    callback({ ok = true })
end)

RegisterNUICallback('action', function(request, callback)
    nextRequestId = nextRequestId + 1
    local requestId = nextRequestId
    pendingRequests[requestId] = callback
    TriggerServerEvent('tss-inventory:action', requestId, request)
    SetTimeout(10000, function()
        if pendingRequests[requestId] then
            pendingRequests[requestId] = nil
            callback({ ok = false, message = 'Server request timed out' })
        end
    end)
end)

exports('HasItem', function(requirements, amount) return TSSItemExports.HasItem(ownInventory and ownInventory.items or {}, requirements, amount) end)

exports('GetLocalInventory', function() return copyValue(ownInventory) end)

exports('GetItemDefinitions', function()
    local definitions = {}
    for itemName, itemDefinition in pairs(TSSItems) do
        local definition = copyValue(Config.ItemDefaults)
        for fieldName, fieldValue in pairs(itemDefinition) do definition[fieldName] = copyValue(fieldValue) end
        definition.name = itemName
        definition.stackSize = definition.stack and definition.stackSize or 1
        definitions[itemName] = definition
    end
    return definitions
end)

exports('OpenSelf', function() requestOwnInventory(); return true end)

exports('OpenShop', function(shopId) TriggerServerEvent('tss-inventory:openShop', shopId); return true end)

exports('CloseInventory', function() closeInventory(); return true end)

CreateThread(function()
    while true do
        if isOpen then
            for _, controlId in ipairs({ 1, 2, 24, 25 }) do DisableControlAction(0, controlId, true) end
            DisablePlayerFiring(PlayerId(), true)
            Wait(0)
        else Wait(200) end
    end
end)

CreateThread(function()
    while true do
        Wait(2000)
        if not ownInventory then TriggerServerEvent('tss-inventory:requestOwn') end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then SetNuiFocus(false, false) end
end)

-- Read keyboard state directly; item bindings never register FiveM commands/mappings.
CreateThread(function()
    if type(IsRawKeyDown) ~= 'function' then
        print('[tss-inventory] Raw keyboard input is unavailable on this client; item keys still work inside the inventory.')
        return
    end
    while true do
        local hasBindings = next(itemKeybinds) ~= nil
        if hasBindings then
            local canUseKeys = ownInventory ~= nil and not isOpen and not IsNuiFocused() and not IsPauseMenuActive()
            for storedKey in pairs(itemKeybinds) do
                local keyCode = tonumber(storedKey)
                if keyCode and keyCode ~= 27 then
                    local isDown = IsRawKeyDown(keyCode)
                    if canUseKeys and isDown and not pressedItemKeys[keyCode] then
                        TriggerServerEvent('tss-inventory:useItemKey', keyCode)
                    end
                    pressedItemKeys[keyCode] = isDown
                end
            end
        else pressedItemKeys = {} end
        Wait(hasBindings and 0 or 200)
    end
end)
