-- Plans are private until the server timer completes. Cancelling never consumes ingredients.
function TSSCreateCraftingService(context)
    local inventoryCore = TSSCore
    local activeCrafts = {}
    local craftingService = {}

    function craftingService.Recipes()
        local recipes = {}
        for resultName, recipe in pairs(TSSCrafting or {}) do
            local ingredients = type(recipe) == 'table' and recipe.input
            local duration = type(recipe) == 'table' and recipe.time
            local resultDefinition = inventoryCore.definition(resultName)
            local outputAmount = 1
            if resultDefinition and resultDefinition.stack and type(recipe) == 'table' and recipe.output ~= nil then
                outputAmount = recipe.output
            end
            local ingredientCount = 0
            local valid = type(ingredients) == 'table' and type(duration) == 'number'
                and duration > 0 and duration <= 3600 and resultDefinition ~= nil
                and inventoryCore.integer(outputAmount, 1, resultDefinition.stackSize)
            for itemName, amount in pairs(type(ingredients) == 'table' and ingredients or {}) do
                ingredientCount = ingredientCount + 1
                valid = valid and inventoryCore.definition(itemName) ~= nil and inventoryCore.integer(amount, 1, 100000)
            end
            if valid and ingredientCount == 2 then
                recipes[#recipes + 1] = { name = resultName, input = inventoryCore.copy(ingredients),
                    output = outputAmount, duration = math.ceil(duration * 1000), definition = resultDefinition }
            end
        end
        table.sort(recipes, function(firstRecipe, secondRecipe) return firstRecipe.name < secondRecipe.name end)
        return recipes
    end

    function craftingService.Active(playerSource)
        return activeCrafts[playerSource] ~= nil
    end

    function craftingService.Cancel(playerSource)
        local craft = activeCrafts[playerSource]
        if not craft then return true end
        activeCrafts[playerSource] = nil
        context.locks[craft.inventoryId] = nil
        TriggerClientEvent('tss-inventory:crafting', playerSource, false)
        return true
    end

    function craftingService.Start(playerSource, inventory, request)
        if craftingService.Active(playerSource) or context.locks[inventory.id] then return false, 'Inventory is busy' end
        if inventory.id ~= context.identity(playerSource) or inventory.type ~= 'player' then return false, 'Craft in your own inventory' end
        local firstItem = inventoryCore.find(inventory, request.itemId)
        local secondItem = inventoryCore.find(inventory, request.targetItemId)
        if not firstItem or not secondItem or firstItem.id == secondItem.id or firstItem.name == secondItem.name then
            return false, 'Choose two different ingredients'
        end
        if firstItem.metadata.containerId or secondItem.metadata.containerId then return false, 'Containers cannot be ingredients' end
        local recipe
        for _, candidate in ipairs(craftingService.Recipes()) do
            if candidate.name == request.recipe and candidate.input[firstItem.name] and candidate.input[secondItem.name] then recipe = candidate; break end
        end
        if not recipe then return false, 'No matching recipe' end
        local plannedInventory = inventoryCore.copy(inventory)
        if not inventoryCore.remove(plannedInventory, firstItem.id, recipe.input[firstItem.name])
            or not inventoryCore.remove(plannedInventory, secondItem.id, recipe.input[secondItem.name]) then
            return false, 'Not enough ingredients in these stacks'
        end
        local output = { id = plannedInventory.nextItemId, name = recipe.name, amount = recipe.output,
            metadata = inventoryCore.copy(recipe.definition.metadata), rotated = false }
        if inventoryCore.fits(plannedInventory, output, secondItem.x, secondItem.y) then output.x, output.y = secondItem.x, secondItem.y
        elseif inventoryCore.fits(plannedInventory, output, firstItem.x, firstItem.y) then output.x, output.y = firstItem.x, firstItem.y
        else output.x, output.y = inventoryCore.space(plannedInventory, output) end
        if not output.x then return false, 'Not enough grid space for the crafted item' end
        if not inventoryCore.allowed(plannedInventory, output.name) then return false, 'Crafted item is not allowed here' end
        plannedInventory.items[#plannedInventory.items + 1] = output
        plannedInventory.nextItemId = plannedInventory.nextItemId + 1
        if plannedInventory.maxWeight and inventoryCore.weight(plannedInventory) > plannedInventory.maxWeight then return false, 'Weight limit exceeded' end
        if inventoryCore.validateWeights then
            local valid, weightError = inventoryCore.validateWeights({ [inventory.id] = plannedInventory })
            if not valid then return false, weightError end
        end
        local craft = { inventoryId = inventory.id, revision = inventory.revision, planned = plannedInventory }
        activeCrafts[playerSource] = craft
        context.locks[inventory.id] = true
        local visibleOutput = inventoryCore.copy(output)
        visibleOutput.definition = inventoryCore.itemDefinition(output)
        local ingredientAmounts = {}
        for _, ingredient in ipairs({ firstItem, secondItem }) do
            ingredientAmounts[tostring(ingredient.id)] = ingredient.amount - recipe.input[ingredient.name]
        end
        TriggerClientEvent('tss-inventory:crafting', playerSource, {
            inventoryId = inventory.id, item = visibleOutput, ingredients = ingredientAmounts, duration = recipe.duration,
        })
        SetTimeout(recipe.duration, function()
            if activeCrafts[playerSource] ~= craft then return end
            local succeeded, failure = context.operation(function()
                if activeCrafts[playerSource] ~= craft then return true end
                local currentInventory = context.load(craft.inventoryId)
                if context.identity(playerSource) ~= craft.inventoryId or not currentInventory or currentInventory.revision ~= craft.revision then
                    return false, 'Crafting inventory changed'
                end
                currentInventory.items = craft.planned.items
                currentInventory.nextItemId = craft.planned.nextItemId
                context.commit(currentInventory)
                return true
            end)
            if activeCrafts[playerSource] == craft then
                craftingService.Cancel(playerSource)
                if not succeeded then context.notify(playerSource, failure or 'Crafting failed') end
            end
        end)
        return true
    end

    return craftingService
end
