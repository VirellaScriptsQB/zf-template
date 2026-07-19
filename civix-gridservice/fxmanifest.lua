fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Civix'
description 'Civix Grid Service field-repair job with real electrical cabinet interactions'
version '1.0.0'

shared_scripts {
    'config.lua',
    'shared/items.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'images/*.svg'
}

dependencies {
    'civix-core',
    'civix-interact',
    'civix-inventory',
    'civix-notify',
    'civix-vehiclekeys'
}
