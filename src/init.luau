const RunService = game:GetService 'RunService'

const client = require(script.client)
const server = require(script.server)
const utils = require(script.utils)
const value = require(script.value)

export type Client<T> = client.Client<T>
export type Server<T> = server.DataServiceServer<T>
export type DataOptions<T> = utils.DataOptions<T>
export type Value<T> = value.Value<T>
export type PublicDataServiceServer<T> = server.Public<T>
export type ServerPlayerData<T> = { [Player]: Value<T> } & {
	service: PublicDataServiceServer<T>,
}

const function createPlayerData<T>(options: DataOptions<T>)
	return {
		client = (if RunService:IsClient() then client:init(options.template) else {}) :: Client<T>,
		server = (if RunService:IsServer() then server:init(options) else {}) :: ServerPlayerData<T>,
	}
end

return createPlayerData
