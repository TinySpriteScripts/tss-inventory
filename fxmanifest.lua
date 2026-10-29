fx_version 'cerulean'
game 'gta5'
lua54 'yes'
version '0.2.0'
description 'A Fivem inventory resource built to use TSS Bridge'
dependencies { 'tss_bridge', 'oxmysql' }

author 'TinySprite'
shared_scripts {
    'config.lua',
    'modules/inventory/items.lua',
    'data/items.lua',
    'data/weapons.lua',
    'data/attachments.lua',
    'data/clothing.lua',
    'modules/clothing/definitions.lua',
    'modules/weapons/definitions.lua',
    'data/containers.lua',
    'data/vehicles.lua',
    'data/vehicle_models.lua',
    'data/shops.lua',
    'data/crafting.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'modules/inventory/core.lua',
    'modules/inventory/packing.lua',
    'modules/crafting/server.lua',
    'modules/money/server.lua',
    'modules/weapons/server.lua',
    'modules/weapons/attachments.lua',
    'modules/inventory/database.lua',
    'modules/inventory/weight.lua',
    'modules/inventory/exports.lua',
    'modules/shops/server.lua',
    'modules/drops/server.lua',
    'modules/storage/server.lua',
    'modules/extras/server.lua',
    'modules/clothing/server.lua',
    'modules/inventory/server.lua'
}

client_scripts {
    'modules/inventory/client.lua',
    'modules/shops/client.lua',
    'modules/drops/client.lua',
    'modules/storage/client.lua',
    'modules/weapons/client.lua',
    'modules/weapons/paint.lua',
    'modules/weapons/preview.lua',
    'modules/clothing/client.lua'
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
    'web/images/*.png'
}
