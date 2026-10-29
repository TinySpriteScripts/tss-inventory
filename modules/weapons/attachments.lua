-- Attachment ownership and compatibility are resolved from server definitions only.
function TSSCreateAttachmentService(context)
    local core = TSSCore
    local viewers = {}
    local service = {}

    local function findWeapon(playerSource, inventoryId, itemId)
        local inventory, item = context.find(playerSource, { inventoryId = inventoryId, id = itemId })
        local definition = item and core.definition(item.name)
        if not Config.EnableWeaponSystem or not definition or not definition.weapon or item.amount ~= 1 then return nil end
        return inventory, item
    end

    local function panelData(inventory, weapon)
        local slots = {}
        local installed = TSSWeaponData.Installed(weapon)
        for _, slot in ipairs(TSSWeaponData.Slots) do
            local compatibleItems = {}
            for itemName, attachment in pairs(TSSAttachmentDefinitions) do
                if attachment.slot == slot.id and TSSWeaponData.Attachment(weapon.name, itemName) then
                    compatibleItems[#compatibleItems + 1] = itemName
                end
            end
            table.sort(compatibleItems)
            if #compatibleItems > 0 then
                local record = installed[slot.id] and installed[slot.id].record
                slots[#slots + 1] = { id = slot.id, label = slot.label, compatibleItems = compatibleItems,
                    installed = record and { name = record.name, amount = 1, metadata = core.copy(record.metadata or {}),
                        definition = core.itemDefinition({ name = record.name, metadata = record.metadata or {} }) } or false }
            end
        end
        local view = core.copy(weapon)
        view.definition = core.itemDefinition(weapon)
        return { inventoryId = inventory.id, itemId = weapon.id, revision = inventory.revision, weapon = view, slots = slots }
    end

    function service.Open(playerSource, sourceInventory, itemId)
        if not Config.EnableWeaponSystem then return false, 'Weapon attachment system is disabled' end
        if context.busy(playerSource) then return false, 'Inventory is busy' end
        local inventory, weapon = findWeapon(playerSource, sourceInventory.id, itemId)
        if not weapon then return false, 'Carry the weapon before editing attachments' end
        viewers[playerSource] = { inventoryId = inventory.id, itemId = weapon.id }
        local panel = panelData(inventory, weapon)
        panel.open = true
        TriggerClientEvent('tss-inventory:attachments', playerSource, panel)
        return true
    end

    function service.Close(playerSource)
        viewers[playerSource] = nil
        TriggerClientEvent('tss-inventory:attachments', playerSource, false)
        return true
    end

    function service.RefreshViews()
        for playerSource, view in pairs(viewers) do
            local inventory, weapon
            if context.isOpen(playerSource) then inventory, weapon = findWeapon(playerSource, view.inventoryId, view.itemId) end
            if weapon then TriggerClientEvent('tss-inventory:attachments', playerSource, panelData(inventory, weapon))
            else service.Close(playerSource) end
        end
    end

    local function changeAttachment(playerSource, request, sourceInventory, sourceItem)
        if context.busy(playerSource) then return false, 'Inventory is busy' end
        local view = viewers[playerSource]
        if not view or request.weaponInventoryId ~= view.inventoryId or request.weaponItemId ~= view.itemId then
            return false, 'Open the weapon attachment window first'
        end
        local inventory, weapon = findWeapon(playerSource, view.inventoryId, view.itemId)
        if not weapon or request.weaponRevision ~= inventory.revision then
            service.RefreshViews()
            return false, 'Weapon changed; try again'
        end
        if context.locks[inventory.id] or (sourceInventory and context.locks[sourceInventory.id]) then return false, 'Inventory is busy' end
        local attachment = sourceItem and TSSWeaponData.Attachment(weapon.name, sourceItem.name)
        if sourceItem and (not attachment or attachment.slot ~= request.slot) then return false, 'Attachment does not fit this slot' end
        local existing = TSSWeaponData.Installed(weapon)[request.slot]
        if not sourceItem and not existing then return false, 'This slot is empty' end

        local plans = {}
        local function plan(live)
            if not plans[live.id] then plans[live.id] = core.copy(live) end
            return plans[live.id]
        end
        local weaponPlan = plan(inventory)
        local plannedWeapon = core.find(weaponPlan, weapon.id)
        plannedWeapon.metadata.attachments = plannedWeapon.metadata.attachments or {}
        if type(plannedWeapon.metadata.attachments) ~= 'table' then return false, 'Invalid saved attachments' end
        local destination = sourceInventory or context.player(playerSource)
        if not destination or context.locks[destination.id] then return false, 'Inventory is busy' end
        local returnPlan = plan(destination)
        if sourceItem then
            local removed, removeError = core.remove(plan(sourceInventory), sourceItem.id, 1)
            if not removed then return false, removeError end
            plannedWeapon.metadata.attachments[request.slot] = { name = sourceItem.name, metadata = core.copy(sourceItem.metadata) }
        else plannedWeapon.metadata.attachments[request.slot] = nil end
        if existing then
            local returnedMetadata, metadataError = context.metadata(existing.record.metadata or {})
            if not returnedMetadata then return false, metadataError end
            local returned, returnError = core.add(returnPlan, existing.record.name, 1, returnedMetadata, nil, plans)
            if not returned then return false, returnError end
        end
        plannedWeapon = core.find(weaponPlan, weapon.id)
        local capacity = TSSWeaponData.ClipSize(plannedWeapon)
        local ammo = tonumber(plannedWeapon.metadata.ammo) or 0
        if ammo > capacity then
            local definition = core.definition(plannedWeapon.name)
            if not definition.ammoItem then return false, 'Unload the weapon before removing this magazine' end
            plannedWeapon.metadata.ammo = capacity
            local returned, returnError = core.add(returnPlan, definition.ammoItem, ammo - capacity, {}, nil, plans)
            if not returned then return false, returnError end
        end
        plannedWeapon = core.find(weaponPlan, weapon.id)
        local metadata, metadataError = context.metadata(plannedWeapon.metadata)
        if not metadata then return false, metadataError end
        plannedWeapon.metadata = metadata
        local changed = {}
        for inventoryId, planned in pairs(plans) do
            local live = context.load(inventoryId)
            live.items, live.nextItemId = planned.items, planned.nextItemId
            changed[#changed + 1] = live
        end
        context.commit(table.unpack(changed))
        context.refreshEquipment(playerSource)
        return true
    end

    function service.Install(playerSource, sourceInventory, request)
        local carriedInventory, sourceItem = context.find(playerSource, { inventoryId = sourceInventory.id, id = request.itemId })
        if not carriedInventory or not sourceItem then return false, 'Carry the attachment before installing it' end
        return changeAttachment(playerSource, request, carriedInventory, sourceItem)
    end

    function service.Remove(playerSource, request)
        return changeAttachment(playerSource, request)
    end

    return service
end
