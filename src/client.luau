local RunService = game:GetService 'RunService'

local create_replication = require '../roblox_packages/create_replication'
local replication = require './replication'
local scope = require '../roblox_packages/scope'

if RunService:IsServer() then return {} :: any end

local data_client_class = {}
data_client_class.__index = data_client_class

--[=[
	@class DataClient
	The server-side service for managing player data.
]=]
function data_client_class.new<T>(template: T)
	const self = {
		hasSynced = true,
		_scope = scope(),
	}
	setmetatable(self, data_client_class)

	return self
end

export type client<T = any> = {
	read new: (template: T) -> client<T>,

	read hasSynced: boolean,
	read _scope: scope.Scope,

	read awaitForData: (self: client<T>, callback: (create_replication.value<T>) -> ()) -> () -> (),
	read waitForData: ((self: client<T>) -> create_replication.value<T>) & ((self: client<T>, timeout: number) -> create_replication.value<T>?),
	read get: ((self: client<T>) -> create_replication.value<T>?) & ((self: client<T>, assert_synced: true) -> create_replication.value<T>),
}

--[=[
	@method awaitForData
	@within DataClient
	@param callback (data: value.value<any>) -> ()
	@param timeout number?
	@return () -> ()

	```lua
	local cleanup = player_data.client:awaitForData(function(data)
		print(data.currency())
	end) -- timeout

	cleanup()
	```
]=]
data_client_class['awaitForData' :: never] = function<T>(self: client<T>, callback: (any) -> (), timeout: number?)
	return replication.client:awaitForData(callback, timeout)
end :: any

--[=[
	@method waitForData
	@within DataClient
	@param timeout number?
	@return value.value<any>?
	@yields

	```lua
	-- returns nil if not loaded (only with timeout)
	local data = player_data.client:waitForData()
	print(data.currency())
	```
	
	```lua
	local data = player_data.client:waitForData(5)
	
	if data then
		print(data.currency())
	end
	```
]=]
data_client_class['waitForData' :: never] = function<T>(self: client<T>, timeout: number?)
	return replication.client:waitForData(timeout :: any)
end

--[=[
	@method get
	@within DataClient
	@param assert_synced boolean?
	@return value.value<T>?

	```lua
	-- errors if not loaded
	local playerData = Data.client:get(true)
	playerData.currency(50)
	```

	```lua
	-- returns nil if not loaded
	local data = Data.client:get()
	if data then
		print(data.currency())
	end		
	```
]=]
data_client_class['get' :: never] = function<T>(self: client<T>, assert_synced: boolean?)
	return replication.client
end :: any

return data_client_class
