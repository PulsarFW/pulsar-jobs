fx_version 'cerulean'
game 'gta5'

name 'Pulsar Jobs'
description 'Employment system with job/grade assignment, duty toggling, and salary payout'
author 'Artmines - maintained for Pulsar Framework'
url 'https://pulsarframe.work'
version 'v1.0.0'

version_check 'yes'
github 'https://github.com/PulsarFW/pulsar_jobs'

client_script '@pulsar_core/components/cl_error.lua'
shared_script '@pulsar_core/core/sh_pulsar.lua'
client_script '@pulsar_pwnzor/client/check.lua'

server_scripts({
	'server/**/*.lua',
})

shared_scripts({
	'config/config.lua',
	'config/spawns.lua',
	'config/defaultJobs/*.lua',
})

client_scripts({
	'client/**/*.lua',
})

lua54 'yes'