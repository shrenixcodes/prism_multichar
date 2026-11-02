fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'prism_multichar'
author 'prism_multichar contributors'
description 'Cinematic multi-character selector for Qbox, QBCore and ESX Legacy'
version '0.1.0'

shared_script {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'bridge/client.lua',
    'client/scene.lua',
    'client/camera.lua',
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/server/_common.lua',
    'bridge/server/qbox.lua',
    'bridge/server/qbcore.lua',
    'bridge/server/esx.lua',
    'server/main.lua'
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
    'locales/en.json'
}

dependencies {
    'ox_lib',
    'oxmysql',
    'illenium-appearance'
}
