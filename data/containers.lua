-- Without coords: carried containers. With coords: fixed stashes. With items: rolled loot containers.

TSSContainers = TSSContainers or {
    backpack = {
        label = "Backpack",
        size = {x=8,y=8},
        -- use only whitelist or blacklist. do not use both
        whitelist = {}, -- only certain items allowed in ,all others not allowed
        blacklist = { 'backpack' }, -- wallets can go inside; backpacks cannot
        metadata = {}, -- metadata can be applied to inventories themselves to store extra data
    },
    wallet = {
        label = "Wallet",
        size = {x=5,y=1},
        whitelist = {'id_card', 'cash', 'drivers_license'},
    },
    test_static_stash = {
        label = "Shared Stash Test",
        size = {x=20,y=10},
        coords = vector3(760.24, 1280.56, 360.3),
        distance = 2.0, -- distance from the stash coordinates
        target = false, -- use the nearby marker instead of a target
        openWhenNearby = true, -- include this stash when pressing TAB nearby
        shared = true, -- true: shared contents; false: a separate stash for each character
        metadata = {}
    },
    stolen_wallet = { --maybe for when robbing peds or cars
        label = "Stolen Wallet",
        size = {x=5,y=1},
        items = { --becomes a loot container
            cash = { amount = { min = 1, max = 100 }, chance = 100 },
            lockpick = {amount = { min = 1, max = 2}, chance = 10 },
        },
        maxItems = { min = 1, max = 2 },
        deleteOnEmpty = true,
    }
}