-- Shop catalogues are read-only. Trades use server prices and validated carried items.
function TSSCreateShopService(inventoryContext)
    local inventoryCore = TSSCore
    local bridge = exports.tss_bridge:GetModules({ 'Banking', 'Framework' })
    local registeredShops = {}
    local shopService = {}

    local function isFiniteNumber(value)
        return type(value) == 'number' and value == value and math.abs(value) < 1e12
    end

    local function isPlayerNearby(playerSource, shop)
        if not inventoryCore.integer(playerSource, 1, 65535) or not GetPlayerName(playerSource) then
            return false
        end

        local playerPed = GetPlayerPed(playerSource)
        if not playerPed or playerPed == 0 or GetPlayerRoutingBucket(playerSource) ~= shop.bucket then
            return false
        end

        local playerPosition = GetEntityCoords(playerPed)
        local shopPosition = shop.coords
        local distanceSquared = (playerPosition.x - shopPosition.x) ^ 2
            + (playerPosition.y - shopPosition.y) ^ 2
            + (playerPosition.z - shopPosition.z) ^ 2

        return distanceSquared <= shop.distance ^ 2
    end

    function shopService.Register(shopId, shopDefinition)
        if type(shopId) ~= 'string' or #shopId == 0 or #shopId > 100 or type(shopDefinition) ~= 'table' then
            return false, 'Invalid shop'
        end

        local coordinates = shopDefinition.coords
        local coordinateType = type(coordinates)
        local validCoordinateType = coordinateType == 'table' or coordinateType == 'vector3' or coordinateType == 'vector4'

        if not validCoordinateType or not isFiniteNumber(coordinates.x)
            or not isFiniteNumber(coordinates.y) or not isFiniteNumber(coordinates.z)
            or type(shopDefinition.size) ~= 'table'
            or not inventoryCore.integer(shopDefinition.size.x, 1, Config.MaxDimension) then
            return false, 'Shop needs coordinates and valid grid size'
        end

        if shopDefinition.label and (type(shopDefinition.label) ~= 'string' or #shopDefinition.label > 100) then
            return false, 'Invalid shop label'
        end

        if shopDefinition.bucket ~= nil and not inventoryCore.integer(shopDefinition.bucket, 0, 1000000000) then
            return false, 'Invalid shop bucket'
        end

        if type(shopDefinition.stock) ~= 'table' then
            return false, 'Shop stock must be a table'
        end

        local interactionDistance = shopDefinition.distance or 3
        if not isFiniteNumber(interactionDistance) or interactionDistance <= 0 or interactionDistance > 10 then
            return false, 'Invalid shop distance'
        end

        if shopDefinition.groups then
            return false, 'Shop groups are not supported; configure access in the calling server resource'
        end

        if shopDefinition.account and shopDefinition.account ~= 'cash' and shopDefinition.account ~= 'bank' then
            return false, 'Unsupported payment account'
        end

        for _, fieldName in ipairs({ 'buy', 'sell' }) do
            if shopDefinition[fieldName] ~= nil and type(shopDefinition[fieldName]) ~= 'boolean' then return false, 'Invalid shop trade toggle' end
        end

        local inventoryId = 'shop:' .. shopId
        if inventoryContext.locks[inventoryId] then
            return false, 'Shop is busy'
        end

        local previousInventory, loadError = inventoryContext.load(inventoryId)
        if loadError then return false, loadError end
        if previousInventory and previousInventory.type ~= 'shop' then
            return false, 'Shop ID conflicts with an existing inventory'
        end

        local shopInventory = {
            id = inventoryId,
            type = 'shop',
            last_updated = previousInventory and previousInventory.last_updated,
            whitelist = {},
            blacklist = {},
            shopId = shopId,
            label = shopDefinition.label or shopId,
            size = { x = shopDefinition.size.x, y = 2 },
            metadata = previousInventory and inventoryCore.copy(previousInventory.metadata) or {},
            settings = previousInventory and inventoryCore.copy(previousInventory.settings) or {},
            coords = { x = coordinates.x, y = coordinates.y, z = coordinates.z },
            items = {},
            nextItemId = 1,
            revision = previousInventory and previousInventory.revision or 0,
            account = shopDefinition.account or 'cash',
        }

        if not inventoryCore.size(shopInventory.size) then return false, 'Invalid shop width' end

        local itemNames = {}
        for itemName in pairs(shopDefinition.stock) do
            if type(itemName) ~= 'string' then return false, 'Invalid shop item name' end
            itemNames[#itemNames + 1] = itemName
        end

        table.sort(itemNames)
        if #itemNames == 0 then return false, 'Shop must have stock' end

        for _, itemName in ipairs(itemNames) do
            local stockDefinition = shopDefinition.stock[itemName]
            local itemDefinition = inventoryCore.definition(itemName)
            if not itemDefinition or type(stockDefinition) ~= 'table' then return false, 'Invalid shop item: ' .. itemName end
            local buyPrice = stockDefinition.buyPrice
            if buyPrice == nil then buyPrice = stockDefinition.price end
            local sellPrice = stockDefinition.sellPrice
            local canBuy = shopDefinition.buy ~= false and stockDefinition.buy ~= false and buyPrice ~= nil
            local canSell = shopDefinition.sell ~= false and stockDefinition.sell ~= false and sellPrice ~= nil
            for _, fieldName in ipairs({ 'buy', 'sell' }) do
                if stockDefinition[fieldName] ~= nil and type(stockDefinition[fieldName]) ~= 'boolean' then return false, 'Invalid product trade toggle' end
            end
            if buyPrice ~= nil and not inventoryCore.integer(buyPrice, 0, 100000000)
                or sellPrice ~= nil and not inventoryCore.integer(sellPrice, 0, 100000000) then
                return false, 'Invalid shop item/price: ' .. itemName
            end

            if canBuy or canSell then
                local remainingStock = stockDefinition.amount
                if remainingStock == nil then remainingStock = false end
                if remainingStock ~= false and not inventoryCore.integer(remainingStock, 0, 100000000) then
                    return false, 'Invalid stock amount'
                end

                local previousLabel
                if previousInventory then
                    for _, previousItem in ipairs(previousInventory.items) do
                        if previousItem.name == itemName then
                            previousLabel = previousItem.metadata.label
                            if previousItem.stock ~= false and remainingStock ~= false then remainingStock = previousItem.stock end
                        end
                    end
                end

                local itemMetadata, metadataError = inventoryContext.metadata(stockDefinition.metadata or itemDefinition.metadata)
                if not itemMetadata then return false, metadataError end
                if previousLabel then itemMetadata.label = previousLabel end

                local shopItem = {
                    id = shopInventory.nextItemId,
                    name = itemName,
                    amount = 1,
                    metadata = itemMetadata,
                    price = buyPrice,
                    buyPrice = buyPrice, sellPrice = sellPrice, canBuy = canBuy, canSell = canSell,
                    stock = remainingStock,
                }

                local itemColumn, itemRow = inventoryCore.space(shopInventory, shopItem)
                while not itemColumn do
                    local expandedSize = { x = shopInventory.size.x, y = shopInventory.size.y + 1 }
                    if not inventoryCore.size(expandedSize) then return false, 'Shop catalogue exceeds configured grid limits' end
                    shopInventory.size = expandedSize
                    itemColumn, itemRow = inventoryCore.space(shopInventory, shopItem)
                end

                shopItem.x = itemColumn
                shopItem.y = itemRow
                shopInventory.nextItemId = shopInventory.nextItemId + 1
                shopInventory.items[#shopInventory.items + 1] = shopItem
            end
        end

        if #shopInventory.items == 0 then return false, 'Shop has no enabled products' end

        local previousRegistration = registeredShops[shopId]
        registeredShops[shopId] = {
            inventoryId = inventoryId,
            coords = { x = coordinates.x, y = coordinates.y, z = coordinates.z },
            distance = interactionDistance,
            bucket = shopDefinition.bucket or 0,
            account = shopInventory.account,
        }

        inventoryContext.put(shopInventory)
        local committed, commitError = pcall(inventoryContext.commit, shopInventory)
        if not committed then
            registeredShops[shopId] = previousRegistration
            return false, tostring(commitError)
        end
        return true
    end

    function shopService.Open(playerSource, shopId)
        local shop = registeredShops[shopId]
        if not shop or not isPlayerNearby(playerSource, shop) then
            return false, 'Move closer to the shop'
        end

        return inventoryContext.open(playerSource, shop.inventoryId)
    end

    function shopService.Buy(playerSource, purchaseRequest)
        local shop = registeredShops[purchaseRequest.from:sub(6)]
        local playerInventory = inventoryContext.player(playerSource)
        if not shop or shop.inventoryId ~= purchaseRequest.from or not playerInventory
            or purchaseRequest.to ~= playerInventory.id then
            return false, 'Purchases must go to your own inventory'
        end

        local paymentAccount = purchaseRequest.account
        if paymentAccount == nil then paymentAccount = shop.account end
        if paymentAccount ~= 'cash' and paymentAccount ~= 'bank' then
            return false, 'Unsupported payment account'
        end

        if not isPlayerNearby(playerSource, shop) then
            return false, 'Move closer to the shop'
        end

        local shopInventory = inventoryContext.load(shop.inventoryId)
        if not shopInventory or purchaseRequest.revision ~= shopInventory.revision
            or purchaseRequest.targetRevision ~= playerInventory.revision then
            inventoryContext.send(playerSource)
            return false, 'Inventory changed; try again'
        end

        local shopItem = inventoryCore.find(shopInventory, purchaseRequest.itemId)
        if not shopItem or not inventoryCore.integer(purchaseRequest.amount, 1, 1000) then
            return false, 'Invalid purchase quantity'
        end

        if shopItem.canBuy == false then return false, 'This product is not for sale' end

        if shopItem.stock ~= false and shopItem.stock < purchaseRequest.amount then
            return false, 'Not enough shop stock'
        end

        if inventoryContext.locks[playerInventory.id] or inventoryContext.locks[shopInventory.id] then
            return false, 'Inventory is busy'
        end

        local plannedInventory = inventoryCore.copy(playerInventory)
        local placementSucceeded, placementError

        if purchaseRequest.x ~= nil or purchaseRequest.y ~= nil then
            if purchaseRequest.amount ~= 1 then return false, 'Drag purchases buy one item' end

            local itemDefinition = inventoryCore.definition(shopItem.name)
            local temporaryInventory = {
                id = 'purchase',
                size = inventoryCore.copy(itemDefinition.size),
                items = {{ id = 1, name = shopItem.name, amount = 1,
                    metadata = inventoryCore.copy(shopItem.metadata), x = 1, y = 1 }},
                nextItemId = 2,
            }

            placementSucceeded, placementError = inventoryCore.move(
                temporaryInventory, plannedInventory, 1, 1,
                purchaseRequest.x, purchaseRequest.y, purchaseRequest.rotated
            )
        else
            placementSucceeded, placementError = inventoryCore.add(
                plannedInventory, shopItem.name, purchaseRequest.amount, shopItem.metadata
            )
        end

        if not placementSucceeded then return false, placementError end

        local purchaseCost = shopItem.price * purchaseRequest.amount
        local availableFunds = bridge.Banking.GetAccount(playerSource, paymentAccount)
        if purchaseCost > 0 and availableFunds < purchaseCost then
            return false, 'Not enough ' .. paymentAccount
        end

        inventoryContext.locks[playerInventory.id] = true
        inventoryContext.locks[shopInventory.id] = true

        local function unlockInventories()
            inventoryContext.locks[playerInventory.id] = nil
            inventoryContext.locks[shopInventory.id] = nil
        end

        local paymentSucceeded = true
        local paymentError = nil
        if purchaseCost > 0 then
            local callSucceeded, paymentResult = pcall(
                bridge.Banking.RemoveMoney, playerSource, paymentAccount,
                purchaseCost, 'tss-inventory:shop:' .. purchaseRequest.from
            )
            paymentSucceeded = callSucceeded and paymentResult == true
            paymentError = not callSucceeded and tostring(paymentResult) or nil
        end

        if not paymentSucceeded then
            unlockInventories()
            if paymentError then print('[tss-inventory] Payment error: ' .. paymentError) end
            return false, 'Payment refused'
        end

        -- External banking adapters may yield. Reject stale plans and refund the same account.
        if playerInventory.revision ~= purchaseRequest.targetRevision
            or shopInventory.revision ~= purchaseRequest.revision
            or not GetPlayerName(playerSource)
            or inventoryContext.identity(playerSource) ~= playerInventory.id then
            if purchaseCost > 0 then
                local refundCallSucceeded, refundResult = pcall(
                    bridge.Banking.AddMoney, playerSource, paymentAccount,
                    purchaseCost, 'tss-inventory:shop-refund'
                )
                if not refundCallSucceeded or refundResult ~= true then
                    print(('[tss-inventory] REFUND REQUIRED player=%s shop=%s cost=%s'):format(
                        playerSource, purchaseRequest.from, purchaseCost
                    ))
                end
            end

            unlockInventories()
            return false, 'Purchase cancelled; inventory changed'
        end

        playerInventory.items = plannedInventory.items
        playerInventory.nextItemId = plannedInventory.nextItemId
        if shopItem.stock ~= false then shopItem.stock = shopItem.stock - purchaseRequest.amount end

        local saved, saveError = pcall(inventoryContext.commit, playerInventory, shopInventory)
        unlockInventories()
        if not saved then
            if purchaseCost > 0 then
                local refunded, refundResult = pcall(bridge.Banking.AddMoney, playerSource, paymentAccount, purchaseCost, 'tss-inventory:database-refund')
                if not refunded or refundResult ~= true then
                    print(('[tss-inventory] REFUND REQUIRED player=%s cost=%s'):format(playerSource, purchaseCost))
                end
            end
            print('[tss-inventory] Purchase save failed: ' .. tostring(saveError))
            return false, 'Purchase could not be saved'
        end

        TriggerEvent('tss-inventory:purchase', playerSource, {
            shop = purchaseRequest.from,
            item = shopItem.name,
            amount = purchaseRequest.amount,
            total = purchaseCost,
            account = paymentAccount,
        })

        return true, ('Bought %s × %s for $%s'):format(
            purchaseRequest.amount, inventoryCore.itemDefinition(shopItem).label, purchaseCost
        )
    end

    function shopService.Sell(playerSource, request)
        local shop = type(request.to) == 'string' and registeredShops[request.to:sub(6)]
        if not shop or shop.inventoryId ~= request.to or not isPlayerNearby(playerSource, shop) then return false, 'Move closer to the shop' end
        local sourceInventory, item = inventoryContext.findCarried(playerSource, { inventoryId = request.from, id = request.itemId })
        if not sourceInventory or not item then return false, 'Sell items from your own inventory' end
        local shopInventory = inventoryContext.load(shop.inventoryId)
        if not shopInventory or sourceInventory.revision ~= request.revision or shopInventory.revision ~= request.targetRevision then
            inventoryContext.send(playerSource)
            return false, 'Inventory changed; try again'
        end
        local product
        for _, candidate in ipairs(shopInventory.items) do if candidate.name == item.name then product = candidate; break end end
        if not product or not product.canSell or product.sellPrice == nil then return false, 'This shop does not buy that item' end
        if not inventoryCore.integer(request.amount, 1, math.min(1000, item.amount)) then return false, 'Invalid sale quantity' end
        local account = request.account or shop.account
        if account ~= 'cash' and account ~= 'bank' then return false, 'Unsupported payment account' end
        if inventoryContext.locks[sourceInventory.id] or inventoryContext.locks[shopInventory.id] then return false, 'Inventory is busy' end
        local definition = inventoryCore.definition(item.name)
        local containerId = definition.container and item.metadata.containerId
        local container = type(containerId) == 'string' and inventoryContext.load(containerId)
        if container and #container.items > 0 then return false, 'Empty the container before selling it' end
        local planned = inventoryCore.copy(sourceInventory)
        local removed, removeError = inventoryCore.remove(planned, item.id, request.amount)
        if not removed then return false, removeError end
        local total = product.sellPrice * request.amount
        local characterId = inventoryContext.identity(playerSource)
        inventoryContext.locks[sourceInventory.id], inventoryContext.locks[shopInventory.id] = true, true
        local function unlock()
            inventoryContext.locks[sourceInventory.id], inventoryContext.locks[shopInventory.id] = nil, nil
        end
        local function reversePayment()
            if total == 0 then return end
            if inventoryContext.identity(playerSource) ~= characterId then
                print(('[tss-inventory] SALE REVERSAL REQUIRED character=%s account=%s amount=%s'):format(characterId, account, total))
                return
            end
            local called, reversed = pcall(bridge.Banking.RemoveMoney, playerSource, account, total, 'tss-inventory:sale-rollback')
            if not called or reversed ~= true then print(('[tss-inventory] SALE REVERSAL REQUIRED player=%s account=%s amount=%s'):format(playerSource, account, total)) end
        end
        if total > 0 then
            local called, paid = pcall(bridge.Banking.AddMoney, playerSource, account, total, 'tss-inventory:shop-sale')
            if not called or paid ~= true then unlock(); return false, 'Shop payment refused' end
        end
        if sourceInventory.revision ~= request.revision or shopInventory.revision ~= request.targetRevision
            or inventoryContext.identity(playerSource) ~= characterId or not isPlayerNearby(playerSource, shop) then
            reversePayment(); unlock(); return false, 'Sale cancelled; inventory changed'
        end
        sourceInventory.items, sourceInventory.nextItemId = planned.items, planned.nextItemId
        local saved, saveError = pcall(inventoryContext.commit, sourceInventory)
        unlock()
        if not saved then
            reversePayment()
            print('[tss-inventory] Sale save failed: ' .. tostring(saveError))
            return false, 'Sale could not be saved'
        end
        -- Sold instances are consumed rather than restocked as fresh/default-metadata products.
        TriggerClientEvent('tss-inventory:itemBox', playerSource, inventoryCore.itemDefinition(item), 'removed', request.amount)
        TriggerEvent('tss-inventory:sale', playerSource, { shop = shop.inventoryId, item = item.name, amount = request.amount, total = total, account = account })
        return true, ('Sold %s × %s for $%s'):format(request.amount, inventoryCore.itemDefinition(item).label, total)
    end

    function shopService.RevokeDistant()
        for playerSource, inventorySession in pairs(inventoryContext.sessions) do
            local sessionChanged = false

            for _, shop in pairs(registeredShops) do
                if inventorySession[shop.inventoryId] and not isPlayerNearby(playerSource, shop) then
                    inventorySession[shop.inventoryId] = nil
                    sessionChanged = true
                end
            end

            if sessionChanged then inventoryContext.send(playerSource) end
        end
    end

    function shopService.RestoreInventory(inventoryId, inventory)
        if not inventory and inventoryId:sub(1, 5) == 'shop:' then registeredShops[inventoryId:sub(6)] = nil end
    end

    return shopService
end
