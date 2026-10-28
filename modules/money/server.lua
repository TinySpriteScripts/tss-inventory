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

    local function mirrorCash(inventory, balance)
        balance = math.floor(balance)
        if cashAmount(inventory) == math.floor(balance) then return true end
        local plannedInventory = inventoryCore.copy(inventory)
        local cashItem
        for itemIndex = #plannedInventory.items, 1, -1 do
            local item = plannedInventory.items[itemIndex]
            if item.name == 'cash' then
                if not cashItem and balance > 0 then cashItem = item
                else table.remove(plannedInventory.items, itemIndex) end
            end
        end
        if balance == 0 then
            inventory.items = plannedInventory.items
            return true
        end
        if not inventoryCore.allowed(plannedInventory, 'cash') then return false, 'Cash is not allowed in this inventory' end
        if not cashItem then
            local added, addError = inventoryCore.add(plannedInventory, 'cash', 1, {})
            if not added then return false, addError end
            for _, item in ipairs(plannedInventory.items) do if item.name == 'cash' then cashItem = item; break end end
        end
        cashItem.amount = balance
        inventory.items = plannedInventory.items
        inventory.nextItemId = plannedInventory.nextItemId
        return true
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
        local succeeded, failure = pcall(function()
            for _, inventory in ipairs(changedInventories) do
                if inventory.type == 'player' then
                    local previous = committedInventories[inventory.id]
                    local delta = reconcilingInventories[inventory.id] and 0 or cashAmount(inventory) - cashAmount(previous)
                    local playerSource = onlineOwner(inventory.id)
                    if not playerSource and delta ~= 0 then error('Cash changes require an online inventory owner') end
                    if playerSource then
                        local balance, balanceError = accountBalance(playerSource)
                        if not balance then error(balanceError) end
                        if balance + delta < 0 then error('Not enough cash') end
                        if delta ~= 0 then
                            local operation = delta > 0 and bridge.Banking.AddMoney or bridge.Banking.RemoveMoney
                            if operation(playerSource, 'cash', math.abs(delta), 'tss-inventory:cash-item') ~= true then error('Cash account change refused') end
                            receipts[#receipts + 1] = { playerSource = playerSource, inventoryId = inventory.id, delta = delta }
                        end
                        local currentBalance, currentError = accountBalance(playerSource)
                        if not currentBalance then error(currentError) end
                        if context.identity(playerSource) ~= inventory.id then error('Character changed during cash transaction') end
                        local mirrored, mirrorError = mirrorCash(inventory, currentBalance)
                        if not mirrored then error(mirrorError) end
                    end
                end
            end
        end)
        if not succeeded then moneyService.Rollback(receipts); return nil, tostring(failure) end
        return receipts
    end

    function moneyService.Reconcile(playerSource, inventory)
        if not Config.MoneyAsItem or context.locks[inventory.id] then return true end
        local balance, balanceError = accountBalance(playerSource)
        if not balance then return false, balanceError end
        if cashAmount(inventory) == math.floor(balance) then return true end
        local plannedInventory = inventoryCore.copy(inventory)
        local mirrored, mirrorError = mirrorCash(plannedInventory, balance)
        if not mirrored then return false, mirrorError end
        inventory.items = plannedInventory.items
        inventory.nextItemId = plannedInventory.nextItemId
        reconcilingInventories[inventory.id] = true
        local saved, saveError = pcall(context.commit, inventory)
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
