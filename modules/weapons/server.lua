-- Server-owned equipment sessions. Ammo reports may decrease loaded ammo, never create it.
function TSSCreateWeaponService(context)
    local core = TSSCore
    local equippedWeapons = {}
    local nextToken = 0
    local service = {}

    function service.IsWeapon(item)
        local definition = item and core.definition(item.name)
        return Config.EnableWeaponSystem == true and definition
            and type(definition.weapon) == 'string' and definition.weapon:match('^weapon_') ~= nil
    end

    local function carriedWeapon(playerSource, state)
        local inventory, item = context.find(playerSource, { inventoryId = state.inventoryId, id = state.itemId })
        if not item or item.name ~= state.name or not service.IsWeapon(item) then return nil end
        return inventory, item
    end

    local function publish(playerSource, state, reloading)
        local _, item
        if state then _, item = carriedWeapon(playerSource, state) end
        local definition = item and core.itemDefinition(item)
        TriggerClientEvent('tss-inventory:weapon', playerSource, state and {
            token = state.token, name = state.name, weapon = state.weapon,
            label = definition and definition.label, image = definition and definition.image,
            ammo = state.ammo, clipSize = state.clipSize, reloading = reloading == true,
            reloadDuration = Config.WeaponReloadDuration, ammoMode = state.ammoMode,
            components = state.components, tint = state.tint,
        } or false)
    end

    local function reduceDurability(item, shotCount)
        local definition = core.definition(item.name)
        local durability = item.metadata.durability
        if not core.integer(durability, 0, 100) then
            durability = definition.metadata.durability or 100
        end
        item.metadata.durability = math.max(0, durability - shotCount)
    end

    function service.Unequip(playerSource)
        if not Config.EnableWeaponSystem then return false end
        equippedWeapons[playerSource] = nil
        publish(playerSource, nil)
        return true
    end

    function service.Use(playerSource, inventory, item)
        if not service.IsWeapon(item) or context.busy(playerSource) then return false, 'Weapon cannot be used' end
        local carriedInventory, carriedItem = context.find(playerSource, { inventoryId = inventory.id, id = item.id })
        if not carriedItem or carriedItem.name ~= item.name or carriedItem.amount ~= 1 then return false, 'Weapon is not carried' end
        local previous = equippedWeapons[playerSource]
        if previous and previous.inventoryId == inventory.id and previous.itemId == item.id then
            return true, nil, function()
                if core.definition(item.name).shouldClose then context.close(playerSource) end
                service.Unequip(playerSource)
            end
        end
        local definition = core.definition(item.name)
        if definition.useable == false then return false, 'Weapon cannot be used' end
        if definition.ammoMode == 'unarmed' then
            return true, nil, function() context.close(playerSource); service.Unequip(playerSource) end
        end
        local clipSize = TSSWeaponData.ClipSize(item)
        if not core.integer(clipSize, 0, 10000) then return false, 'Invalid weapon clip size' end
        local ammo = item.metadata.ammo
        if ammo == nil then ammo = definition.initialAmmo or 0 end
        if not core.integer(ammo, 0, clipSize) then ammo = 0 end
        if item.metadata.ammo ~= ammo or item.metadata.durability == nil then
            item.metadata.ammo = ammo
            if item.metadata.durability == nil then item.metadata.durability = definition.metadata.durability or 100 end
            context.commit(carriedInventory)
        end
        nextToken = nextToken + 1
        local state = { token = nextToken, inventoryId = inventory.id, itemId = item.id,
            name = item.name, weapon = definition.weapon, ammoItem = definition.ammoItem,
            ammo = ammo, clipSize = clipSize, reloadUntil = 0, ammoMode = definition.ammoMode }
        state.components, state.tint = TSSWeaponData.Components(item)
        return true, nil, function()
            -- Re-check after any deferred callback boundary.
            if not carriedWeapon(playerSource, state) then return end
            if definition.shouldClose then context.close(playerSource) end
            equippedWeapons[playerSource] = state
            publish(playerSource, state)
        end
    end

    function service.Report(playerSource, token, remainingAmmo)
        local state = equippedWeapons[playerSource]
        if not state or state.token ~= token or GetGameTimer() < state.reloadUntil
            or not core.integer(remainingAmmo, 0, state.ammo) then return false end
        local inventory, item = carriedWeapon(playerSource, state)
        if not inventory then return service.Unequip(playerSource) end
        if context.locks[inventory.id] then return false end
        if remainingAmmo == state.ammo then return true end
        local previousAmmo = state.ammo
        if state.ammoMode == 'throwable' and remainingAmmo == 0 then
            core.remove(inventory, item.id, 1)
        else
            item.metadata.ammo = remainingAmmo
            if state.ammoMode == 'firearm' then reduceDurability(item, previousAmmo - remainingAmmo) end
        end
        local saved, saveError = pcall(context.commit, inventory)
        if not saved then state.ammo = previousAmmo; error(saveError) end
        state.ammo = remainingAmmo
        return true
    end

    function service.Shot(playerSource, token)
        local state = equippedWeapons[playerSource]
        local currentTime = GetGameTimer()
        if not state or state.token ~= token or state.ammoMode ~= 'rechargeable'
            or currentTime < state.reloadUntil or currentTime < (state.nextShotTime or 0) then return false end
        local inventory, item = carriedWeapon(playerSource, state)
        if not inventory then return service.Unequip(playerSource) end
        if context.locks[inventory.id] then return false end
        reduceDurability(item, 1)
        context.commit(inventory)
        state.nextShotTime = currentTime + 200
        return true
    end

    function service.Reload(playerSource, token, remainingAmmo)
        if not Config.EnableWeaponSystem or context.busy(playerSource) then return false, 'Inventory is busy' end
        local state = equippedWeapons[playerSource]
        if not state or state.token ~= token or not state.ammoItem or GetGameTimer() < state.reloadUntil then return false end
        if not service.Report(playerSource, token, remainingAmmo) then return false end
        local inventory, weaponItem = carriedWeapon(playerSource, state)
        if not inventory or context.locks[inventory.id] then return false, 'Weapon is unavailable' end
        local missingRounds = state.clipSize - state.ammo
        if missingRounds <= 0 then return true end
        local plans, consumedRounds = {}, 0
        local visited = {}
        local function consumeFrom(carriedInventory)
            if not carriedInventory or visited[carriedInventory.id] or consumedRounds >= missingRounds then return end
            visited[carriedInventory.id] = true
            if context.locks[carriedInventory.id] then return end
            local plan = plans[carriedInventory.id] or core.copy(carriedInventory)
            local changed = false
            for itemIndex = #plan.items, 1, -1 do
                local ammoItem = plan.items[itemIndex]
                if ammoItem.name == state.ammoItem and consumedRounds < missingRounds then
                    local amount = math.min(missingRounds - consumedRounds, ammoItem.amount)
                    core.remove(plan, ammoItem.id, amount)
                    consumedRounds = consumedRounds + amount
                    changed = true
                end
            end
            if changed then plans[carriedInventory.id] = plan end
            for _, carriedItem in ipairs(plan.items) do
                local definition = core.definition(carriedItem.name)
                local linkedId = definition and definition.container and carriedItem.metadata.containerId
                local container = linkedId and context.load(linkedId)
                if container and container.type == definition.container
                    and container.metadata.containerItem == carriedItem.name then consumeFrom(container) end
            end
        end
        for _, rootInventory in ipairs(context.roots(playerSource)) do consumeFrom(rootInventory) end
        if consumedRounds == 0 then return false, 'No matching ammunition' end
        local weaponPlan = plans[inventory.id] or core.copy(inventory)
        plans[inventory.id] = weaponPlan
        core.find(weaponPlan, weaponItem.id).metadata.ammo = state.ammo + consumedRounds
        local changed = {}
        for inventoryId, plan in pairs(plans) do
            local live = context.load(inventoryId)
            live.items = plan.items
            live.nextItemId = plan.nextItemId
            changed[#changed + 1] = live
        end
        context.commit(table.unpack(changed))
        state.ammo = state.ammo + consumedRounds
        state.reloadUntil = GetGameTimer() + Config.WeaponReloadDuration
        publish(playerSource, state, true)
        return true
    end

    function service.Refresh(playerSource)
        local state = equippedWeapons[playerSource]
        if not state then return end
        local inventory, item = carriedWeapon(playerSource, state)
        if not inventory then return service.Unequip(playerSource) end
        state.clipSize = TSSWeaponData.ClipSize(item)
        state.ammo = math.min(tonumber(item.metadata.ammo) or 0, state.clipSize)
        state.components, state.tint = TSSWeaponData.Components(item)
        publish(playerSource, state)
    end

    function service.RevokeInvalid()
        for playerSource, state in pairs(equippedWeapons) do
            if not carriedWeapon(playerSource, state) then service.Unequip(playerSource) end
        end
    end

    function service.Get(playerSource)
        return equippedWeapons[playerSource] and core.copy(equippedWeapons[playerSource]) or nil
    end

    return service
end
