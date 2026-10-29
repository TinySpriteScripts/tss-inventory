-- Slot IDs control appearance components. Item metadata supplies gender and variations.
TSSClothingSlots = {
    { id = 'top', label = 'Top', component = 11 },
    { id = 'undershirt', label = 'Undershirt', component = 8 },
    { id = 'pants', label = 'Trousers', component = 4 },
    { id = 'shoes', label = 'Shoes', component = 6 },
    { id = 'mask', label = 'Mask', component = 1 },
    { id = 'bag', label = 'Bag', component = 5 },
    { id = 'accessory', label = 'Necklace', component = 7 },
    { id = 'vest', label = 'Vest', component = 9 },
    { id = 'decals', label = 'Decals', component = 10 },
    { id = 'hat', label = 'Hat', prop = 0 },
    { id = 'glasses', label = 'Glasses', prop = 1 },
    { id = 'ears', label = 'Earrings', prop = 2 },
    { id = 'watch', label = 'Watch', prop = 6 },
    { id = 'bracelet', label = 'Bracelet', prop = 7 },
}

local items = {
    shirt = { label = 'Shirt', slot = 'top', size = { x = 2, y = 2 }, image = 'clothing_shirt.png' },
    jacket = { label = 'Jacket', slot = 'top', size = { x = 2, y = 2 }, image = 'clothing_jacket.png' },
    undershirt = { label = 'Undershirt', slot = 'undershirt', size = { x = 2, y = 2 }, image = 'clothing_undershirt.png' },
    pants = { label = 'Trousers', slot = 'pants', size = { x = 2, y = 2 }, image = 'clothing_pants.png' },
    shoes = { label = 'Shoes', slot = 'shoes', size = { x = 2, y = 2 }, image = 'clothing_shoes.png' },
    mask = { label = 'Mask', slot = 'mask', size = { x = 2, y = 2 }, image = 'clothing_mask.png' },
    clothing_bag = { label = 'Clothing Bag', slot = 'bag', size = { x = 2, y = 2 }, image = 'clothing_bag.png' },
    necklace = { label = 'Necklace', slot = 'accessory', size = { x = 1, y = 2 }, image = 'clothing_necklace.png' },
    clothing_vest = { label = 'Vest', slot = 'vest', size = { x = 2, y = 2 }, image = 'clothing_vest.png' },
    clothing_decals = { label = 'Decals', slot = 'decals', size = { x = 2, y = 2 }, image = 'clothing_decals.png' },
    hat = { label = 'Hat', slot = 'hat', size = { x = 2, y = 2 }, image = 'clothing_hat.png' },
    glasses = { label = 'Glasses', slot = 'glasses', size = { x = 2, y = 1 }, image = 'clothing_glasses.png' },
    earrings = { label = 'Earrings', slot = 'ears', size = { x = 1, y = 1 }, image = 'clothing_earrings.png' },
    watch = { label = 'Watch', slot = 'watch', size = { x = 1, y = 1 }, image = 'clothing_watch.png' },
    bracelet = { label = 'Bracelet', slot = 'bracelet', size = { x = 1, y = 1 }, image = 'clothing_bracelet.png' },
}

TSSItems = TSSItems or {}
for itemName, definition in pairs(items) do
    -- Existing definitions can keep their own labels, images and weights.
    if not TSSItems[itemName] then
        TSSItems[itemName] = { label = definition.label, category = 'clothing', description = 'Wearable clothing.',
            size = definition.size, image = definition.image, weight = 200, stack = false, useable = true,
            shouldClose = false, clothingSlot = definition.slot, metadata = {} }
    end
end
