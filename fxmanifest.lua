fx_version 'cerulean'
game 'gta5'
author 'A R d x'
description 'Advanced Gudang System (ESX & Ox)'
version '1.0.0'
lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    '@es_extended/imports.lua', -- Opsional: Membantu import fungsi ESX
    'shared/*.lua',
}

client_scripts {
    'client/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua'
}

dependencies {
    'es_extended',
    'ox_lib',
    'ox_inventory',
    'ox_target',
    'oxmysql'
}