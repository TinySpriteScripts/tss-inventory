Config = Config or {}
Config.TSS = {}
Config.MaxDimension = 40
Config.MaxCells = 800
Config.MaxMetadataBytes = 8192
Config.MaxTransferDistance = 3.0 -- reserved for future world interactions
Config.CellSize = 48 -- identical for every inventory; overflow scrolls
Config.OpenKey = 'TAB'
Config.DefaultStash = { label = 'Stash', size = {x=8,y=6}, metadata = {} }

Config.WorldDrops = {
    enable = true, --if false then dropping an item deletes it forever
    prop = 'ch_prop_ch_moneybag_01a',
    poolDistance = 5.0, -- if items within this distance drop near each other then pool into one inventory and prop (1 world drop)
    openWithTarget = false, -- if true you need to target prop, if false just open your inventory within poolDistance to open the drop window alongside inventory
    size = {x = 8, y = 10}, -- starting grid size; pooled drops can grow within the global grid limits
}

Config.PlayerDefaults = {
    useNamePrefix = true, -- prefixes player inventory with their name in ui
    label = "Inventory", -- players first name inventory
    size = {x = 8, y = 10}, --the default inventory size (must be defined per inventory) (can be resized through exports)
}

-- if not defined per item will use this
Config.ItemDefaults = {
    size = {x=1,y=1},
    category = 'misc', -- not sure what to do with categories so just data atm
    weight = 100, -- in grams
    stack = true,
    stackSize = 100,
    useable = true, -- just shows the use item in UI. if no script attatched then do nothing
    metadata = {}, -- never remove this field (you can define specific metadata to items per each item)
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

-- shows these metadata fields in the inventory when right click details
Config.VisibleItemMetadata = {
    usage = "Usage", -- metadata key and then the label thats shown in its place
    durability = "Durability",
}
