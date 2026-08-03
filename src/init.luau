--!strict
local RunService = game:GetService 'RunService'

local client = require(script.client)
local server = require(script.server)
local utils = require(script.utils)
local value = require(script.value)

export type client<T> = client.client<T>
export type server<T> = server.server<T>
export type value<T> = value.value<T>
export type data_options<T> = utils.data_options<T>

local function createPlayerData<T>(options: data_options<T>)
	return {
		client = (if RunService:IsClient() then client:init(options.template) else {}) :: client<T>,
		server = (if RunService:IsServer() then server:init(options) else {}) :: server<T>,
	}
end

return createPlayerData
