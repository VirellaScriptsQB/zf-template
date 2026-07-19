fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Civix'
description 'Civix Electrician field-service job with real street electrical-box repairs'
version '2.0.0'

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
    'oxmysql',
    'civix-core',
    'civix-interact',
    'civix-inventory',
    'civix-notify',
    'civix-vehiclekeys'
}

escrow_ignore {
    'config.lua',
    'shared/items.lua'
}