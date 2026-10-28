TSSCrafting = TSSCrafting or {}

local craftingRecipes = {
    radio = {
        input = { -- what 2 items are placed on top of each other to craft
            plastic = 1,
            bandage = 2,
        },
        time = 2, -- in seconds how fast it crafts
    },
}

for craftedRecipe, recipeDefinition in pairs(craftingRecipes) do
    TSSItems[craftedRecipe] = recipeDefinition
end
