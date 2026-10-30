local isOpen = false
local isCrafting = false
local pendingCraftRequestId = nil
local nextRequestId = 0
local pendingRequests = {}
local ownInventory = nil
local readyInventoryId = nil
local itemKeybinds = {}
local pressedItemKeys = {}
local bridge = exports.tss_bridge:GetModules({ 'Notify', 'Commands' }, Config.TSS)
local uiReady = false
local pendingUiMessages = {}
local lastOpenMessage = nil

local function sendUiMessage(message)
    if uiReady then SendNUIMessage(message); return end
    -- Keep the newest state of each type while the browser is loading.
    if message.type ~= 'itemBox' then
        for messageIndex = #pendingUiMessages, 1, -1 do
            if pendingUiMessages[messageIndex].type == message.type then table.remove(pendingUiMessages, messageIndex) end
        end
    end
    if #pendingUiMessages >= 64 then table.remove(pendingUiMessages, 1) end
    pendingUiMessages[#pendingUiMessages + 1] = message
end

RegisterNUICallback('uiReady', function(_, callback)
    local wasReady = uiReady
    uiReady = true
    for _, message in ipairs(pendingUiMessages) do SendNUIMessage(message) end
    pendingUiMessages = {}
    if wasReady and isOpen and lastOpenMessage then SendNUIMessage(lastOpenMessage) end
    if isOpen then SetNuiFocus(true, true) end
    callback({ ok = true })
    TriggerServerEvent('tss-inventory:requestOwn')
end)

local function copyValue(value)
    if type(value) ~= 'table' then return value end
    local copiedValue = {}
    for fieldName, fieldValue in pairs(value) do copiedValue[fieldName] = copyValue(fieldValue) end
    return copiedValue
end

local function closeInventory(shouldNotifyServer)
    if isCrafting and shouldNotifyServer ~= false then return false end
    isOpen = false
    lastOpenMessage = nil
    if TSSInventoryClient and TSSInventoryClient.Giving then TSSInventoryClient.Giving.Stop() end
    if TSSInventoryClient and TSSInventoryClient.WeaponPreview then TSSInventoryClient.WeaponPreview.Close() end
    SetNuiFocus(false, false)
    sendUiMessage({ type = 'close' })
    if shouldNotifyServer ~= false then TriggerServerEvent('tss-inventory:closeSession') end
end

local function requestOwnInventory()
    local nearbyTrunkNetworkId = TSSInventoryClient and TSSInventoryClient.NearbyTrunkNetworkId()
    TriggerServerEvent('tss-inventory:openSelf', nearbyTrunkNetworkId)
end

local function registerInventoryCommand(commandName, description, callback)
    local registered, registrationError = bridge.Commands.Register(commandName, {
        description = description,
        arguments = {},
        category = 'Inventory',
        permission = false,
        allowConsole = false,
    }, callback)
    if not registered then
        print(('[tss-inventory] Could not register /%s: %s'):format(commandName, tostring(registrationError)))
    end
end

registerInventoryCommand('inv', 'Open or close your inventory.', function()
    if isOpen then closeInventory() else requestOwnInventory() end
end)

registerInventoryCommand('inventorysettings', 'Change inventory settings or reset window positions.', function()
    TriggerServerEvent('tss-inventory:openSettings')
end)

RegisterKeyMapping('inv', 'Open inventory', 'keyboard', Config.OpenKey)

RegisterNetEvent('tss-inventory:crafting', function(craft)
    if source ~= 65535 then return end
    pendingCraftRequestId = nil
    isCrafting = type(craft) == 'table'
    sendUiMessage({ type = 'crafting', craft = craft })
end)

RegisterNetEvent('tss-inventory:attachments', function(panel)
    if source ~= 65535 then return end
    if TSSInventoryClient and TSSInventoryClient.WeaponPreview then TSSInventoryClient.WeaponPreview.Open(panel) end
    sendUiMessage({ type = 'attachments', panel = panel })
end)

RegisterNetEvent('tss-inventory:sync', function(inventories, visibleMetadata, cellSize)
    if source ~= 65535 then return end
    isOpen = true
    lastOpenMessage = { type = 'sync', inventories = inventories, visibleMetadata = visibleMetadata, cellSize = cellSize, rarity = Config.Rarity,
        weaponSystemEnabled = Config.EnableWeaponSystem == true, clothingEnabled = Config.EnableClothingSystem == true, sounds = Config.Sounds }
    sendUiMessage(lastOpenMessage)
    if uiReady then SetNuiFocus(true, true) end
end)

RegisterNetEvent('tss-inventory:close', function(onlyIfOpen)
    if source == 65535 and (onlyIfOpen ~= true or isOpen) then closeInventory(false) end
end)

local function showItemBox(definition, action, amount)
    if type(definition) ~= 'table' or (action ~= 'added' and action ~= 'removed') then return false end
    amount = amount or 1
    if type(amount) ~= 'number' or amount % 1 ~= 0 or amount < 1 or amount > 100000 then return false end
    sendUiMessage({ type = 'itemBox', definition = definition, action = action, amount = amount })
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
    bridge.Notify.Send({ title = 'Inventory', description = tostring(message), type = 'inform' })
end)

RegisterNUICallback('notify', function(request, callback)
    if type(request.message) == 'string' and #request.message > 0 and #request.message <= 1000 then
        bridge.Notify.Send({ title = 'Inventory', description = request.message, type = 'inform' })
    end
    callback({ ok = true })
end)

RegisterNetEvent('tss-inventory:result', function(requestId, succeeded, message)
    if source ~= 65535 then return end
    if pendingCraftRequestId == requestId then
        pendingCraftRequestId = nil
        if not succeeded then isCrafting = false end
    end
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
    sendUiMessage({ type = 'itemKeybinds', bindings = itemKeybinds })
    if not inventory then
        if TSSInventoryClient and TSSInventoryClient.Clothing then TSSInventoryClient.Clothing.Clear() end
        readyInventoryId = nil
    elseif inventory.id ~= readyInventoryId then
        readyInventoryId = inventory.id
        bridge.Notify.Send({ title = 'Inventory', description = 'Inventory ready', type = 'success' })
    end
    sendUiMessage({ type = 'preferences', settings = inventory and inventory.playerSettings or {}, sounds = Config.Sounds })
end)

RegisterNetEvent('tss-inventory:settings', function(settings)
    if source ~= 65535 then return end
    isOpen = true
    lastOpenMessage = { type = 'openSettings', settings = settings, sounds = Config.Sounds }
    sendUiMessage(lastOpenMessage)
    if uiReady then SetNuiFocus(true, true) end
end)

RegisterNetEvent('tss-inventory:resetLayouts', function()
    if source == 65535 then sendUiMessage({ type = 'resetLayouts' }) end
end)

RegisterNUICallback('settingsClosed', function(request, callback)
    isOpen = request.inventoryOpen == true
    SetNuiFocus(isOpen, isOpen)
    callback({ ok = true })
end)

RegisterNUICallback('useItemKey', function(request, callback)
    if TSSInventoryClient and TSSInventoryClient.FlushWeaponAmmo then TSSInventoryClient.FlushWeaponAmmo() end
    TriggerServerEvent('tss-inventory:useItemKey', request.keyCode)
    callback({ ok = true })
end)

RegisterNUICallback('close', function(_, callback)
    closeInventory()
    callback({ ok = true })
end)

RegisterNUICallback('closeInventory', function(request, callback)
    if isCrafting then return callback({ ok = false }) end
    TriggerServerEvent('tss-inventory:closeSession', request.id)
    callback({ ok = true })
end)

RegisterNUICallback('action', function(request, callback)
    if TSSInventoryClient and TSSInventoryClient.FlushWeaponAmmo then TSSInventoryClient.FlushWeaponAmmo() end
    nextRequestId = nextRequestId + 1
    local requestId = nextRequestId
    if request.kind == 'craft' then
        isCrafting = true
        pendingCraftRequestId = requestId
    end
    pendingRequests[requestId] = function(result)
        if result.ok and request.kind == 'installAttachment' and (request.slot == 'finish' or request.slot == 'tint')
            and TSSInventoryClient and TSSInventoryClient.WeaponPreview then
            TSSInventoryClient.WeaponPreview.PaintApplied(request.weaponInventoryId, request.weaponItemId, request.slot)
        end
        callback(result)
    end
    TriggerServerEvent('tss-inventory:action', requestId, request)
    SetTimeout(10000, function()
        if pendingRequests[requestId] then
            if pendingCraftRequestId == requestId then
                pendingCraftRequestId = nil
                isCrafting = false
            end
            pendingRequests[requestId] = nil
            callback({ ok = false, message = 'Server request timed out' })
        end
    end)
end)

local function hasItems(requirements, amount)
    return TSSItemExports.HasItem(TSSItemExports.CheckItems(ownInventory), requirements, amount)
end

exports('HasItem', hasItems)
exports('HasItems', hasItems)

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
                        if TSSInventoryClient and TSSInventoryClient.FlushWeaponAmmo then TSSInventoryClient.FlushWeaponAmmo() end
                        TriggerServerEvent('tss-inventory:useItemKey', keyCode)
                    end
                    pressedItemKeys[keyCode] = isDown
                end
            end
        else pressedItemKeys = {} end
        Wait(hasBindings and 0 or 200)
    end
end)
