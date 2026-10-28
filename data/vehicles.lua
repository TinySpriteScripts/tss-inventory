-- A model entry replaces its class entry. Use false to disable a compartment.
Config = Config or {}
TSSVehicles = TSSVehicles or {}

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

local vehicleDefinitions = {
    compact = {
        trunk = { label = 'Trunk', size = { x = 5, y = 5 } },
        glovebox = { label = 'Glovebox', size = { x = 4, y = 2 } },
    },
    sedan = {
        trunk = { label = 'Trunk', size = { x = 6, y = 5 } },
        glovebox = { label = 'Glovebox', size = { x = 4, y = 2 } },
    },
    suv = {
        trunk = { label = 'Trunk', size = { x = 8, y = 6 } },
        glovebox = { label = 'Glovebox', size = { x = 4, y = 2 } },
    },
    coupe = {
        trunk = { label = 'Trunk', size = { x = 5, y = 4 } },
        glovebox = { label = 'Glovebox', size = { x = 4, y = 2 } },
    },
    muscle = {
        trunk = { label = 'Trunk', size = { x = 6, y = 5 } },
        glovebox = { label = 'Glovebox', size = { x = 4, y = 2 } },
    },
    sports_classic = {
        trunk = { label = 'Trunk', size = { x = 5, y = 4 } },
        glovebox = { label = 'Glovebox', size = { x = 4, y = 2 } },
    },
    sport = {
        trunk = { label = 'Trunk', size = { x = 5, y = 4 } },
        glovebox = { label = 'Glovebox', size = { x = 4, y = 2 } },
    },
    super = {
        trunk = { label = 'Trunk', size = { x = 4, y = 3 } },
        glovebox = { label = 'Glovebox', size = { x = 3, y = 2 } },
    },
    motorcycle = {
        trunk = { label = 'Trunk', size = { x = 3, y = 3 } },
        glovebox = false,
    },
    offroad = {
        trunk = { label = 'Trunk', size = { x = 8, y = 6 } },
        glovebox = { label = 'Glovebox', size = { x = 4, y = 2 } },
    },
    industrial = {
        trunk = { label = 'Trunk', size = { x = 10, y = 10 } },
        glovebox = { label = 'Glovebox', size = { x = 4, y = 2 } },
    },
    utility = {
        trunk = { label = 'Trunk', size = { x = 8, y = 8 } },
        glovebox = { label = 'Glovebox', size = { x = 4, y = 2 } },
    },
    vans = {
        trunk = { label = 'Trunk', size = { x = 10, y = 8 } },
        glovebox = { label = 'Glovebox', size = { x = 4, y = 2 } },
    },
    cycle = {
        trunk = false,
        glovebox = false,
    },
    boat = {
        trunk = { label = 'Trunk', size = { x = 8, y = 6 } },
        glovebox = { label = 'Glovebox', size = { x = 4, y = 2 } },
    },
    helicopter = {
        trunk = { label = 'Trunk', size = { x = 8, y = 6 } },
        glovebox = { label = 'Glovebox', size = { x = 4, y = 2 } },
    },
    plane = {
        trunk = { label = 'Trunk', size = { x = 10, y = 10 } },
        glovebox = { label = 'Glovebox', size = { x = 4, y = 2 } },
    },
    service = {
        trunk = { label = 'Trunk', size = { x = 8, y = 8 } },
        glovebox = { label = 'Glovebox', size = { x = 4, y = 2 } },
    },
    emergency = {
        trunk = { label = 'Trunk', size = { x = 8, y = 6 } },
        glovebox = { label = 'Glovebox', size = { x = 4, y = 2 } },
    },
    military = {
        trunk = { label = 'Trunk', size = { x = 10, y = 10 } },
        glovebox = { label = 'Glovebox', size = { x = 4, y = 2 } },
    },
    commercial = {
        trunk = { label = 'Trunk', size = { x = 10, y = 15 } },
        glovebox = { label = 'Glovebox', size = { x = 4, y = 2 } },
    },
    train = {
        trunk = false,
        glovebox = false,
    },
    open_wheel = {
        trunk = false,
        glovebox = false,
    },
    sultanrs = {
        class = 6,
        trunk = { label = 'SultanRS Trunk', size = { x = 10, y = 20 } },
        glovebox = false,
    },
}

for vehicleKey, vehicleDefinition in pairs(vehicleDefinitions) do
    TSSVehicles[vehicleKey] = vehicleDefinition
end
