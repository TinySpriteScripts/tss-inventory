-- Each item file builds a local definition table, then registers it by item name.
-- Values omitted here inherit Config.ItemDefaults.
TSSItems = TSSItems or {}

local itemDefinitions = {
    wallet = {
        label = 'Wallet',
        description = 'Keeps your cash and cards together.',
        size = { x = 1, y = 1 },
        weight = 100,
        image = 'wallet.svg',
        stack = false,
        container = 'wallet',
    },
    backpack = {
        label = 'Backpack',
        description = 'Extra storage you can carry with you.',
        size = { x = 2, y = 3 },
        weight = 800,
        image = 'backpack.svg',
        stack = false,
        container = 'backpack',
    },
    radio = {
        label = 'Radio',
        description = 'You can communicate with this through a signal',
        size = { x = 1, y = 2 },
        image = 'radio.png',
        weight = 100,
        stack = false,
    },
    water_bottle = {
        label = 'Water Bottle',
        description = 'Fresh drinking water.',
        size = { x = 1, y = 2 },
        weight = 500,
        image = 'water_bottle.png',
        stackSize = 10,
    },
    sandwich = {
        label = 'Sandwich',
        description = 'A freshly prepared sandwich.',
        size = { x = 2, y = 1 },
        weight = 300,
        image = 'sandwich.png',
        stackSize = 5,
    },
    bandage = {
        label = 'Bandage',
        description = 'A clean medical dressing.',
        weight = 50,
        image = 'bandage.png',
        stackSize = 20,
    },
    phone = {
        label = 'Phone',
        description = 'A mobile phone.',
        weight = 200,
        image = 'phone.png',
        stack = false,
    },
    cash = {
        label = 'Cash',
        description = 'Inventory cash item; separate from bridge money accounts.',
        weight = 0,
        stackSize = 10000,
        useable = false,
    },
    id_card = {
        label = 'ID Card',
        weight = 10,
        image = 'id_card.png',
        stack = false,
        useable = false,
    },
    drivers_license = {
        label = 'Driving Licence',
        weight = 10,
        image = 'driver_license.png',
        stack = false,
        useable = false,
    },
    plastic = {
        label = 'Plastic',
        description = 'Reusable plastic material.',
        image = 'plastic.png',
        weight = 100,
        stackSize = 100,
        useable = false,
    },
}

for itemName, itemDefinition in pairs(itemDefinitions) do
    TSSItems[itemName] = itemDefinition
end
