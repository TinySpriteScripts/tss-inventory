fx_version 'cerulean'
game 'gta5'
lua54 'yes'
version '0.2.0'
description 'A Fivem inventory resource built to use TSS Bridge'
dependency 'tss_bridge'

author 'TinySprite'
shared_scripts { 
    'config.lua', 
    'data/items.lua', 
    'data/containers.lua', 
    'data/vehicles.lua', 
    'data/shops.lua' 
}

server_scripts { 
    'modules/inventory/core.lua', 
    'modules/shops/server.lua', 
    'modules/drops/server.lua',
    'modules/inventory/server.lua' 
}

client_scripts { 
    'modules/inventory/client.lua', 
    'modules/shops/client.lua',
    'modules/drops/client.lua'
}

ui_page 'web/index.html'

files { 
    'web/index.html', 
    'web/style.css', 
    'web/app.js', 
    'web/images/*.png' 
}
