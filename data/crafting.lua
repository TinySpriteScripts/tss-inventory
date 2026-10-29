TSSCrafting = TSSCrafting or {}

local craftingRecipes = {
    radio = {
        input = { -- what 2 items are placed on top of each other to craft
            plastic = 1,
            bandage = 2,
        },
        time = 2, -- in seconds how fast it crafts
        output = 1, -- crafted amount; defaults to 1 and must fit the item's stack limit
    },
    joint = {
        input = {
            rolling_paper = 1,
            weed = 1,
        },
        time = 5,
        output = 5, -- how many of that item you get (ignored if item doesnt stack)
    },
}

for craftedRecipe, recipeDefinition in pairs(craftingRecipes) do
    TSSCrafting[craftedRecipe] = recipeDefinition
end
