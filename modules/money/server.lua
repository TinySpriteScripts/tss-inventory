-- The cash account is authoritative on load; inventory transactions apply only their cash delta.
function TSSCreateMoneyService(context)
    local inventoryCore = TSSCore
    local moneyService = {}
    local reconcilingInventories = {}
    local bridge
    if Config.MoneyAsItem then
        bridge = exports.tss_bridge:GetModules({ 'Banking', 'Framework' }, Config.TSS)
    end

    local function cashAmount(inventory)
        local amount = 0
        for _, item in ipairs(inventory and inventory.items or {}) do
            if item.name == 'cash' then amount = amount + item.amount end
        end
        return amount
    end

    local function onlineOwner(inventoryId)
        for playerSource, ownedInventoryId in pairs(context.players) do
            if ownedInventoryId == inventoryId and GetPlayerName(playerSource)
                and context.identity(playerSource) == inventoryId then return playerSource end
        end
    end

    local function accountBalance(playerSource)
        if not bridge.Framework.System() then return nil, 'Cash account is unavailable' end
        local balance = bridge.Banking.GetAccount(playerSource, 'cash')
        if type(balance) ~= 'number' or balance ~= balance or balance < 0 or balance > 2147483647 then
            return nil, 'Cash balance is unavailable or outside the supported range'
        end
        return balance
    end

    -- Only server-owned item links attach storage to a player's spendable cash tree.
    local function carriedInventories(rootInventory, resolveInventory)
        local carried, visited = {}, {}
        local function visit(inventory)
            if not inventory or visited[inventory.id] then return end
            visited[inventory.id] = true
            carried[#carried + 1] = inventory
            for _, item in ipairs(inventory.items) do
                local definition = inventoryCore.definition(item.name)
                local containerId = definition and definition.container and item.metadata and item.metadata.containerId
                local container = type(containerId) == 'string' and resolveInventory(containerId)
                if container and container.type == definition.container
                    and container.metadata.containerItem == item.name then visit(container) end
            end
        end
        visit(rootInventory)
        for _, extraInventory in ipairs(context.extraRoots(rootInventory)) do
            visit(resolveInventory(extraInventory.id))
        end
        return carried
    end

    local function carriedCash(carried)
        local total = 0
        for _, inventory in ipairs(carried) do total = total + cashAmount(inventory) end
        return total
    end

    local function planBalance(carried, balance, plannedInventories)
        local difference = math.floor(balance) - carriedCash(carried)
        if difference == 0 then return true end
        local function planned(inventory)
            if not plannedInventories[inventory.id] then
                plannedInventories[inventory.id] = inventoryCore.copy(inventory)
            end
            return plannedInventories[inventory.id]
        end
        if difference < 0 then
            local remaining = -difference
            for _, inventory in ipairs(carried) do
                if cashAmount(inventory) > 0 then
                    local updated = planned(inventory)
                    for itemIndex = #updated.items, 1, -1 do
                        local item = updated.items[itemIndex]
                        if item.name == 'cash' then
                            local removed = math.min(remaining, item.amount)
                            inventoryCore.remove(updated, item.id, removed)
                            remaining = remaining - removed
                            if remaining == 0 then return true end
                        end
                    end
                end
            end
            return false, 'Not enough carried cash'
        end

        -- Keep cash where it already lives; only use a free slot when no cash stack exists.
        for _, inventory in ipairs(carried) do
            for _, item in ipairs(inventory.items) do
                if item.name == 'cash' and item.amount + difference <= 2147483647 then
                    local updated = planned(inventory)
                    inventoryCore.find(updated, item.id).amount = item.amount + difference
                    return true
                end
            end
        end
        for _, inventory in ipairs(carried) do
            local updated = inventoryCore.copy(inventory)
            local added = inventoryCore.add(updated, 'cash', 1, {})
            if added then
                local cashItem
                for _, item in ipairs(updated.items) do if item.name == 'cash' then cashItem = item; break end end
                cashItem.amount = difference
                plannedInventories[inventory.id] = updated
                return true
            end
        end
        return false, 'Not enough carried grid space for cash'
    end

    local function applyPlans(plans, changedInventories, increaseRevision)
        local included = {}
        for _, inventory in ipairs(changedInventories) do included[inventory.id] = true end
        for inventoryId, plan in pairs(plans) do
            local liveInventory = context.load(inventoryId)
            if liveInventory and not inventoryCore.equal(liveInventory.items, plan.items) then
                if not included[inventoryId] then
                    if increaseRevision then liveInventory.revision = liveInventory.revision + 1 end
                    changedInventories[#changedInventories + 1] = liveInventory
                    included[inventoryId] = true
                end
                liveInventory.items = plan.items
                liveInventory.nextItemId = plan.nextItemId
            end
        end
    end

    function moneyService.Rollback(receipts)
        for receiptIndex = #(receipts or {}), 1, -1 do
            local receipt = receipts[receiptIndex]
            local restored = false
            if context.identity(receipt.playerSource) == receipt.inventoryId then
                local operation = receipt.delta > 0 and bridge.Banking.RemoveMoney or bridge.Banking.AddMoney
                local called, result = pcall(operation, receipt.playerSource, 'cash', math.abs(receipt.delta), 'tss-inventory:cash-rollback')
                restored = called and result == true
            end
            if not restored then
                print(('[tss-inventory] CASH RECOVERY REQUIRED inventory=%s delta=%s'):format(receipt.inventoryId, receipt.delta))
            end
        end
    end

    function moneyService.Prepare(changedInventories, committedInventories)
        local receipts = {}
        if not Config.MoneyAsItem then return receipts end
        local changedById, plannedInventories = {}, {}
        for _, inventory in ipairs(changedInventories) do changedById[inventory.id] = inventory end
        local function previousInventory(inventoryId)
            if changedById[inventoryId] then return committedInventories[inventoryId] end
            return committedInventories[inventoryId] or context.load(inventoryId)
        end
        local function currentInventory(inventoryId)
            return plannedInventories[inventoryId] or changedById[inventoryId] or context.load(inventoryId)
        end
        local succeeded, failure = pcall(function()
            for _, inventory in ipairs(changedInventories) do
                if inventory.type == 'player' and not onlineOwner(inventory.id)
                    and cashAmount(inventory) ~= cashAmount(committedInventories[inventory.id]) then
                    error('Cash changes require an online inventory owner')
                end
            end
            for playerSource, rootId in pairs(context.players) do
                if GetPlayerName(playerSource) and context.identity(playerSource) == rootId then
                    local rootInventory = currentInventory(rootId)
                    if rootInventory then
                        local previousRoot = previousInventory(rootId)
                        local previousCarried = previousRoot and carriedInventories(previousRoot, previousInventory) or {}
                        local currentCarried = carriedInventories(rootInventory, currentInventory)
                        local affected = false
                        for _, inventory in ipairs(previousCarried) do if changedById[inventory.id] then affected = true end end
                        for _, inventory in ipairs(currentCarried) do if changedById[inventory.id] then affected = true end end
                        if affected then
                            local delta = reconcilingInventories[rootId] and 0 or carriedCash(currentCarried) - carriedCash(previousCarried)
                            local balance, balanceError = accountBalance(playerSource)
                            if not balance then error(balanceError) end
                            if balance + delta < 0 then error('Not enough cash') end
                            if delta ~= 0 then
                                local operation = delta > 0 and bridge.Banking.AddMoney or bridge.Banking.RemoveMoney
                                if operation(playerSource, 'cash', math.abs(delta), 'tss-inventory:cash-item') ~= true then error('Cash account change refused') end
                                receipts[#receipts + 1] = { playerSource = playerSource, inventoryId = rootId, delta = delta }
                            end
                            local currentBalance, currentError = accountBalance(playerSource)
                            if not currentBalance then error(currentError) end
                            if context.identity(playerSource) ~= rootId then error('Character changed during cash transaction') end
                            local mirrored, mirrorError = planBalance(currentCarried, currentBalance, plannedInventories)
                            if not mirrored then error(mirrorError) end
                        end
                    end
                end
            end
            applyPlans(plannedInventories, changedInventories, true)
        end)
        if not succeeded then moneyService.Rollback(receipts); return nil, tostring(failure) end
        return receipts
    end

    function moneyService.Reconcile(playerSource, inventory)
        if not Config.MoneyAsItem then return true end
        local carried = carriedInventories(inventory, context.load)
        for _, carriedInventory in ipairs(carried) do
            if context.locks[carriedInventory.id] then return true end
        end
        local balance, balanceError = accountBalance(playerSource)
        if not balance then return false, balanceError end
        if carriedCash(carried) == math.floor(balance) then return true end
        local plans, changedInventories = {}, {}
        local mirrored, mirrorError = planBalance(carried, balance, plans)
        if not mirrored then return false, mirrorError end
        applyPlans(plans, changedInventories, false)
        reconcilingInventories[inventory.id] = true
        local saved, saveError = pcall(context.commit, table.unpack(changedInventories))
        reconcilingInventories[inventory.id] = nil
        if not saved then return false, tostring(saveError) end
        return true
    end

    function moneyService.Tick()
        if not Config.MoneyAsItem then return end
        for playerSource, inventoryId in pairs(context.players) do
            if GetPlayerName(playerSource) and context.identity(playerSource) == inventoryId then
                local inventory = context.load(inventoryId)
                if inventory then moneyService.Reconcile(playerSource, inventory) end
            end
        end
    end

    return moneyService
end
