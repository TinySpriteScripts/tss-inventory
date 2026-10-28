 -- will contain all data related to vehicle inventories
Config = Config or {}

-- no need to edit unless youve forced extra classes
Config.VehicleClasses = {
    compact = 0,
    sedan = 1,
    suv = 2,
    coupe = 3,
    muscle = 4,
    sports_classic = 5,
    sport = 6,
    super = 7,
    motorcycle = 8,
    offroad = 9,
    industrial = 10,
    utility = 11,
    vans = 12,
    cycle = 13,
    boat = 14,
    helicopter = 15,
    plane = 16,
    service = 17,
    emergency = 18,
    military = 19,
    commercial = 20,
    train = 21,
    open_wheel = 22,
}

TSSVehicles = TSSVehicles or {
    compact = { -- example of vehicle class which can be overriden by a specific vehicle model name
        trunk = { -- if nil then no trunkk available on these vehicles
            label = "Trunk",
            size = {x=5,y=5},
            whitelist = {},
            blacklist = {},
        },
        glovebox = {
            label = "Glovebox",
            size = {x=4,y=2},
            whitelist = {},
            blacklist = {},
        },
    },
    sultanrs = {
        trunk = {
            label = "SultanRS Trunk",
            size = {x=10,y=20},
            whitelist = {},
            blacklist = {},
        },
        glovebox = nil, -- overrides vehicle class so it has no glovebox
    }
}
