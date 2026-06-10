
fx_version 'cerulean'
lua54 'yes'
game 'gta5'

name 'Advance ATM Robbery'
author 'PulseScripts - pulsescripts.com'
version '2.1.1'

description 'Atm Robbery by PulseScripts https://discord.gg/72Y7WKsP9M'

shared_scripts {
	'@ox_lib/init.lua',
	'shared/config.lua',
	'locales/locale.lua',
}

client_scripts {
	'client/lib.lua',
	'client/utils.lua',
	'client/shop.lua',
	'client/main.lua'
}

server_scripts {
	'server/lib.lua',
	'server/shop.lua',
	'server/main.lua'
}

files {
	'locales/*.lua',
	'locales/*.json'
}

dependency {
	'ox_lib',
	'pl_lib',
}
