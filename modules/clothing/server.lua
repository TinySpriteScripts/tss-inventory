function TSSCreateClothingService(context)
    if not Config.EnableClothingSystem then return nil end
    local core = TSSCore
    local service = {}
    local lastSent = {}
    local lastGender = {}
    local equipmentName = 'clothing_equipment'
    context.extras.Register(equipmentName, { label = 'Clothing', size = { x = 4, y = 4 }, metadata = { clothingEquipment = true } })

    local function equipmentId(owner) return 'extra_' .. owner .. ':' .. equipmentName end

    local function gender(playerSource)
        local playerPed = GetPlayerPed(playerSource)
        return playerPed and playerPed ~= 0 and TSSClothingData.Gender(GetEntityModel(playerPed)) or nil
    end

    function service.View(playerSource)
        local owner = context.players[playerSource]
        local own = owner and context.load(owner)
        if not own then return nil end
        local equipment = context.load(equipmentId(own.owner))
        local inventory = equipment and core.copy(equipment) or nil
        if inventory then
            inventory.owner, inventory.settings = nil, nil
            inventory.isPlayerExtra = true
            for _, item in ipairs(inventory.items) do item.definition = core.itemDefinition(item) end
        end
        local currentGender = gender(playerSource)
        local baseline = (own.settings.clothingBaseline or {})[currentGender or '']
        return { playerInventoryId = own.id, gender = currentGender or false, inventory = inventory,
            slots = core.copy(TSSClothingSlots), baseline = core.copy(baseline) or false }
    end

    function service.Sync(playerSource, force)
        local state = service.View(playerSource)
        if not state then return end
        local signature = tostring(state.inventory and state.inventory.revision) .. ':' .. tostring(state.gender)
            .. ':' .. json.encode(state.baseline) .. ':' .. state.playerInventoryId
        if force or lastSent[playerSource] ~= signature then
            lastSent[playerSource] = signature
            lastGender[playerSource] = state.gender
            TriggerClientEvent('tss-inventory:clothing', playerSource, state)
        end
    end

    function service.Load(playerSource)
        local equipment, equipmentError = context.extras.Get(playerSource, equipmentName)
        if not equipment then return false, equipmentError end
        if context.sessions[playerSource] then context.sessions[playerSource][equipment.id] = true end
        service.Sync(playerSource, true)
        return true
    end

    function service.Tick()
        -- Character identity can load before its freemode ped is ready.
        for playerSource in pairs(context.players) do
            if (gender(playerSource) or false) ~= lastGender[playerSource] then service.Sync(playerSource) end
        end
    end

    function service.AfterCommit(changed)
        for playerSource, ownId in pairs(context.players) do
            for _, inventory in ipairs(changed) do
                if inventory.id == ownId or inventory.metadata.clothingEquipment then service.Sync(playerSource); break end
            end
        end
    end

    local function publish(plans)
        if core.validateWeights then
            local valid, weightError = core.validateWeights(plans)
            if not valid then return false, weightError end
        end
        local changed = {}
        for inventoryId, plan in pairs(plans) do
            local live = context.load(inventoryId)
            live.items, live.nextItemId, live.settings = plan.items, plan.nextItemId, plan.settings
            changed[#changed + 1] = live
        end
        context.commit(table.unpack(changed))
        return true
    end

    function service.Unequip(playerSource, slotId, expectedRevision)
        local slot = TSSClothingData.Slots[slotId]
        local own, ownError = context.player(playerSource)
        if not slot or not own then return false, ownError or 'Invalid clothing slot' end
        local equipment, equipmentError = context.extras.Get(playerSource, equipmentName)
        if not equipment then return false, equipmentError end
        if expectedRevision and equipment.revision ~= expectedRevision then return false, 'Clothing changed; try again' end
        if context.busy(playerSource) or context.locks[own.id] or context.locks[equipment.id] then return false, 'Inventory is busy' end
        local ownPlan, equipmentPlan = core.copy(own), core.copy(equipment)
        local worn
        for _, item in ipairs(equipmentPlan.items) do if item.x == slot.x and item.y == slot.y then worn = item; break end end
        if not worn then return false, 'Clothing slot is empty' end
        core.remove(equipmentPlan, worn.id, 1)
        local plans = { [own.id] = ownPlan, [equipment.id] = equipmentPlan }
        local returned, returnError = core.add(ownPlan, worn.name, 1, worn.metadata, worn.rotated, plans)
        if not returned then return false, returnError end
        return publish(plans)
    end

    function service.Equip(playerSource, sourceInventory, itemId, slotId, expectedRevision)
        if context.busy(playerSource) then return false, 'Inventory is busy' end
        local carried, item = context.find(playerSource, { inventoryId = sourceInventory.id, id = itemId })
        if not carried or not item or item.amount ~= 1 or not context.canUse(playerSource, carried) then return false, 'Clothing is not carried' end
        local variation, variationError = TSSClothingData.Validate(item)
        if not variation or (slotId and slotId ~= variation.slot) then return false, variationError or 'Clothing does not fit this slot' end
        local currentGender = gender(playerSource)
        if not currentGender then return false, 'Clothing requires a male or female freemode character' end
        if variation.gender ~= currentGender then return false, 'Clothing is for a different gender' end
        local own, ownError = context.player(playerSource)
        if not own then return false, ownError end
        local equipment, equipmentError = context.extras.Get(playerSource, equipmentName)
        if not equipment then return false, equipmentError end
        if expectedRevision and equipment.revision ~= expectedRevision then return false, 'Clothing changed; try again' end
        if carried.id == equipment.id then return service.Unequip(playerSource, variation.slot, expectedRevision) end
        if context.locks[own.id] or context.locks[carried.id] or context.locks[equipment.id] then return false, 'Inventory is busy' end
        local plans = { [own.id] = core.copy(own), [equipment.id] = core.copy(equipment) }
        plans[carried.id] = plans[carried.id] or core.copy(carried)
        local equipmentPlan = plans[equipment.id]
        local slot = TSSClothingData.Slots[variation.slot]
        local previous
        for _, candidate in ipairs(equipmentPlan.items) do
            if candidate.x == slot.x and candidate.y == slot.y then previous = candidate; break end
        end
        local wasEmpty = #equipmentPlan.items == 0
        if previous then core.remove(equipmentPlan, previous.id, 1) end
        core.remove(plans[carried.id], item.id, 1)
        local equipped = core.copy(item)
        equipped.id, equipped.x, equipped.y, equipped.rotated = equipmentPlan.nextItemId, slot.x, slot.y, false
        equipmentPlan.nextItemId = equipmentPlan.nextItemId + 1
        if not core.fits(equipmentPlan, equipped, slot.x, slot.y) then return false, 'Clothing does not fit this slot' end
        equipmentPlan.items[#equipmentPlan.items + 1] = equipped
        if previous then
            local returned, returnError = core.add(plans[own.id], previous.name, 1, previous.metadata, previous.rotated, plans)
            if not returned then return false, returnError end
        end
        if wasEmpty then
            plans[own.id].settings.clothingBaseline = core.copy(plans[own.id].settings.clothingBaseline or {})
            plans[own.id].settings.clothingBaseline[currentGender] = nil
        end
        return publish(plans)
    end

    function service.Use(playerSource, inventory, item)
        return service.Equip(playerSource, inventory, item.id)
    end

    function service.SaveBaseline(playerSource, playerInventoryId, baseline)
        local own, ownError = context.player(playerSource)
        if not own or own.id ~= playerInventoryId then return false, ownError or 'Character changed' end
        if type(baseline) ~= 'table' or baseline.gender ~= gender(playerSource) then return false, 'Invalid clothing baseline' end
        local equipment = context.load(equipmentId(own.owner))
        if not equipment or #equipment.items == 0 then return false, 'No equipped clothing' end
        if (own.settings.clothingBaseline or {})[baseline.gender] then return true end
        local cleaned = { gender = baseline.gender, components = {}, props = {} }
        for fieldName, allowed in pairs({ components = TSSClothingData.ComponentIds, props = TSSClothingData.PropIds }) do
            if type(baseline[fieldName]) ~= 'table' then return false, 'Invalid clothing baseline' end
            for componentId in pairs(allowed) do
                local key = tostring(componentId)
                local variation = TSSClothingData.Variation(baseline[fieldName][key], fieldName == 'props')
                if not variation then return false, 'Invalid clothing baseline' end
                cleaned[fieldName][key] = variation
            end
        end
        own.settings.clothingBaseline = own.settings.clothingBaseline or {}
        own.settings.clothingBaseline[baseline.gender] = cleaned
        context.commit(own)
        return true
    end

    function service.Clear(playerSource)
        lastSent[playerSource], lastGender[playerSource] = nil, nil
        TriggerClientEvent('tss-inventory:clothing', playerSource, false)
    end

    return service
end
