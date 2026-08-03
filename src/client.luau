local RunService = game:GetService 'RunService'

local network = require './network'
local signal = (require) '../roblox_packages/signal'
local value = require './value'

if RunService:IsServer() then return {} :: any end

local data_service_client = {
	hasSynced = false,
	playerDataSynced = signal<<()>>(),
}

function data_service_client.init<T>(self: self, template: T): client<T>
	self.data = value.new {}

	network.sync:connect(function(data: T)
		self:_load(data)
	end)

	network.replicate:connect(function(replicateType: string, path: { string }, ...: any)
		if replicateType == 'set' then
			self:_set(path, ...)
		elseif replicateType == 'insert' then
			self:_insert(path, ...)
		elseif replicateType == 'remove' then
			self:_remove(path, ...)
		end
	end)

	if not RunService:IsRunning() then self:_load(template) end

	return self :: any
end

export type self = typeof(data_service_client)

function data_service_client._load<T>(self: self, data: T)
	if self.hasSynced then return end

	local raw = self.data()
	for k, v in data :: any do
		raw[k] = v
	end

	self.hasSynced = true
	self.playerDataSynced:fire()
end

function data_service_client:use(callback: (any) -> ())
	if self.hasSynced then
		task.spawn(callback, self.data)
	else
		self.playerDataSynced:once(function()
			task.spawn(callback, self.data)
		end)
	end
end

function data_service_client:get(assert_synced: boolean?)
	if assert_synced == true and self.hasSynced == false then error(`Player data has not synced yet. Use playerDataSynced:wait() to wait for it.`) end

	return self.data
end

function data_service_client._get_with_path<T>(self: self, path: { string }): value.value<any>
	if not self.hasSynced then self.playerDataSynced:wait() end

	local current = self.data
	for i = #path, 2, -1 do
		local key = path[i]
		current = (current :: any)[key]
	end

	return current[path[1]]
end

function data_service_client._set<T>(self: self, path: { string }, value: any?)
	self:_get_with_path(path)(value)
end

function data_service_client._insert<T>(self: self, path: { string }, item: any, pos: number?)
	self:_get_with_path(path).Insert(item, pos)
end

function data_service_client._remove<T>(self: self, path: { string }, pos: number?)
	self:_get_with_path(path).Remove(pos)
end

export type data_controller<T> = self & {
	use: (self: data_controller<T>, callback: (value.value<T>) -> ()) -> (),
	get: ((self: data_controller<T>) -> value.value<T>?) & ((self: data_controller<T>, assert_synced: true) -> value.value<T>),
}

export type client<T> = data_controller<T>

return data_service_client
