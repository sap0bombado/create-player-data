local remo = require '../roblox_packages/remo'

return remo.createRemotes {
	sync = remo.remote(),
	replicate = remo.remote(),
} :: any
