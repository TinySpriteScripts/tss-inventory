Config = Config or {}

Config.TSS = {}
Config.OpenKey = 'TAB'
Config.CellSize = 48 -- identical for every inventory; overflow scrolls

Config.Sounds = {
    enabled = true,
    volume = 0.2, -- default player volume, from 0.0 to 1.0
    actions = {
        move = true,
        equip = true,
        purchase = true,
        reject = true,
    },
}

Config.Rarity = {
    enable = true,
    tiers = {
        common = '#aeb6bf',
        uncommon = '#53bb76',
        rare = '#51a7df',
        epic = '#b778df',
        legendary = '#e8bc50',
    },
}

-- shows these metadata fields in the inventory when right click details
Config.VisibleItemMetadata = {
    usage = {label = "Usage"}, -- metadata key and then the label thats shown in its place
    durability = {label = "Durability", progress = true}, -- progress bars use values from 0 to 100
    rarity = {label = "Rarity"},
}

Config.MaxDimension = 100
Config.MaxCells = 10000

Config.PlayerDefaults = {
    useNamePrefix = true, -- prefixes player inventory with their name in ui
    label = "Inventory", -- players first name inventory
    size = {x = 8, y = 10}, --the default inventory size (must be defined per inventory) (can be resized through exports)
}

-- these slots open as extra windows when your players inventory opens. can be used to store specific items seperate to main inventory
Config.ExtraInventories = {
    backpack_slot = { -- example of exra inv which can hold only backpack
        label = "Backpack",
        size = {x = 2, y = 3},
        whitelist = {'backpack'},
    },

    -- primary_weapon = { -- example rifle storage
    --     label = "Primary Weapon",
    --     size = {x = 4, y = 2},
    --     whitelist = {'weapon_assaultrifle', 'weapon_carbinerifle'},
    -- },
    -- secondary_weapon = { -- example sidearm storage
    --     label = "Secondary Weapon",
    --     size = {x = 2, y = 2},
    --     whitelist = {'weapon_pistol', 'weapon_combatpistol'},
    -- },
    -- melee_weapon = { -- example melee weapon storage
    --     label = "Melee Weapon",
    --     size = {x = 1, y = 4},
    --     whitelist = {'weapon_knife', 'weapon_bat'},
    -- },
}

-- if not defined per item will use this
Config.ItemDefaults = {
    size = {x=1,y=1},
    category = 'misc', -- fallback category for items without one
    weight = 100, -- in grams
    stack = true,
    stackSize = 100,
    shouldClose = true, -- close an open inventory when the item is used
    useable = true, -- just shows the use item in UI. if no script attatched then do nothing
    throwable = true, -- show Take to hand in the context menu; E uses it, R throws it. Normal Use stays immediate.
    throwModel = 'ch_prop_ch_moneybag_01a', -- override per item; weapons automatically use their native weapon model
    metadata = {}, -- never remove this field (you can define specific metadata to items per each item)
}

Config.MoneyAsItem = true -- cash carried in player inventories, extra slots and their containers mirrors the bridge cash account

Config.DynamicContainerWeight = true -- carried containers and equipped slots share the player weight
Config.UseItemsFromContainers = true -- allow using items inside carried containers, including nested containers

Config.DefaultStash = { label = 'Stash', size = {x=8,y=6}, metadata = {} }

Config.FixedStash = {
    Marker = 2, -- nil disables markers; target stashes never draw them
    drawDistance = 5.0, -- marker visibility distance, in metres
}

-- can be overriden by vehicle class or by model itself
Config.VehicleDefaults = {
    trunk = {
        size = {x=5,y=2},   
    },
    glovebox = {
        size = {x=4,y=1},
    },
}

Config.VehicleStorage = {
    interactionDistance = 2.5,
    serverDistance = 7.0, -- includes long vehicles; access is rechecked for every action
    targetScanDistance = 12.0,
}

Config.WorldDrops = {
    enable = true, --if false then dropping an item deletes it forever
    prop = 'ch_prop_ch_moneybag_01a',
    poolDistance = 5.0, -- if items within this distance drop near each other then pool into one inventory and prop (1 world drop)
    openWithTarget = false, -- if true you need to target prop, if false just open your inventory within poolDistance to open the drop window alongside inventory
    size = {x = 8, y = 10}, -- starting grid size; pooled drops can grow within the global grid limits
}

Config.GiveDistance = 3.0 -- maximum distance in metres for nearby item transfers
Config.MaxTransferDistance = 3.0 -- reserved for future world interactions

Config.Throwing = {
    fillTime = 500, -- milliseconds from empty to full power
    drainTime = 500, -- milliseconds from full power back to empty
    idleTimeout = 5000, -- milliseconds before clearing an idle hand; 0 disables
    chargeTimeout = 6800, -- milliseconds allowed holding R; 0 disables
    tapTime = 150, -- shorter presses drop the item near your feet
    minPower = 0.0,
    maxPower = 2.0, -- 1 = original throw distance; 2 = roughly twice that distance
    speed = 13.0, -- original throw velocity at power 1
    lift = 3.5, -- upward lift at power 1
    maxDistance = 70.0, -- maximum allowed landing distance in metres at full power
}

Config.EnableWeaponSystem = true -- false leaves equipping and ammo handling to other resources
Config.WeaponReloadDuration = 1500 -- milliseconds

Config.EnableClothingSystem = true -- false disables clothing controls and appearance changes

Config.CleanUpEmptyInventories = true -- remove empty non-player database inventories once at startup (RECOMMENDED TRUE)
