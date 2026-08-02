--!nolint
const RunService = game:GetService 'RunService'

const network = require './network'
const signal = (require) '../signal'
const value = require './value'

if RunService:IsServer() then return {} :: any end

const data_service_client = {
	hasLoaded = false,
	playerDataSynced = signal<<()>>(),
}

function data_service_client.init<T>(self: self, template: T): Client<T>
	self.data = value.new {}
	self.data.controller = self

	network.sync:connect(function(data: T)
		self:load(data)
	end)

	network.replicate:connect(function(replicateType: string, path: { string }, ...: any)
		if replicateType == 'set' then
			self:set(path, ...)
		elseif replicateType == 'insert' then
			self:insert(path, ...)
		elseif replicateType == 'remove' then
			self:remove(path, ...)
		end
	end)

	if not RunService:IsRunning() then self:load(template) end

	return self.data
end

export type self = typeof(data_service_client)

function data_service_client.load<T>(self: self, data: T)
	if self.hasLoaded then return end

	const raw = self.data()
	for k, v in data :: any do
		raw[k] = v
	end

	self.hasLoaded = true
	self.playerDataSynced:fire()
end

function data_service_client.get<T>(self: self, path: { string }): value.value<any>
	if not self.hasLoaded then self.playerDataSynced:wait() end

	local current = self.data
	for i = #path, 2, -1 do
		const key = path[i]
		current = (current :: any)[key]
	end

	return current[path[1]]
end

function data_service_client.set<T>(self: self, path: { string }, value: any?)
	self:get(path)(value)
end

function data_service_client.insert<T>(self: self, path: { string }, item: any, pos: number?)
	self:get(path).Insert(item, pos)
end

function data_service_client.remove<T>(self: self, path: { string }, pos: number?)
	self:get(path).Remove(pos)
end

export type data_controller = self

export type client<T> = value.value<T> & {
	controller: data_controller,
}

return data_service_client
