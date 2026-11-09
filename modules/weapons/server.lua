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
        local magazine = item and TSSWeaponData.Installed(item).magazine
        TriggerClientEvent('tss-inventory:weapon', playerSource, state and {
            token = state.token, name = state.name, weapon = state.weapon,
            label = definition and definition.label, image = definition and definition.image,
            ammo = state.ammo, clipSize = state.clipSize, reloading = reloading ~= nil,
            magazineSwap = reloading == 'magazine',
            reloadDuration = Config.WeaponReloadDuration, ammoMode = state.ammoMode,
            components = state.components, tint = state.tint,
            magazineComponent = magazine and magazine.definition.weapons[item.name],
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

    function service.UnloadMagazine(playerSource, sourceInventory, itemId)
        if not TSSWeaponData.MagazineReloadEnabled() then return false, 'Magazine reloading is disabled' end
        local inventory, weapon, ownInventory = context.find(playerSource, { inventoryId = sourceInventory.id, id = itemId })
        local magazine = weapon and TSSWeaponData.LoadedMagazine(weapon)
        if not magazine or weapon.amount ~= 1 or not ownInventory then return false, 'Carry a weapon with a magazine inserted' end
        if context.locks[inventory.id] or context.locks[ownInventory.id] then return false, 'Inventory is busy' end

        local equipped = equippedWeapons[playerSource]
        local isEquipped = equipped and equipped.inventoryId == inventory.id and equipped.itemId == weapon.id
        if isEquipped and GetGameTimer() < equipped.reloadUntil then return false, 'Wait for the reload to finish' end

        local metadata = core.copy(magazine.metadata)
        local ammo = weapon.metadata.ammo
        local capacity = TSSWeaponData.ClipSize(weapon)
        metadata.rounds = core.integer(ammo, 0, capacity) and ammo or 0
        local clean, metadataError = context.metadata(metadata)
        if not clean then return false, metadataError end

        local weaponPlan = core.copy(inventory)
        local returnPlan = inventory == ownInventory and weaponPlan or core.copy(ownInventory)
        local plannedWeapon = core.find(weaponPlan, weapon.id)
        plannedWeapon.metadata.loadedMagazine = nil
        plannedWeapon.metadata.ammo = 0
        local plans = { [weaponPlan.id] = weaponPlan, [returnPlan.id] = returnPlan }
        local returned, returnError = core.add(returnPlan, magazine.name, 1, clean, nil, plans)
        if not returned then return false, returnError end

        inventory.items = weaponPlan.items
        ownInventory.items, ownInventory.nextItemId = returnPlan.items, returnPlan.nextItemId
        context.commit(inventory, ownInventory)
        if isEquipped then service.Refresh(playerSource) end
        return true
    end

    local function planMagazineFill(ammoInventory, ammo, magazineInventory, magazine, loadedRounds, rounds)
        local metadata = core.copy(magazine.metadata)
        metadata.rounds = rounds + loadedRounds
        local clean, metadataError = context.metadata(metadata)
        if not clean then return nil, metadataError end

        local ammoPlan = core.copy(ammoInventory)
        local magazinePlan = magazineInventory == ammoInventory and ammoPlan or core.copy(magazineInventory)
        local plannedMagazine = core.find(magazinePlan, magazine.id)
        core.remove(ammoPlan, ammo.id, loadedRounds)
        plannedMagazine.metadata = clean

        local plans = { [ammoPlan.id] = ammoPlan, [magazinePlan.id] = magazinePlan }
        local ingredients = { [tostring(magazine.id)] = 0 }
        local sourceIngredients
        if ammoPlan == magazinePlan then ingredients[tostring(ammo.id)] = ammo.amount - loadedRounds
        else sourceIngredients = { [tostring(ammo.id)] = ammo.amount - loadedRounds } end
        return plans, {
            inventoryId = magazineInventory.id, item = plannedMagazine, ingredients = ingredients,
            sourceInventoryId = sourceIngredients and ammoInventory.id, sourceIngredients = sourceIngredients,
            duration = Config.MagazineFillDuration, kind = 'fillMagazine',
        }
    end

    function service.FillMagazine(playerSource, sourceInventory, targetInventory, request)
        if not TSSWeaponData.MagazineReloadEnabled() then return false, 'Magazine reloading is disabled' end
        local ammoSelector = { inventoryId = sourceInventory.id, id = request.itemId }
        local magazineSelector = { inventoryId = targetInventory.id, id = request.targetItemId }
        local ammoInventory, ammo = context.find(playerSource, ammoSelector)
        local magazineInventory, magazine = context.find(playerSource, magazineSelector)
        if not ammo or not magazine then return false, 'Carry the ammunition and magazine to load it' end
        local definition = core.definition(magazine.name).magazine
        if not definition or magazine.amount ~= 1 or ammo.name ~= definition.ammoItem then
            return false, 'Ammunition does not fit this magazine'
        end
        if not core.integer(request.amount, 1, ammo.amount) then return false, 'Invalid ammunition amount' end
        local rounds = magazine.metadata.rounds
        if not core.integer(rounds, 0, definition.capacity) then rounds = 0 end
        local roundsToLoad = math.min(request.amount, definition.capacity - rounds)
        if roundsToLoad == 0 then return false, 'Magazine is full' end
        local roundsPerStep = Config.MagazineLoadingStyle == 'perBullet' and 1 or roundsToLoad

        local function stillCarried()
            local _, carriedAmmo = context.find(playerSource, ammoSelector)
            local _, carriedMagazine = context.find(playerSource, magazineSelector)
            return carriedAmmo and carriedMagazine
        end

        local function startStep()
            local currentAmmo = core.find(ammoInventory, ammoSelector.id)
            local currentMagazine = core.find(magazineInventory, magazineSelector.id)
            if not currentAmmo or not currentMagazine then return false, 'Ammunition or magazine changed' end
            local plans, preview = planMagazineFill(ammoInventory, currentAmmo, magazineInventory, currentMagazine, roundsPerStep, rounds)
            if not plans then return false, preview end
            rounds = rounds + roundsPerStep
            roundsToLoad = roundsToLoad - roundsPerStep
            preview.step = rounds
            return context.startTimedAction(playerSource, plans, preview, stillCarried, roundsToLoad > 0 and startStep or nil)
        end

        local started, startError = startStep()
        if started and equippedWeapons[playerSource] then service.Unequip(playerSource) end
        return started, startError
    end

    local function visitCarried(playerSource, visitInventory)
        local visited = {}
        local function visit(carriedInventory)
            if visited[carriedInventory.id] or context.locks[carriedInventory.id] then return false end
            visited[carriedInventory.id] = true
            if visitInventory(carriedInventory) then return true end
            for _, carriedItem in ipairs(carriedInventory.items) do
                local definition = core.definition(carriedItem.name)
                local linkedId = definition and definition.container and carriedItem.metadata.containerId
                local container = type(linkedId) == 'string' and context.load(linkedId)
                if container and container.type == definition.container
                    and container.metadata.containerItem == carriedItem.name and visit(container) then return true end
            end
            return false
        end
        for _, rootInventory in ipairs(context.roots(playerSource)) do
            if visit(rootInventory) then return end
        end
    end

    local function commitReload(playerSource, state, plans, rounds, magazineSwap)
        local changed = {}
        for inventoryId, plan in pairs(plans) do
            local live = context.load(inventoryId)
            live.items, live.nextItemId = plan.items, plan.nextItemId
            changed[#changed + 1] = live
        end
        context.commit(table.unpack(changed))
        state.ammo = rounds
        state.reloadUntil = GetGameTimer() + Config.WeaponReloadDuration
        publish(playerSource, state, magazineSwap and 'magazine' or 'loose')
        return true
    end

    local function swapMagazine(playerSource, state, inventory, weaponItem, magazineName)
        local spareInventory, spareMagazine
        local fullestRounds = 0
        visitCarried(playerSource, function(carriedInventory)
            for _, item in ipairs(carriedInventory.items) do
                local rounds = item.metadata.rounds
                if item.name == magazineName and item.amount == 1 and core.integer(rounds, 1, state.clipSize)
                    and rounds > fullestRounds then
                    spareInventory, spareMagazine, fullestRounds = carriedInventory, item, rounds
                    if rounds == state.clipSize then return true end
                end
            end
        end)
        if not spareMagazine then return false, 'No loaded magazine fits this weapon' end

        local weaponPlan = core.copy(inventory)
        local sparePlan = spareInventory == inventory and weaponPlan or core.copy(spareInventory)
        local plans = { [weaponPlan.id] = weaponPlan, [sparePlan.id] = sparePlan }
        local plannedWeapon = core.find(weaponPlan, weaponItem.id)
        local previousMagazine = TSSWeaponData.LoadedMagazine(weaponItem)
        local spareMetadata = core.copy(spareMagazine.metadata)
        spareMetadata.rounds = nil
        plannedWeapon.metadata.loadedMagazine = { name = magazineName, metadata = spareMetadata }
        plannedWeapon.metadata.ammo = fullestRounds
        local clean, metadataError = context.metadata(plannedWeapon.metadata)
        if not clean then return false, metadataError end
        plannedWeapon.metadata = clean

        core.remove(sparePlan, spareMagazine.id, 1)
        if previousMagazine then
            local returnedMetadata = core.copy(previousMagazine.metadata)
            returnedMetadata.rounds = state.ammo
            local cleanReturn, returnMetadataError = context.metadata(returnedMetadata)
            if not cleanReturn then return false, returnMetadataError end
            local returned, returnError = core.add(sparePlan, previousMagazine.name, 1, cleanReturn, nil, plans)
            if not returned then return false, returnError end
        elseif state.ammo > 0 then
            -- Guns loaded before magazine mode keep their rounds as loose ammo on their first swap.
            local returned, returnError = core.add(sparePlan, state.ammoItem, state.ammo, {}, nil, plans)
            if not returned then return false, returnError end
        else
            local weightValid, weightError = core.validatePlannedWeight(plans)
            if not weightValid then return false, weightError end
        end
        return commitReload(playerSource, state, plans, fullestRounds, true)
    end

    function service.Reload(playerSource, token, remainingAmmo)
        if not Config.EnableWeaponSystem or context.busy(playerSource) then return false, 'Inventory is busy' end
        local state = equippedWeapons[playerSource]
        if not state or state.token ~= token or not state.ammoItem or GetGameTimer() < state.reloadUntil then return false end
        if not service.Report(playerSource, token, remainingAmmo) then return false end
        local inventory, weaponItem = carriedWeapon(playerSource, state)
        if not inventory or context.locks[inventory.id] then return false, 'Weapon is unavailable' end
        local magazineName = TSSWeaponData.MagazineReloadEnabled() and TSSWeaponData.MagazineItem(weaponItem)
        if magazineName then return swapMagazine(playerSource, state, inventory, weaponItem, magazineName) end

        local missingRounds = state.clipSize - state.ammo
        if missingRounds <= 0 then return true end
        local plans, consumedRounds = {}, 0
        visitCarried(playerSource, function(carriedInventory)
            local plan = core.copy(carriedInventory)
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
            return consumedRounds >= missingRounds
        end)
        if consumedRounds == 0 then return false, 'No matching ammunition' end
        local weaponPlan = plans[inventory.id] or core.copy(inventory)
        plans[inventory.id] = weaponPlan
        local rounds = state.ammo + consumedRounds
        core.find(weaponPlan, weaponItem.id).metadata.ammo = rounds
        return commitReload(playerSource, state, plans, rounds, false)
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
