-- Each item file builds a local definition table, then registers it by item name.
-- Values omitted here inherit Config.ItemDefaults.
TSSItems = TSSItems or {}

local itemDefinitions = {
    wallet = {
        label = 'Wallet',
        description = 'Keeps your cash and cards together.',
        size = { x = 1, y = 1 },
        weight = 100,
        image = 'wallet.png',
        stack = false,
        container = 'wallet',
        shouldClose = false,
    },
    backpack = {
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
        image = 'cash.png',
        description = 'Physical cash. Mirrors your cash account when MoneyAsItem is enabled.',
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
    paper = {
        label = "Paper",
        description = "Its Paper",
        image = 'paper.png',
        useable = false,
    },
    comicbook = {
        label = "Comic Book",
        description = "Book",
        image = 'comicbook.png',
        stack = false,
    },

    pistol_ammo = {
        label = 'Pistol ammo',
        description = 'Ammo for Pistols',
        size = { x = 2, y = 1 },
        weight = 200,
        image = 'pistol_ammo.png',
    },

    rifle_ammo = {
        label = 'Rifle ammo',
        description = 'Ammo for Rifles',
        size = { x = 2, y = 1 },
        weight = 1000,
        image = 'rifle_ammo.png',
    },

    smg_ammo = {
        label = 'SMG ammo',
        description = 'Ammo for Sub Machine Guns',
        size = { x = 2, y = 1 },
        weight = 500,
        image = 'smg_ammo.png',
    },

    shotgun_ammo = {
        label = 'Shotgun ammo',
        description = 'Ammo for Shotguns',
        size = { x = 2, y = 1 },
        weight = 500,
        image = 'shotgun_ammo.png',
    },

    mg_ammo = {
        label = 'MG ammo',
        description = 'Ammo for Machine Guns',
        size = { x = 2, y = 1 },
        weight = 1000,
        image = 'mg_ammo.png',
    },

    snp_ammo = {
        label = 'Sniper ammo',
        description = 'Ammo for Sniper Rifles',
        size = { x = 2, y = 1 },
        weight = 1000,
        image = 'rifle_ammo.png',
    },

    emp_ammo = {
        label = 'EMP Ammo',
        description = 'Ammo for EMP Launcher',
        size = { x = 2, y = 1 },
        weight = 200,
        image = 'emp_ammo.png',
    },

    -- Cards
    driver_license = {
        label = 'Drivers License',
        description = 'Permit to show you can drive a vehicle',
        weight = 0,
        image = 'driver_license.png',
        stack = false,
        shouldClose = false,
    },

    lawyerpass = {
        label = 'Lawyer Pass',
        description = 'Pass exclusive to lawyers to show they can represent a suspect',
        weight = 0,
        image = 'lawyerpass.png',
        stack = false,
        shouldClose = false,
    },

    weaponlicense = {
        label = 'Weapon License',
        description = 'Weapon License',
        weight = 0,
        image = 'weapon_license.png',
        stack = false,
    },

    bank_card = {
        label = 'Bank Card',
        description = 'Used to access ATM',
        weight = 0,
        image = 'bank_card.png',
        stack = false,
    },

    security_card_01 = {
        label = 'Security Card A',
        description = 'A security card... I wonder what it goes to',
        weight = 0,
        image = 'security_card_01.png',
    },

    security_card_02 = {
        label = 'Security Card B',
        description = 'A security card... I wonder what it goes to',
        weight = 0,
        image = 'security_card_02.png',
    },

    -- Food
    tosti = {
        label = 'Grilled Cheese Sandwich',
        description = 'Nice to eat',
        size = { x = 2, y = 1 },
        weight = 200,
        image = 'tosti.png',
    },

    twerks_candy = {
        label = 'Twerks',
        description = 'Some delicious candy :O',
        weight = 100,
        image = 'twerks_candy.png',
    },

    snikkel_candy = {
        label = 'Snikkel',
        description = 'Some delicious candy :O',
        weight = 100,
        image = 'snikkel_candy.png',
    },

    -- Drinks
    coffee = {
        label = 'Coffee',
        description = 'Pump 4 Caffeine',
        size = { x = 1, y = 2 },
        weight = 200,
        image = 'coffee.png',
    },

    kurkakola = {
        label = 'Cola',
        description = 'For all the thirsty out there',
        size = { x = 1, y = 2 },
        weight = 500,
        image = 'cola.png',
    },

    -- Alcohol
    beer = {
        label = 'Beer',
        description = 'Nothing like a good cold beer!',
        size = { x = 1, y = 2 },
        weight = 500,
        image = 'beer.png',
    },

    whiskey = {
        label = 'Whiskey',
        description = 'For all the thirsty out there',
        size = { x = 1, y = 2 },
        weight = 500,
        image = 'whiskey.png',
    },

    vodka = {
        label = 'Vodka',
        description = 'For all the thirsty out there',
        size = { x = 1, y = 2 },
        weight = 500,
        image = 'vodka.png',
    },

    grape = {
        label = 'Grape',
        description = 'Mmmmh yummie, grapes',
        weight = 100,
        image = 'grape.png',
        shouldClose = false,
    },

    wine = {
        label = 'Wine',
        description = 'Some good wine to drink on a fine evening',
        size = { x = 1, y = 2 },
        weight = 300,
        image = 'wine.png',
        shouldClose = false,
    },

    grapejuice = {
        label = 'Grape Juice',
        description = 'Grape juice is said to be healthy',
        size = { x = 1, y = 2 },
        weight = 200,
        image = 'grapejuice.png',
        shouldClose = false,
    },

    -- Drugs
    joint = {
        label = 'Joint',
        description = 'Sidney would be very proud at you',
        weight = 0,
        image = 'joint.png',
    },

    cokebaggy = {
        label = 'Bag of Coke',
        description = 'To get happy real quick',
        weight = 0,
        image = 'cocaine_baggy.png',
    },

    crack_baggy = {
        label = 'Bag of Crack',
        description = 'To get happy faster',
        weight = 0,
        image = 'crack_baggy.png',
    },

    xtcbaggy = {
        label = 'Bag of XTC',
        description = 'Pop those pills baby',
        weight = 0,
        image = 'xtc_baggy.png',
    },

    coke_brick = {
        label = 'Coke Brick',
        description = 'Heavy package of cocaine, mostly used for deals and takes a lot of space',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'coke_brick.png',
        stack = false,
        useable = false,
    },

    weed_brick = {
        label = 'Weed Brick',
        description = '1KG Weed Brick to sell to large customers.',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'weed_brick.png',
        useable = false,
    },

    coke_small_brick = {
        label = 'Coke Package',
        description = 'Small package of cocaine, mostly used for deals and takes a lot of space',
        size = { x = 2, y = 1 },
        weight = 350,
        image = 'coke_small_brick.png',
        stack = false,
        useable = false,
    },

    oxy = {
        label = 'Prescription Oxy',
        description = 'The Label Has Been Ripped Off',
        weight = 0,
        image = 'oxy.png',
    },

    meth = {
        label = 'Meth',
        description = 'A baggie of Meth',
        weight = 100,
        image = 'meth_baggy.png',
    },

    rolling_paper = {
        label = 'Rolling Paper',
        description = 'Paper made specifically for encasing and smoking tobacco or cannabis.',
        weight = 0,
        image = 'rolling_paper.png',
        useable = false,
    },

    empty_weed_bag = {
        label = 'Empty Weed Bag',
        description = 'A small empty bag',
        weight = 0,
        image = 'weed_baggy_empty.png',
    },

    weed_nutrition = {
        label = 'Plant Fertilizer',
        description = 'Plant nutrition',
        size = { x = 1, y = 2 },
        weight = 2000,
        image = 'weed_nutrition.png',
    },

    weed = {
        label = 'Weed 2g',
        description = 'A weed bag with 2g',
        weight = 200,
        image = 'weed_baggy.png',
        shouldClose = false,
    },

    -- Material
    metalscrap = {
        label = 'Metal Scrap',
        description = 'You can probably make something nice out of this',
        weight = 100,
        image = 'metalscrap.png',
        useable = false,
        shouldClose = false,
    },

    copper = {
        label = 'Copper',
        description = 'Nice piece of metal that you can probably use for something',
        weight = 100,
        image = 'copper.png',
        useable = false,
        shouldClose = false,
    },

    aluminum = {
        label = 'Aluminium',
        description = 'Nice piece of metal that you can probably use for something',
        weight = 100,
        image = 'aluminum.png',
        useable = false,
        shouldClose = false,
    },

    aluminumoxide = {
        label = 'Aluminium Powder',
        description = 'Some powder to mix with',
        weight = 100,
        image = 'aluminumoxide.png',
        useable = false,
        shouldClose = false,
    },

    iron = {
        label = 'Iron',
        description = 'Handy piece of metal that you can probably use for something',
        weight = 100,
        image = 'iron.png',
        useable = false,
        shouldClose = false,
    },

    ironoxide = {
        label = 'Iron Powder',
        description = 'Some powder to mix with.',
        weight = 100,
        image = 'ironoxide.png',
        useable = false,
        shouldClose = false,
    },

    steel = {
        label = 'Steel',
        description = 'Nice piece of metal that you can probably use for something',
        weight = 100,
        image = 'steel.png',
        useable = false,
        shouldClose = false,
    },

    rubber = {
        label = 'Rubber',
        description = 'Rubber, I believe you can make your own rubber ducky with it :D',
        weight = 100,
        image = 'rubber.png',
        useable = false,
        shouldClose = false,
    },

    glass = {
        label = 'Glass',
        description = 'It is very fragile, watch out',
        weight = 100,
        image = 'glass.png',
        useable = false,
        shouldClose = false,
    },

    -- Tools
    lockpick = {
        label = 'Lockpick',
        description = 'Very useful if you lose your keys a lot.. or if you want to use it for something else...',
        weight = 300,
        image = 'lockpick.png',
    },

    advancedlockpick = {
        label = 'Advanced Lockpick',
        description = 'If you lose your keys a lot this is very useful... Also useful to open your beers',
        weight = 500,
        image = 'advancedlockpick.png',
    },

    electronickit = {
        label = 'Electronic Kit',
        description = 'If you\'ve always wanted to build a robot you can maybe start here. Maybe you\'ll be the new Elon Musk?',
        size = { x = 2, y = 2 },
        weight = 100,
        image = 'electronickit.png',
    },

    gatecrack = {
        label = 'Gatecrack',
        description = 'Handy software to tear down some fences',
        size = { x = 2, y = 2 },
        weight = 0,
        image = 'usb_device.png',
        useable = false,
    },

    thermite = {
        label = 'Thermite',
        description = 'Sometimes you\'d wish for everything to burn',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'thermite.png',
    },

    trojan_usb = {
        label = 'Trojan USB',
        description = 'Handy software to shut down some systems',
        weight = 0,
        image = 'usb_device.png',
        useable = false,
    },

    screwdriverset = {
        label = 'Toolkit',
        description = 'Very useful to screw... screws...',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'screwdriverset.png',
        useable = false,
        shouldClose = false,
    },

    drill = {
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
        label = 'Nitrous',
        description = 'Speed up, gas pedal! :D',
        size = { x = 1, y = 2 },
        weight = 1000,
        image = 'nitrous.png',
    },

    repairkit = {
        label = 'Repairkit',
        description = 'A nice toolbox with stuff to repair your vehicle',
        size = { x = 2, y = 2 },
        weight = 2500,
        image = 'repairkit.png',
    },

    advancedrepairkit = {
        label = 'Advanced Repairkit',
        description = 'A nice toolbox with stuff to repair your vehicle',
        size = { x = 2, y = 2 },
        weight = 4000,
        image = 'advancedkit.png',
    },

    cleaningkit = {
        label = 'Cleaning Kit',
        description = 'A microfiber cloth with some soap will let your car sparkle again!',
        size = { x = 2, y = 2 },
        weight = 250,
        image = 'cleaningkit.png',
    },

    tunerlaptop = {
        label = 'Tunerchip',
        description = 'With this tunerchip you can get your car on steroids... If you know what you\'re doing',
        size = { x = 3, y = 2 },
        weight = 2000,
        image = 'tunerchip.png',
        stack = false,
    },

    harness = {
        label = 'Race Harness',
        description = 'Racing Harness so no matter what you stay in the car',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'harness.png',
        stack = false,
    },

    jerry_can = {
        label = 'Jerrycan 20L',
        description = 'A can full of Fuel',
        size = { x = 2, y = 3 },
        weight = 20000,
        image = 'jerry_can.png',
    },

    tirerepairkit = {
        label = 'Tire Repair Kit',
        description = 'A kit to repair your tires',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'tirerepairkit.png',
    },

    -- Mechanic Parts
    veh_toolbox = {
        label = 'Toolbox',
        description = 'Check vehicle status',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'veh_toolbox.png',
    },

    veh_armor = {
        label = 'Armor',
        description = 'Upgrade vehicle armor',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'veh_armor.png',
    },

    veh_brakes = {
        label = 'Brakes',
        description = 'Upgrade vehicle brakes',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'veh_brakes.png',
    },

    veh_engine = {
        label = 'Engine',
        description = 'Upgrade vehicle engine',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'veh_engine.png',
    },

    veh_suspension = {
        label = 'Suspension',
        description = 'Upgrade vehicle suspension',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'veh_suspension.png',
    },

    veh_transmission = {
        label = 'Transmission',
        description = 'Upgrade vehicle transmission',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'veh_transmission.png',
    },

    veh_turbo = {
        label = 'Turbo',
        description = 'Install vehicle turbo',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'veh_turbo.png',
    },

    veh_interior = {
        label = 'Interior',
        description = 'Upgrade vehicle interior',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'veh_interior.png',
    },

    veh_exterior = {
        label = 'Exterior',
        description = 'Upgrade vehicle exterior',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'veh_exterior.png',
    },

    veh_wheels = {
        label = 'Wheels',
        description = 'Upgrade vehicle wheels',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'veh_wheels.png',
    },

    veh_neons = {
        label = 'Neons',
        description = 'Upgrade vehicle neons',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'veh_neons.png',
    },

    veh_xenons = {
        label = 'Xenons',
        description = 'Upgrade vehicle xenons',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'veh_xenons.png',
    },

    veh_tint = {
        label = 'Tints',
        description = 'Install vehicle tint',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'veh_tint.png',
    },

    veh_plates = {
        label = 'Plates',
        description = 'Install vehicle plates',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'veh_plates.png',
    },

    -- Medication
    firstaid = {
        label = 'First Aid',
        description = 'You can use this First Aid kit to get people back on their feet',
        size = { x = 2, y = 2 },
        weight = 2500,
        image = 'firstaid.png',
    },

    ifaks = {
        label = 'ifaks',
        description = 'ifaks for healing and a complete stress remover.',
        size = { x = 2, y = 2 },
        weight = 200,
        image = 'ifaks.png',
    },

    painkillers = {
        label = 'Painkillers',
        description = 'For pain you can\'t stand anymore, take this pill that\'d make you feel great again',
        weight = 0,
        image = 'painkillers.png',
    },

    walkstick = {
        label = 'Walking Stick',
        description = 'Walking stick for ya\'ll grannies out there.. HAHA',
        size = { x = 1, y = 4 },
        weight = 1000,
        image = 'walkstick.png',
    },

    -- Communication
    tssphone = {
        label = 'Sprite Phone',
        description = 'Latest sprite phone model',
        size = { x = 1, y = 2 },
        weight = 700,
        image = 'tssphone.png',
        stack = false,
    },

    tssphone_powerbank = {
        label = 'Power Bank',
        description = 'Juice Up Your Phones battery',
        weight = 700,
        image = 'tssphone_powerbank.png',
        stack = false,
    },

    vpn_usbstick = {
        label = 'VPN USB Stick',
        description = 'a usb stick',
        weight = 700,
        image = 'vpn_usbstick.png',
        stack = false,
    },

    hacknet_usbstick = {
        label = 'Glitchy USB Stick',
        description = 'a usb stick',
        weight = 700,
        image = 'hacknet_usbstick.png',
        stack = false,
    },

    iphone = {
        label = 'iPhone',
        description = 'Very expensive phone',
        size = { x = 1, y = 2 },
        weight = 1000,
        image = 'iphone.png',
        useable = false,
    },

    samsungphone = {
        label = 'Samsung S10',
        description = 'Very expensive phone',
        size = { x = 1, y = 2 },
        weight = 1000,
        image = 'samsungphone.png',
        useable = false,
    },

    laptop = {
        label = 'Laptop',
        description = 'Expensive laptop',
        size = { x = 3, y = 2 },
        weight = 4000,
        image = 'laptop.png',
        useable = false,
    },

    tablet = {
        label = 'Tablet',
        description = 'Expensive tablet',
        size = { x = 2, y = 2 },
        weight = 2000,
        image = 'tablet.png',
        useable = false,
    },

    fitbit = {
        label = 'Fitbit',
        description = 'I like fitbit',
        weight = 500,
        image = 'fitbit.png',
        stack = false,
    },

    radioscanner = {
        label = 'Radio Scanner',
        description = 'With this you can get some police alerts. Not 100% effective however',
        size = { x = 1, y = 2 },
        weight = 1000,
        image = 'radioscanner.png',
        useable = false,
    },

    pinger = {
        label = 'Pinger',
        description = 'With a pinger and your phone you can send out your location',
        weight = 1000,
        image = 'pinger.png',
        useable = false,
    },

    cryptostick = {
        label = 'Crypto Stick',
        description = 'Why would someone ever buy money that doesn\'t exist.. How many would it contain..?',
        weight = 200,
        image = 'cryptostick.png',
        stack = false,
    },

    deliverytablet = {
        label = 'Delivery Tablet',
        description = 'Tablet for tracking delivery jobs',
        size = { x = 2, y = 2 },
        weight = 2000,
        image = 'tablet.png',
        useable = false,
    },

    -- Theft and Jewelry
    rolex = {
        label = 'Golden Watch',
        description = 'A golden watch seems like the jackpot to me!',
        weight = 1500,
        image = 'rolex.png',
        useable = false,
    },

    diamond_ring = {
        label = 'Diamond Ring',
        description = 'A diamond ring seems like the jackpot to me!',
        weight = 1500,
        image = 'diamond_ring.png',
        useable = false,
    },

    diamond = {
        label = 'Diamond',
        description = 'A diamond seems like the jackpot to me!',
        weight = 1000,
        image = 'diamond.png',
        useable = false,
    },

    goldchain = {
        label = 'Golden Chain',
        description = 'A golden chain seems like the jackpot to me!',
        weight = 1500,
        image = 'goldchain.png',
        useable = false,
    },

    tenkgoldchain = {
        label = '10k Gold Chain',
        description = '10 carat golden chain',
        weight = 2000,
        image = '10kgoldchain.png',
        useable = false,
    },

    goldbar = {
        label = 'Gold Bar',
        description = 'Looks pretty expensive to me',
        weight = 7000,
        image = 'goldbar.png',
        useable = false,
    },

    -- Cops Tools
    armor = {
        label = 'Armor',
        description = 'Some protection won\'t hurt... right?',
        size = { x = 3, y = 3 },
        weight = 5000,
        image = 'armor.png',
    },

    heavyarmor = {
        label = 'Heavy Armor',
        description = 'Some protection won\'t hurt... right?',
        size = { x = 3, y = 3 },
        weight = 5000,
        image = 'armor.png',
    },

    handcuffs = {
        label = 'Handcuffs',
        description = 'Comes in handy when people misbehave. Maybe it can be used for something else?',
        weight = 100,
        image = 'handcuffs.png',
    },

    police_stormram = {
        label = 'Stormram',
        description = 'A nice tool to break into doors',
        size = { x = 1, y = 4 },
        weight = 18000,
        image = 'police_stormram.png',
    },

    empty_evidence_bag = {
        label = 'Empty Evidence Bag',
        description = 'Used a lot to keep DNA from blood, bullet shells and more',
        weight = 0,
        image = 'evidence.png',
        useable = false,
        shouldClose = false,
    },

    filled_evidence_bag = {
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
        label = '2Brothers',
        description = 'Fireworks',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'firework1.png',
    },

    firework2 = {
        label = 'Poppelers',
        description = 'Fireworks',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'firework2.png',
    },

    firework3 = {
        label = 'WipeOut',
        description = 'Fireworks',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'firework3.png',
    },

    firework4 = {
        label = 'Weeping Willow',
        description = 'Fireworks',
        size = { x = 2, y = 2 },
        weight = 1000,
        image = 'firework4.png',
    },

    -- Sea Tools
    dendrogyra_coral = {
        label = 'Dendrogyra',
        description = 'Its also known as pillar coral',
        weight = 1000,
        image = 'dendrogyra_coral.png',
        useable = false,
    },

    antipatharia_coral = {
        label = 'Antipatharia',
        description = 'Its also known as black corals or thorn corals',
        weight = 1000,
        image = 'antipatharia_coral.png',
        useable = false,
    },

    diving_gear = {
        label = 'Diving Gear',
        description = 'An oxygen tank and a rebreather',
        size = { x = 2, y = 4 },
        weight = 30000,
        image = 'diving_gear.png',
        stack = false,
    },

    diving_fill = {
        label = 'Diving Tube',
        description = 'An oxygen tube and a rebreather',
        size = { x = 1, y = 2 },
        weight = 3000,
        image = 'diving_tube.png',
        stack = false,
    },

    -- Other Tools
    casinochips = {
        label = 'Casino Chips',
        description = 'Chips For Casino Gambling',
        weight = 0,
        image = 'casinochips.png',
        useable = false,
        shouldClose = false,
    },

    stickynote = {
        label = 'Sticky note',
        description = 'Sometimes handy to remember something :)',
        weight = 0,
        image = 'stickynote.png',
        stack = false,
        useable = false,
        shouldClose = false,
    },

    moneybag = {
        label = 'Money Bag',
        description = 'A bag with cash',
        size = { x = 2, y = 3 },
        weight = 0,
        image = 'moneybag.png',
        stack = false,
    },

    parachute = {
        label = 'Parachute',
        description = 'The sky is the limit! Woohoo!',
        size = { x = 2, y = 3 },
        weight = 30000,
        image = 'parachute.png',
        stack = false,
    },

    binoculars = {
        label = 'Binoculars',
        description = 'Sneaky Breaky...',
        size = { x = 2, y = 2 },
        weight = 600,
        image = 'binoculars.png',
    },

    lighter = {
        label = 'Lighter',
        description = 'On new years eve a nice fire to stand next to',
        weight = 0,
        image = 'lighter.png',
        useable = false,
    },

    certificate = {
        label = 'Certificate',
        description = 'Certificate that proves you own certain stuff',
        weight = 0,
        image = 'certificate.png',
        useable = false,
    },

    markedbills = {
        label = 'Marked Money',
        description = 'Money?',
        weight = 1000,
        image = 'markedbills.png',
        stack = false,
        useable = false,
    },

    labkey = {
        label = 'Key',
        description = 'Key for a lock...?',
        weight = 500,
        image = 'labkey.png',
        stack = false,
    },

    printerdocument = {
        label = 'Document',
        description = 'A nice document',
        weight = 500,
        image = 'printerdocument.png',
        stack = false,
    },

    newscam = {
        label = 'News Camera',
        description = 'A camera for the news',
        size = { x = 2, y = 2 },
        weight = 100,
        image = 'newscam.png',
        stack = false,
    },

    newsmic = {
        label = 'News Microphone',
        description = 'A microphone for the news',
        size = { x = 1, y = 2 },
        weight = 100,
        image = 'newsmic.png',
        stack = false,
    },

    newsbmic = {
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
