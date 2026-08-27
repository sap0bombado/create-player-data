--!strict
local RunService = game:GetService 'RunService'

local client = require '@self/client'
local create_replication = require './roblox_packages/create_replication'
local server = require '@self/server'
local utils = require '@self/utils'

export type client<T> = client.client<T>
export type server<T> = server.server<T>
export type value<T> = create_replication.value<T>
export type data_options<T> = utils.data_options<T>

local created = false

local function createPlayerData<T>(options: data_options<T> | any)
	assert(not created, '')

	local player_data = {
		client = (if RunService:IsClient() then client.new(options.template) else {}) :: client<T>,
		server = (if RunService:IsServer() then server.new(options) else {}) :: server<T>,
	}

	created = true

	return player_data
end

return createPlayerData
