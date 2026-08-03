--!strict
const RunService = game:GetService 'RunService'

const client = require(script.client)
const server = require(script.server)
const utils = require(script.utils)
const value = require(script.value)

export type client<T> = client.client<T>
export type server<T> = server.server<T>
export type value<T> = value.value<T>
export type data_options<T> = utils.data_options<T>

const function createPlayerData<T>(options: data_options<T>)
	return {
		client = (if RunService:IsClient() then client:init(options.template) else {}) :: client<T>,
		server = (if RunService:IsServer() then server:init(options) else {}) :: server<T>,
	}
end

return createPlayerData
