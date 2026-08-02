const remo = (require) '../remo'

return remo.createRemotes {
	sync = remo.remote(),
	replicate = remo.remote(),
}
