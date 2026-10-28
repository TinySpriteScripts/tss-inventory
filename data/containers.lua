-- will contain all container types and their data

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
        size = {x=5,y=2},
        whitelist = {'id_card', 'cash', 'drivers_license'},
    },
}