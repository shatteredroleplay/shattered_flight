fx_version 'cerulean'
game 'gta5'

description 'Shattered: realistic flight controls for helicopters and planes'

shared_script 'config.lua'

client_scripts {
	'client/util.lua',
	'client/common.lua',
	'client/input.lua',
	'client/assists.lua',
	'client/flight.lua',
	'client/plane.lua',
	'client/main.lua',
}

lua54 'yes'
