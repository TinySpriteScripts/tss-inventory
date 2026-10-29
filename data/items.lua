-- Each item file builds a local definition table, then registers it by item name.
-- Values omitted here inherit Config.ItemDefaults.
TSSItems = TSSItems or {}

local itemDefinitions = {
    wallet = {
        metadata = {},
        category = 'storage',
        label = 'Wallet',
        description = 'Keeps your cash and cards together.',
        size = { x = 1, y = 1 },
        weight = 100,
        image = 'wallet.png',
        stack = false,
        container = 'wallet',
        shouldClose = false,
    },
    stolen_wallet = {
        metadata = {},
        category = 'storage',
        label = 'Stolen Wallet',
        description = 'A stolen wallet. Open it to search its contents.',
        size = { x = 1, y = 1 },
        weight = 100,
        image = 'wallet.png',
        stack = false,
        useable = true,
        container = 'stolen_wallet',
        shouldClose = false,
    },
    backpack = {
        metadata = {},
        category = 'storage',
        label = 'Backpack',
        description = 'Extra storage you can carry with you.',
        size = { x = 2, y = 3 },
        weight = 800,
        image = 'backpack.png',
        stack = false,
        container = 'backpack',
        shouldClose = false,
    },
    radio = {
        metadata = {},
        category = 'communication',
        label = 'Radio',
        description = 'You can communicate with this through a signal',
        size = { x = 1, y = 2 },
        image = 'radio.png',
        weight = 100,
        stack = false,
    },
    water_bottle = {
        metadata = {},
        category = 'drinks',
        label = 'Water Bottle',
        description = 'Fresh drinking water.',
        size = { x = 1, y = 2 },
        weight = 500,
        image = 'water_bottle.png',
        stackSize = 10,
    },
    sandwich = {
        metadata = {},
        category = 'food',
        label = 'Sandwich',
        description = 'A freshly prepared sandwich.',
        size = { x = 2, y = 1 },
        weight = 300,
        image = 'sandwich.png',
        stackSize = 5,
    },
    bandage = {
        metadata = {},
        category = 'medical',
        label = 'Bandage',
        description = 'A clean medical dressing.',
        weight = 50,
        image = 'bandage.png',
        stackSize = 20,
    },
    phone = {
        metadata = {},
        category = 'communication',
        label = 'Phone',
        description = 'A mobile phone.',
        weight = 200,
        image = 'phone.png',
        stack = false,
    },
    cash = {
        metadata = {},
        category = 'currency',
        label = 'Cash',
        image = 'cash.png',
        description = 'Physical cash.',
        weight = 0,
        stackSize = 10000,
        useable = false,
    },
    id_card = {
        metadata = {},
        category = 'documents',
        label = 'ID Card',
        weight = 10,
        image = 'id_card.png',
        stack = false,
        useable = false,
    },
    drivers_license = {
        metadata = {},
        category = 'documents',
        label = 'Driving Licence',
        weight = 10,
        image = 'driver_license.png',
        stack = false,
        useable = false,
    },
    plastic = {
        metadata = {},
        category = 'materials',
        label = 'Plastic',
        description = 'Reusable plastic material.',
        image = 'plastic.png',
        weight = 100,
        stackSize = 100,
        useable = false,
    },
    paper = {
        metadata = {},
        category = 'materials',
        label = "Paper",
        description = "Its Paper",
        image = 'paper.png',
        useable = false,
    },
    comicbook = {
        metadata = {},
        category = 'documents',
        label = "Comic Book",
        description = "Book",
        image = 'comicbook.png',
        stack = false,
    },

    pistol_ammo = {
        metadata = {},
        category = 'ammunition',
        label = 'Pistol ammo',
        description = 'Ammo for Pistols',
        size = { x = 2, y = 1 },
        weight = 200,
        image = 'pistol_ammo.png',
    },

    rifle_ammo = {
        metadata = {},
        category = 'ammunition',
        label = 'Rifle ammo',
        description = 'Ammo for Rifles',
        size = { x = 2, y = 1 },
        weight = 1000,
        image = 'rifle_ammo.png',
    },

    smg_ammo = {
        metadata = {},
        category = 'ammunition',
        label = 'SMG ammo',
        description = 'Ammo for Sub Machine Guns',
        size = { x = 2, y = 1 },
        weight = 500,
        image = 'smg_ammo.png',
    },

    shotgun_ammo = {
        metadata = {},
        category = 'ammunition',
        label = 'Shotgun ammo',
        description = 'Ammo for Shotguns',
        size = { x = 2, y = 1 },
        weight = 500,
        image = 'shotgun_ammo.png',
    },

    mg_ammo = {
        metadata = {},
        category = 'ammunition',
        label = 'MG ammo',
        description = 'Ammo for Machine Guns',
        size = { x = 2, y = 1 },
        weight = 1000,
        image = 'mg_ammo.png',
    },

    snp_ammo = {
        metadata = {},
        category = 'ammunition',
        label = 'Sniper ammo',
        description = 'Ammo for Sniper Rifles',
        size = { x = 2, y = 1 },
        weight = 1000,
        image = 'rifle_ammo.png',
    },

    emp_ammo = {
        metadata = {},
        category = 'ammunition',
        label = 'EMP Ammo',
        description = 'Ammo for EMP Launcher',
        size = { x = 2, y = 1 },
        weight = 200,
        image = 'emp_ammo.png',
    },

    -- Cards
    driver_license = {
        metadata = {},
        category = 'documents',
        label = 'Drivers License',
        description = 'Permit to show you can drive a vehicle',
        weight = 0,
        image = 'driver_license.png',
        stack = false,
        shouldClose = false,
    },

    lawyerpass = {
        metadata = {},
        category = 'documents',
        label = 'Lawyer Pass',
        description = 'Pass exclusive to lawyers to show they can represent a suspect',
        weight = 0,
        image = 'lawyerpass.png',
        stack = false,
        shouldClose = false,
    },

    weaponlicense = {
        metadata = {},
        category = 'documents',
        label = 'Weapon License',
        description = 'Weapon License',
        weight = 0,
        image = 'weapon_license.png',
        stack = false,
    },

    bank_card = {
        metadata = {},
        category = 'documents',
        label = 'Bank Card',
        description = 'Used to access ATM',
        weight = 0,
        image = 'bank_card.png',
        stack = false,
    },

    security_card_01 = {
        metadata = {},
        category = 'documents',
        label = 'Security Card A',
        description = 'A security card... I wonder what it goes to',
        weight = 0,
        image = 'security_card_01.png',
    },

    security_card_02 = {
        metadata = {},
        category = 'documents',
        label = 'Security Card B',
        description = 'A security card... I wonder what it goes to',
        weight = 0,
        image = 'security_card_02.png',
    },

    -- Food
    tosti = {
        metadata = {},
        category = 'food',
        label = 'Grilled Cheese Sandwich',
        description = 'Nice to eat',
        size = { x = 2, y = 1 },
        weight = 200,
        image = 'tosti.png',
    },

    twerks_candy = {
        metadata = {},
        category = 'food',
        label = 'Twerks',
        description = 'Some delicious candy :O',
        weight = 100,
        image = 'twerks_candy.png',
    },

    snikkel_candy = {
        metadata = {},
        category = 'food',
        label = 'Snikkel',
        description = 'Some delicious candy :O',
        weight = 100,
        image = 'snikkel_candy.png',
    },

    -- Drinks
    coffee = {
        metadata = {},
        category = 'drinks',
        label = 'Coffee',
        description = 'Pump 4 Caffeine',
        size = { x = 1, y = 2 },
        weight = 200,
        image = 'coffee.png',
    },

    kurkakola = {
        metadata = {},
        category = 'drinks',
        label = 'Cola',
        description = 'For all the thirsty out there',
        size = { x = 1, y = 2 },
        weight = 500,
        image = 'cola.png',
    },

    -- Alcohol
    beer = {
        metadata = {},
        category = 'alcohol',
        label = 'Beer',
        description = 'Nothing like a good cold beer!',
        size = { x = 1, y = 2 },
        weight = 500,
        image = 'beer.png',
    },

    whiskey = {
        metadata = {},
        category = 'alcohol',
        label = 'Whiskey',
        description = 'For all the thirsty out there',
        size = { x = 1, y = 2 },
        weight = 500,
        image = 'whiskey.png',
    },

    vodka = {
        metadata = {},
        category = 'alcohol',
        label = 'Vodka',
        description = 'For all the thirsty out there',
        size = { x = 1, y = 2 },
        weight = 500,
        image = 'vodka.png',
    },

    grape = {
        metadata = {},
        category = 'food',
        label = 'Grape',
        description = 'Mmmmh yummie, grapes',
        weight = 100,
        image = 'grape.png',
        shouldClose = false,
    },

    wine = {
        metadata = {},
        category = 'alcohol',
        label = 'Wine',
        description = 'Some good wine to drink on a fine evening',
        size = { x = 1, y = 2 },
        weight = 300,
        image = 'wine.png',
        shouldClose = false,
    },

    grapejuice = {
        metadata = {},
        category = 'drinks',
        label = 'Grape Juice',
        description = 'Grape juice is said to be healthy',
        size = { x = 1, y = 2 },
        weight = 200,
        image = 'grapejuice.png',
        shouldClose = false,
    },

    -- Drugs
    joint = {
        metadata = {},
        category = 'drugs',
        label = 'Joint',
        description = 'Sidney would be very proud at you',
        weight = 0,
        image = 'joint.png',
    },

    cokebaggy = {
        metadata = {},
        category = 'drugs',
        label = 'Bag of Coke',
        description = 'To get happy real quick',
        weight = 0,
        image = 'cocaine_baggy.png',
    },

    crack_baggy = {
        metadata = {},
        category = 'drugs',
        label = 'Bag of Crack',
        description = 'To get happy faster',
        weight = 0,
        image = 'crack_baggy.png',
    },

    xtcbaggy = {
        metadata = {},
        category = 'drugs',
        label = 'Bag of XTC',
        description = 'Pop those pills baby',
        weight = 0,
        image = 'xtc_baggy.png',
    },

    coke_brick = {
        metadata = {},
        category = 'drugs',
        label = 'Coke Brick',
        description = 'Heavy package of cocaine, mostly used for deals and takes a lot of space',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'coke_brick.png',
        stack = false,
        useable = false,
    },

    weed_brick = {
        metadata = {},
        category = 'drugs',
        label = 'Weed Brick',
        description = '1KG Weed Brick to sell to large customers.',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'weed_brick.png',
        useable = false,
    },

    coke_small_brick = {
        metadata = {},
        category = 'drugs',
        label = 'Coke Package',
        description = 'Small package of cocaine, mostly used for deals and takes a lot of space',
        size = { x = 2, y = 1 },
        weight = 350,
        image = 'coke_small_brick.png',
        stack = false,
        useable = false,
    },

    oxy = {
        metadata = {},
        category = 'medical',
        label = 'Prescription Oxy',
        description = 'The Label Has Been Ripped Off',
        weight = 0,
        image = 'oxy.png',
    },

    meth = {
        metadata = {},
        category = 'drugs',
        label = 'Meth',
        description = 'A baggie of Meth',
        weight = 100,
        image = 'meth_baggy.png',
    },

    rolling_paper = {
        metadata = {},
        category = 'drug_supplies',
        label = 'Rolling Paper',
        description = 'Paper made specifically for encasing and smoking tobacco or cannabis.',
        weight = 0,
        image = 'rolling_paper.png',
        useable = false,
    },

    empty_weed_bag = {
        metadata = {},
        category = 'drug_supplies',
        label = 'Empty Weed Bag',
        description = 'A small empty bag',
        weight = 0,
        image = 'weed_baggy_empty.png',
    },

    weed_nutrition = {
        metadata = {},
        category = 'drug_supplies',
        label = 'Plant Fertilizer',
        description = 'Plant nutrition',
        size = { x = 1, y = 2 },
        weight = 2000,
        image = 'weed_nutrition.png',
    },

    weed = {
        metadata = {},
        category = 'drugs',
        label = 'Weed 2g',
        description = 'A weed bag with 2g',
        weight = 200,
        image = 'weed_baggy.png',
        shouldClose = false,
    },

    -- Material
    metalscrap = {
        metadata = {},
        category = 'materials',
        label = 'Metal Scrap',
        description = 'You can probably make something nice out of this',
        weight = 100,
        image = 'metalscrap.png',
        useable = false,
        shouldClose = false,
    },

    copper = {
        metadata = {},
        category = 'materials',
        label = 'Copper',
        description = 'Nice piece of metal that you can probably use for something',
        weight = 100,
        image = 'copper.png',
        useable = false,
        shouldClose = false,
    },

    aluminum = {
        metadata = {},
        category = 'materials',
        label = 'Aluminium',
        description = 'Nice piece of metal that you can probably use for something',
        weight = 100,
        image = 'aluminum.png',
        useable = false,
        shouldClose = false,
    },

    aluminumoxide = {
        metadata = {},
        category = 'materials',
        label = 'Aluminium Powder',
        description = 'Some powder to mix with',
        weight = 100,
        image = 'aluminumoxide.png',
        useable = false,
        shouldClose = false,
    },

    iron = {
        metadata = {},
        category = 'materials',
        label = 'Iron',
        description = 'Handy piece of metal that you can probably use for something',
        weight = 100,
        image = 'iron.png',
        useable = false,
        shouldClose = false,
    },

    ironoxide = {
        metadata = {},
        category = 'materials',
        label = 'Iron Powder',
        description = 'Some powder to mix with.',
        weight = 100,
        image = 'ironoxide.png',
        useable = false,
        shouldClose = false,
    },

    steel = {
        metadata = {},
        category = 'materials',
        label = 'Steel',
        description = 'Nice piece of metal that you can probably use for something',
        weight = 100,
        image = 'steel.png',
        useable = false,
        shouldClose = false,
    },

    rubber = {
        metadata = {},
        category = 'materials',
        label = 'Rubber',
        description = 'Rubber, I believe you can make your own rubber ducky with it :D',
        weight = 100,
        image = 'rubber.png',
        useable = false,
        shouldClose = false,
    },

    glass = {
        metadata = {},
        category = 'materials',
        label = 'Glass',
        description = 'It is very fragile, watch out',
        weight = 100,
        image = 'glass.png',
        useable = false,
        shouldClose = false,
    },

    -- Tools
    lockpick = {
        metadata = {},
        category = 'tools',
        label = 'Lockpick',
        description = 'Very useful if you lose your keys a lot.. or if you want to use it for something else...',
        weight = 300,
        image = 'lockpick.png',
    },

    advancedlockpick = {
        metadata = {},
        category = 'tools',
        label = 'Advanced Lockpick',
        description = 'If you lose your keys a lot this is very useful... Also useful to open your beers',
        weight = 500,
        image = 'advancedlockpick.png',
    },

    electronickit = {
        metadata = {},
        category = 'tools',
        label = 'Electronic Kit',
        description = 'If you\'ve always wanted to build a robot you can maybe start here. Maybe you\'ll be the new Elon Musk?',
        size = { x = 2, y = 2 },
        weight = 100,
        image = 'electronickit.png',
    },

    gatecrack = {
        metadata = {},
        category = 'tools',
        label = 'Gatecrack',
        description = 'Handy software to tear down some fences',
        size = { x = 2, y = 2 },
        weight = 0,
        image = 'usb_device.png',
        useable = false,
    },

    thermite = {
        metadata = {},
        category = 'tools',
        label = 'Thermite',
        description = 'Sometimes you\'d wish for everything to burn',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'thermite.png',
    },

    trojan_usb = {
        metadata = {},
        category = 'tools',
        label = 'Trojan USB',
        description = 'Handy software to shut down some systems',
        weight = 0,
        image = 'usb_device.png',
        useable = false,
    },

    screwdriverset = {
        metadata = {},
        category = 'tools',
        label = 'Toolkit',
        description = 'Very useful to screw... screws...',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'screwdriverset.png',
        useable = false,
        shouldClose = false,
    },

    drill = {
        metadata = {},
        category = 'tools',
        label = 'Drill',
        description = 'The real deal...',
        size = { x = 2, y = 2 },
        weight = 20000,
        image = 'drill.png',
        useable = false,
        shouldClose = false,
    },

    -- Vehicle Tools
    nitrous = {
        metadata = {},
        category = 'vehicle_tools',
        label = 'Nitrous',
        description = 'Speed up, gas pedal! :D',
        size = { x = 1, y = 2 },
        weight = 1000,
        image = 'nitrous.png',
    },

    repairkit = {
        metadata = {},
        category = 'vehicle_tools',
        label = 'Repairkit',
        description = 'A nice toolbox with stuff to repair your vehicle',
        size = { x = 2, y = 2 },
        weight = 2500,
        image = 'repairkit.png',
    },

    advancedrepairkit = {
        metadata = {},
        category = 'vehicle_tools',
        label = 'Advanced Repairkit',
        description = 'A nice toolbox with stuff to repair your vehicle',
        size = { x = 2, y = 2 },
        weight = 4000,
        image = 'advancedkit.png',
    },

    cleaningkit = {
        metadata = {},
        category = 'vehicle_tools',
        label = 'Cleaning Kit',
        description = 'A microfiber cloth with some soap will let your car sparkle again!',
        size = { x = 2, y = 2 },
        weight = 250,
        image = 'cleaningkit.png',
    },

    tunerlaptop = {
        metadata = {},
        category = 'vehicle_tools',
        label = 'Tunerchip',
        description = 'With this tunerchip you can get your car on steroids... If you know what you\'re doing',
        size = { x = 3, y = 2 },
        weight = 2000,
        image = 'tunerchip.png',
        stack = false,
    },

    harness = {
        metadata = {},
        category = 'vehicle_tools',
        label = 'Race Harness',
        description = 'Racing Harness so no matter what you stay in the car',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'harness.png',
        stack = false,
    },

    jerry_can = {
        metadata = {},
        category = 'vehicle_tools',
        label = 'Jerrycan 20L',
        description = 'A can full of Fuel',
        size = { x = 2, y = 3 },
        weight = 20000,
        image = 'jerry_can.png',
    },

    tirerepairkit = {
        metadata = {},
        category = 'vehicle_tools',
        label = 'Tire Repair Kit',
        description = 'A kit to repair your tires',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'tirerepairkit.png',
    },

    -- Mechanic Parts
    veh_toolbox = {
        metadata = {},
        category = 'vehicle_tools',
        label = 'Toolbox',
        description = 'Check vehicle status',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'veh_toolbox.png',
    },

    veh_armor = {
        metadata = {},
        category = 'vehicle_parts',
        label = 'Armor',
        description = 'Upgrade vehicle armor',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'veh_armor.png',
    },

    veh_brakes = {
        metadata = {},
        category = 'vehicle_parts',
        label = 'Brakes',
        description = 'Upgrade vehicle brakes',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'veh_brakes.png',
    },

    veh_engine = {
        metadata = {},
        category = 'vehicle_parts',
        label = 'Engine',
        description = 'Upgrade vehicle engine',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'veh_engine.png',
    },

    veh_suspension = {
        metadata = {},
        category = 'vehicle_parts',
        label = 'Suspension',
        description = 'Upgrade vehicle suspension',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'veh_suspension.png',
    },

    veh_transmission = {
        metadata = {},
        category = 'vehicle_parts',
        label = 'Transmission',
        description = 'Upgrade vehicle transmission',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'veh_transmission.png',
    },

    veh_turbo = {
        metadata = {},
        category = 'vehicle_parts',
        label = 'Turbo',
        description = 'Install vehicle turbo',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'veh_turbo.png',
    },

    veh_interior = {
        metadata = {},
        category = 'vehicle_parts',
        label = 'Interior',
        description = 'Upgrade vehicle interior',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'veh_interior.png',
    },

    veh_exterior = {
        metadata = {},
        category = 'vehicle_parts',
        label = 'Exterior',
        description = 'Upgrade vehicle exterior',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'veh_exterior.png',
    },

    veh_wheels = {
        metadata = {},
        category = 'vehicle_parts',
        label = 'Wheels',
        description = 'Upgrade vehicle wheels',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'veh_wheels.png',
    },

    veh_neons = {
        metadata = {},
        category = 'vehicle_parts',
        label = 'Neons',
        description = 'Upgrade vehicle neons',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'veh_neons.png',
    },

    veh_xenons = {
        metadata = {},
        category = 'vehicle_parts',
        label = 'Xenons',
        description = 'Upgrade vehicle xenons',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'veh_xenons.png',
    },

    veh_tint = {
        metadata = {},
        category = 'vehicle_parts',
        label = 'Tints',
        description = 'Install vehicle tint',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'veh_tint.png',
    },

    veh_plates = {
        metadata = {},
        category = 'vehicle_parts',
        label = 'Plates',
        description = 'Install vehicle plates',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'veh_plates.png',
    },

    -- Medication
    firstaid = {
        metadata = {},
        category = 'medical',
        label = 'First Aid',
        description = 'You can use this First Aid kit to get people back on their feet',
        size = { x = 2, y = 2 },
        weight = 2500,
        image = 'firstaid.png',
    },

    ifaks = {
        metadata = {},
        category = 'medical',
        label = 'ifaks',
        description = 'ifaks for healing and a complete stress remover.',
        size = { x = 2, y = 2 },
        weight = 200,
        image = 'ifaks.png',
    },

    painkillers = {
        metadata = {},
        category = 'medical',
        label = 'Painkillers',
        description = 'For pain you can\'t stand anymore, take this pill that\'d make you feel great again',
        weight = 0,
        image = 'painkillers.png',
    },

    walkstick = {
        metadata = {},
        category = 'medical',
        label = 'Walking Stick',
        description = 'Walking stick for ya\'ll grannies out there.. HAHA',
        size = { x = 1, y = 4 },
        weight = 1000,
        image = 'walkstick.png',
    },

    -- Communication
    tssphone = {
        metadata = {},
        category = 'communication',
        label = 'Sprite Phone',
        description = 'Latest sprite phone model',
        size = { x = 1, y = 2 },
        weight = 700,
        image = 'tssphone.png',
        stack = false,
    },

    tssphone_powerbank = {
        metadata = {},
        category = 'electronics',
        label = 'Power Bank',
        description = 'Juice Up Your Phones battery',
        weight = 700,
        image = 'tssphone_powerbank.png',
        stack = false,
    },

    vpn_usbstick = {
        metadata = {},
        category = 'electronics',
        label = 'VPN USB Stick',
        description = 'a usb stick',
        weight = 700,
        image = 'vpn_usbstick.png',
        stack = false,
    },

    hacknet_usbstick = {
        metadata = {},
        category = 'electronics',
        label = 'Glitchy USB Stick',
        description = 'a usb stick',
        weight = 700,
        image = 'hacknet_usbstick.png',
        stack = false,
    },

    iphone = {
        metadata = {},
        category = 'communication',
        label = 'iPhone',
        description = 'Very expensive phone',
        size = { x = 1, y = 2 },
        weight = 1000,
        image = 'iphone.png',
        useable = false,
    },

    samsungphone = {
        metadata = {},
        category = 'communication',
        label = 'Samsung S10',
        description = 'Very expensive phone',
        size = { x = 1, y = 2 },
        weight = 1000,
        image = 'samsungphone.png',
        useable = false,
    },

    laptop = {
        metadata = {},
        category = 'electronics',
        label = 'Laptop',
        description = 'Expensive laptop',
        size = { x = 3, y = 2 },
        weight = 4000,
        image = 'laptop.png',
        useable = false,
    },

    tablet = {
        metadata = {},
        category = 'electronics',
        label = 'Tablet',
        description = 'Expensive tablet',
        size = { x = 2, y = 2 },
        weight = 2000,
        image = 'tablet.png',
        useable = false,
    },

    fitbit = {
        metadata = {},
        category = 'electronics',
        label = 'Fitbit',
        description = 'I like fitbit',
        weight = 500,
        image = 'fitbit.png',
        stack = false,
    },

    radioscanner = {
        metadata = {},
        category = 'communication',
        label = 'Radio Scanner',
        description = 'With this you can get some police alerts. Not 100% effective however',
        size = { x = 1, y = 2 },
        weight = 1000,
        image = 'radioscanner.png',
        useable = false,
    },

    pinger = {
        metadata = {},
        category = 'communication',
        label = 'Pinger',
        description = 'With a pinger and your phone you can send out your location',
        weight = 1000,
        image = 'pinger.png',
        useable = false,
    },

    cryptostick = {
        metadata = {},
        category = 'electronics',
        label = 'Crypto Stick',
        description = 'Why would someone ever buy money that doesn\'t exist.. How many would it contain..?',
        weight = 200,
        image = 'cryptostick.png',
        stack = false,
    },

    deliverytablet = {
        metadata = {},
        category = 'electronics',
        label = 'Delivery Tablet',
        description = 'Tablet for tracking delivery jobs',
        size = { x = 2, y = 2 },
        weight = 2000,
        image = 'tablet.png',
        useable = false,
    },

    -- Theft and Jewelry
    rolex = {
        metadata = {},
        category = 'jewellery',
        label = 'Golden Watch',
        description = 'A golden watch seems like the jackpot to me!',
        weight = 1500,
        image = 'rolex.png',
        useable = false,
    },

    diamond_ring = {
        metadata = {},
        category = 'jewellery',
        label = 'Diamond Ring',
        description = 'A diamond ring seems like the jackpot to me!',
        weight = 1500,
        image = 'diamond_ring.png',
        useable = false,
    },

    diamond = {
        metadata = {},
        category = 'jewellery',
        label = 'Diamond',
        description = 'A diamond seems like the jackpot to me!',
        weight = 1000,
        image = 'diamond.png',
        useable = false,
    },

    goldchain = {
        metadata = {},
        category = 'jewellery',
        label = 'Golden Chain',
        description = 'A golden chain seems like the jackpot to me!',
        weight = 1500,
        image = 'goldchain.png',
        useable = false,
    },

    tenkgoldchain = {
        metadata = {},
        category = 'jewellery',
        label = '10k Gold Chain',
        description = '10 carat golden chain',
        weight = 2000,
        image = '10kgoldchain.png',
        useable = false,
    },

    goldbar = {
        metadata = {},
        category = 'jewellery',
        label = 'Gold Bar',
        description = 'Looks pretty expensive to me',
        weight = 7000,
        image = 'goldbar.png',
        useable = false,
    },

    -- Cops Tools
    armor = {
        metadata = {},
        category = 'equipment',
        label = 'Armor',
        description = 'Some protection won\'t hurt... right?',
        size = { x = 3, y = 3 },
        weight = 5000,
        image = 'armor.png',
    },

    heavyarmor = {
        metadata = {},
        category = 'equipment',
        label = 'Heavy Armor',
        description = 'Some protection won\'t hurt... right?',
        size = { x = 3, y = 3 },
        weight = 5000,
        image = 'armor.png',
    },

    handcuffs = {
        metadata = {},
        category = 'police',
        label = 'Handcuffs',
        description = 'Comes in handy when people misbehave. Maybe it can be used for something else?',
        weight = 100,
        image = 'handcuffs.png',
    },

    police_stormram = {
        metadata = {},
        category = 'police',
        label = 'Stormram',
        description = 'A nice tool to break into doors',
        size = { x = 1, y = 4 },
        weight = 18000,
        image = 'police_stormram.png',
    },

    empty_evidence_bag = {
        metadata = {},
        category = 'police',
        label = 'Empty Evidence Bag',
        description = 'Used a lot to keep DNA from blood, bullet shells and more',
        weight = 0,
        image = 'evidence.png',
        useable = false,
        shouldClose = false,
    },

    filled_evidence_bag = {
        metadata = {},
        category = 'police',
        label = 'Evidence Bag',
        description = 'A filled evidence bag to see who committed the crime >:(',
        weight = 200,
        image = 'evidence.png',
        stack = false,
        useable = false,
        shouldClose = false,
    },

    -- Firework Tools
    firework1 = {
        metadata = {},
        category = 'fireworks',
        label = '2Brothers',
        description = 'Fireworks',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'firework1.png',
    },

    firework2 = {
        metadata = {},
        category = 'fireworks',
        label = 'Poppelers',
        description = 'Fireworks',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'firework2.png',
    },

    firework3 = {
        metadata = {},
        category = 'fireworks',
        label = 'WipeOut',
        description = 'Fireworks',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'firework3.png',
    },

    firework4 = {
        metadata = {},
        category = 'fireworks',
        label = 'Weeping Willow',
        description = 'Fireworks',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'firework4.png',
    },

    -- Sea Tools
    dendrogyra_coral = {
        metadata = {},
        category = 'materials',
        label = 'Dendrogyra',
        description = 'Its also known as pillar coral',
        weight = 1000,
        image = 'dendrogyra_coral.png',
        useable = false,
    },

    antipatharia_coral = {
        metadata = {},
        category = 'materials',
        label = 'Antipatharia',
        description = 'Its also known as black corals or thorn corals',
        weight = 1000,
        image = 'antipatharia_coral.png',
        useable = false,
    },

    diving_gear = {
        metadata = {},
        category = 'diving',
        label = 'Diving Gear',
        description = 'An oxygen tank and a rebreather',
        size = { x = 2, y = 4 },
        weight = 30000,
        image = 'diving_gear.png',
        stack = false,
    },

    diving_fill = {
        metadata = {},
        category = 'diving',
        label = 'Diving Tube',
        description = 'An oxygen tube and a rebreather',
        size = { x = 1, y = 2 },
        weight = 3000,
        image = 'diving_tube.png',
        stack = false,
    },

    -- Other Tools
    casinochips = {
        metadata = {},
        category = 'currency',
        label = 'Casino Chips',
        description = 'Chips For Casino Gambling',
        weight = 0,
        image = 'casinochips.png',
        useable = false,
        shouldClose = false,
    },

    stickynote = {
        metadata = {},
        category = 'misc',
        label = 'Sticky note',
        description = 'Sometimes handy to remember something :)',
        weight = 0,
        image = 'stickynote.png',
        stack = false,
        useable = false,
        shouldClose = false,
    },

    moneybag = {
        metadata = {},
        category = 'currency',
        label = 'Money Bag',
        description = 'A bag with cash',
        size = { x = 2, y = 3 },
        weight = 0,
        image = 'moneybag.png',
        stack = false,
    },

    parachute = {
        metadata = {},
        category = 'equipment',
        label = 'Parachute',
        description = 'The sky is the limit! Woohoo!',
        size = { x = 2, y = 3 },
        weight = 30000,
        image = 'parachute.png',
        stack = false,
    },

    binoculars = {
        metadata = {},
        category = 'equipment',
        label = 'Binoculars',
        description = 'Sneaky Breaky...',
        size = { x = 2, y = 2 },
        weight = 600,
        image = 'binoculars.png',
    },

    lighter = {
        metadata = {},
        category = 'tools',
        label = 'Lighter',
        description = 'On new years eve a nice fire to stand next to',
        weight = 0,
        image = 'lighter.png',
        useable = false,
    },

    certificate = {
        metadata = {},
        category = 'documents',
        label = 'Certificate',
        description = 'Certificate that proves you own certain stuff',
        weight = 0,
        image = 'certificate.png',
        useable = false,
    },

    markedbills = {
        metadata = {},
        category = 'currency',
        label = 'Marked Money',
        description = 'Money?',
        weight = 1000,
        image = 'markedbills.png',
        stack = false,
        useable = false,
    },

    labkey = {
        metadata = {},
        category = 'tools',
        label = 'Key',
        description = 'Key for a lock...?',
        weight = 500,
        image = 'labkey.png',
        stack = false,
    },

    printerdocument = {
        metadata = {},
        category = 'documents',
        label = 'Document',
        description = 'A nice document',
        weight = 500,
        image = 'printerdocument.png',
        stack = false,
    },

    newscam = {
        metadata = {},
        category = 'electronics',
        label = 'News Camera',
        description = 'A camera for the news',
        size = { x = 2, y = 2 },
        weight = 100,
        image = 'newscam.png',
        stack = false,
    },

    newsmic = {
        metadata = {},
        category = 'electronics',
        label = 'News Microphone',
        description = 'A microphone for the news',
        size = { x = 1, y = 2 },
        weight = 100,
        image = 'newsmic.png',
        stack = false,
    },

    newsbmic = {
        metadata = {},
        category = 'electronics',
        label = 'Boom Microphone',
        description = 'A Useable BoomMic',
        size = { x = 1, y = 4 },
        weight = 100,
        image = 'newsbmic.png',
        stack = false,
    },
}

for itemName, itemDefinition in pairs(itemDefinitions) do
    TSSItems[itemName] = itemDefinition
end
