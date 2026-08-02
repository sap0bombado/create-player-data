const Players = game:GetService 'Players'
const RunService = game:GetService 'RunService'

if RunService:IsClient() then return {} :: any end

const utils = require './utils'
const value = require './value'
const network = require './network'
const signal = (require) '../signal'

const profile_store = if RunService:IsServer() then (require) '../profile_store' else nil :: any

local DATA_PREFIX = 'PLAYER_'
local DEFAULT_PROFILE_STORE_INDEX = 'Default'

--[=[
	@type DataTemplate { [string]: any }
	@within DataServiceServer
	
	Defines the structure of player data used by the DataServiceServer.

	```lua
	local datatemplate = {
		currency = 0,
		inventory = {
			apples = 5,
			oranges = 10,
		},
		settings = {
			music = true,
		},
		items = {} :: { [string]: ItemData },
		array = {} :: { number },
	}
	```

	
	:::note
	Player data automatically reconciles the template on join if new keys are added.
	:::
	:::warning
	Follow JSON rules for all data. (e.g., no Vector3, CFrame, etc.)
	:::
]=]
type DataTemplate = { [string | number]: any }

--[=[
	@interface DataOptions
	@within DataServiceServer
	.template DataTemplate -- Template dictionary for player data.
	.profileStoreIndex string -- Index for the ProfileStore.
	.useMock boolean? -- Use Mock data for testing.
	.viewedUserId number? -- User ID to view data for. Use to view a specific player's data without saving.
	.overridenUserId number? -- User ID to override for the profile. Use to play on another player's save.
	.dontSave boolean? -- Prevent saving the profile. Use for testing without saving.
	.resetData boolean? -- Reset the data on player join. Use to wipe data for testing.
	
	```lua
	local options = {
		template = require(path.to.datatemplate),
		profileStoreIndex = "Public",
	}
	```

	Provides options for initializing the DataServiceServer.
]=]
type DataOptions<T> = utils.data_options<T>
type MessageData = { key: string, data: { any } }

const data_service = {
	_profiles = {} :: any,
	_loading = {} :: { [Player]: boolean },
	_sessions = {} :: { [Player]: boolean },
	_wait_signals = {} :: { [Player]: signal.Signal<any> },
	_removal_functions = {} :: { (player: Player, data: any) -> () },
	_pending_message_waits = {} :: { [Player]: { any } },
	_global_callbacks = {} :: { [string]: (player: Player, { any }) -> boolean? },
	_global_callback_added = signal() :: signal.Signal<string>,

	playerDataLoaded = signal() :: signal.Signal<Player>,
	playerDataFailed = signal() :: signal.Signal<Player, string>,
	playerDataEnded = signal() :: signal.Signal<Player>,

	data = {} :: { [Player]: value.value<any> & { service: self } },
}

--[=[
	@class DataServiceServer
	The server-side service for managing player data.
]=]
function data_service.init<T>(self: self, options: DataOptions<T>)
	assert(RunService:IsServer(), 'DataServiceServer can only be used on the server.')

	value.shouldRecordPath = true
	self.options = options
	self.playerStore = profile_store.New(options.profileStoreIndex or DEFAULT_PROFILE_STORE_INDEX, options.template)

	Players.PlayerRemoving:Connect(function(player: Player)
		self:_on_player_removing(player)
	end);

	(self.data :: any).service = self

	return self.data
end

export type self = typeof(data_service)

local function storeCancel(player: Player)
	return {
		Cancel = function()
			return player.Parent ~= Players
		end,
	}
end

--[=[
	@method loadPlayer
	@within DataServiceServer
	@yields
	@param player Player
	@return boolean

	Loads the player's data, starting a ProfileStore session and making it
	available through `data[player]`. Idempotent: if the player is already
	loaded, it returns `true` immediately.

	```lua
	local ok = Data.service:loadPlayer(player)
	if not ok then
		-- playerDataFailed already fired
	end
	```
]=]
function data_service.loadPlayer(self: self, player: Player): boolean
	if self.data[player] ~= nil then return true end

	if self._loading[player] then
		local waitSignal = self._wait_signals[player]
		if waitSignal then
			waitSignal:wait()
			return self.data[player] ~= nil
		end
		return false
	end

	self._loading[player] = true
	if not self._wait_signals[player] then self._wait_signals[player] = signal() end

	local userId = self.options.overridenUserId or self.options.viewedUserId or player.UserId
	local index = self:_get_profile_key(userId)

	if self.options.resetData and not self.options.viewedUserId then self.playerStore:RemoveAsync(index) end

	local ok, profile = pcall(function()
		if self.options.useMock then
			return self.playerStore.Mock:StartSessionAsync(index, storeCancel(player))
		elseif self.options.viewedUserId or self.options.dontSave then
			return self.playerStore:GetAsync(index)
		else
			return self.playerStore:StartSessionAsync(index, storeCancel(player))
		end
	end)

	if not ok or profile == nil then
		warn(`Failed to load data for {player.Name}: {profile}`)
		self._loading[player] = nil
		self:_resolve_wait(player)
		self.playerDataFailed:fire(player, profile)
		return false
	end

	profile:AddUserId(userId)
	profile:Reconcile()

	local isSession = not (self.options.viewedUserId or self.options.dontSave)
	self._sessions[player] = isSession

	if isSession then
		profile.OnSessionEnd:Connect(function()
			self._profiles[player] = nil
			self._sessions[player] = nil
			if player.Parent then player:Kick(`Profile session end - Please rejoin`) end
		end)
	end

	if not player:IsDescendantOf(Players) then
		if isSession then pcall(function()
			profile:EndSession()
		end) end
		self._profiles[player] = nil
		self._sessions[player] = nil
		self._loading[player] = nil
		self:_resolve_wait(player)
		self.playerDataFailed:fire(player, 'Player left before data loaded')
		return false
	end

	self._profiles[player] = profile
	self:_setup_player(player, profile.Data)
	self._loading[player] = nil

	profile:MessageHandler(function(messageData: MessageData, processed: () -> ())
		local cb = self._global_callbacks[messageData.key]
		if cb then
			if (cb :: any)(player, messageData.data) ~= false then processed() end
			return
		end

		local waitConnection: any
		waitConnection = self._global_callback_added:connect(function(key: string)
			if key ~= messageData.key then return end

			local newCb = self._global_callbacks[messageData.key]
			if (newCb :: any)(player, messageData.data) ~= false then processed() end

			waitConnection:disconnect()

			local pending = self._pending_message_waits[player]
			if pending then
				local index = table.find(pending, waitConnection)
				if index then table.remove(pending, index) end
			end
		end)

		local pending = self._pending_message_waits[player]
		if not pending then
			pending = {}
			self._pending_message_waits[player] = pending
		end

		table.insert(pending, waitConnection)
	end)

	return true
end

--[=[
	@method isLoaded
	@within DataServiceServer
	@param player Player
	@return boolean

	Returns whether the player's data has been loaded and is available through `data[player]`.

	```lua
	if Data.service:isLoaded(player) then
		print(Data[player].coins())
	end
	```
]=]
function data_service.isLoaded(self: self, player: Player): boolean
	return self.data[player] ~= nil
end

--[=[
	@method resetData
	@within DataServiceServer
	@param player Player

	Resets the data for the specified player by removing their profile from the store.
	The player is then kicked from the game with a message to rejoin.

	```lua
	Data.service:resetData(player)
	```
]=]
function data_service.resetData(self: self, player: Player): ()
	local userId = self.options.overridenUserId or self.options.viewedUserId or player.UserId
	local index = self:_get_profile_key(userId)
	self:_on_player_removing(player)
	self.playerStore:RemoveAsync(index)
	player:Kick 'Your data has been reset. Please rejoin.'
end

function data_service._resolve_wait(self: self, player: Player): ()
	local waitSignal = self._wait_signals[player]
	if waitSignal then
		waitSignal:fire()
		waitSignal:disconnectAll()
		self._wait_signals[player] = nil
	end
end

function data_service._on_player_removing(self: self, player: Player): ()
	self._loading[player] = nil
	self:_resolve_wait(player)

	local pending = self._pending_message_waits[player]
	self._pending_message_waits[player] = nil
	if pending then
		for _, connection in pending do
			(connection :: any):disconnect()
		end
	end

	local profile = self._profiles[player] :: any
	self._profiles[player] = nil
	if not profile then return end

	for _, fn in self._removal_functions do
		local success, err: any? = pcall(fn, player, profile.Data)
		if not success then warn(err or 'Error in removal function for ' .. player.Name) end
	end

	if self._sessions[player] then profile:EndSession() end
	self._sessions[player] = nil

	self.data[player] = nil
	self.playerDataEnded:fire(player)
end

--[=[
	@method sendGlobalMessage
	@within DataServiceServer
	@param key string
	@param userId number | string
	@param data { any }
	@return boolean

	Sends a global message to the specified user's profile.
	Returns true if the message was sent successfully, false otherwise.

	```lua
	Data.service:sendGlobalMessage("SendGift", userId, { currency = 100, from = "Friend" })
	```
]=]
function data_service.sendGlobalMessage(self: self, key: string, userId: number | string, data: { any }): boolean
	local messageData: MessageData = { key = key, data = data }
	return self.playerStore:MessageAsync(self:_get_profile_key(userId), messageData)
end

--[=[
	@method addGlobalCallback
	@within DataServiceServer
	@param key string
	@param cb (player: Player, data: { any }) -> boolean?

	Adds a global callback function for handling messages with the specified key.
	The callback receives the player and data as parameters.
	If the callback returns false, the message is not processed further.

	```lua
	Data.service:addGlobalCallback("SendGift", function(player: Player, data: { any }): boolean?
		print("Received gift for", player.Name, "with data:", data)
		-- Process the gift here
	end)
	```
]=]
function data_service.addGlobalCallback(self: self, key: string, cb: (player: Player, { any }) -> boolean?): ()
	assert(self._global_callbacks[key] == nil, 'Global callback already exists for key: ' .. key)
	self._global_callbacks[key] = cb
	self._global_callback_added:fire(key)
end

function data_service._get_profile_key(self: self, userId: number | string): string
	return self:_get_data_prefix() .. tostring(userId)
end

function data_service._get_data_prefix(self: self): string
	return self.options.profileStoreDataPrefix or DATA_PREFIX
end

function data_service._setup_player<T>(self: self, player: Player, data: T): ()
	network.sync:fire(player, data)

	self.data[player] = value.new(data, nil, nil, function(replicateType: string, path: { string }, ...)
		network.replicate:fire(player, replicateType, path, ...)
	end)

	self:_resolve_wait(player)
	self.playerDataLoaded:fire(player)
end

--[=[
	@method addPlayerRemovingCallback
	@within DataServiceServer
	@param fn (player: Player, data: any) -> ()

	Add any number of functions to be called when a player is removed.
	Used to perform cleanup or save data before the player leaves.

	```lua
	Data.service:addPlayerRemovingCallback(function(player: Player, data: any): ()
		print(player.Name .. " is leaving with data:", data)
		-- Perform any cleanup or save operations here
	end)
	```

	```lua
	local disconnect = Data.service:addPlayerRemovingCallback(function(player: Player, data: any): ()
		data.currency = 0
	end)

	-- Later, you can disconnect this function if needed
	disconnect()
	```
]=]
function data_service.addPlayerRemovingCallback(self: self, fn: (player: Player, data: any) -> ()): () -> ()
	table.insert(self._removal_functions, fn)
	return function()
		local index = table.find(self._removal_functions, fn)
		if index then table.remove(self._removal_functions, index) end
	end
end

--[=[
	@method asyncGetProfile
	@within DataServiceServer
	@param userId number | string
	@return Profile?

	Asynchronously retrieves the profile for the given user ID using internal ProfileStore.
]=]
function data_service.asyncGetProfile(self: self, userId: number | string): any?
	return self.playerStore:GetAsync(self:_get_profile_key(userId))
end

--[=[
	@method getProfile
	@within DataServiceServer
	@param player Player
	@return Profile

	Retrieves the profile for the given player.
]=]
function data_service.getProfile(self: self, player: Player): any
	return self._profiles[player]
end

--[=[
	@method waitForData
	@within DataServiceServer
	@yields
	@param player Player
	@return Data?

	Waits for the player's data to be initialized and returns it.
	If the data is already available, it returns immediately.
	Returns `nil` if the player leaves before their data loads.
]=]
function data_service.waitForData(self: self, player: Player): any
	local data = self.data[player]
	if data then return data end

	local waitSignal = self._wait_signals[player]
	if not waitSignal then
		waitSignal = signal()
		self._wait_signals[player] = waitSignal
	end

	waitSignal:wait()
	return self.data[player]
end

export type data_service = typeof(data_service)

export type server<T> = {
	service: data_service,
	[Player]: value.value<T>,
}

export type Public<T> = {
	loadPlayer: (self: any, player: Player) -> boolean,
	isLoaded: (self: any, player: Player) -> boolean,
	waitForData: (self: any, player: Player) -> (),
	getProfile: (self: any, player: Player) -> any,
	asyncGetProfile: (self: any, userId: number | string) -> any,
	resetData: (self: any, player: Player) -> (),
	addPlayerRemovingCallback: (self: any, fn: (player: Player, data: any) -> ()) -> () -> (),
	addGlobalCallback: (self: any, key: string, cb: (player: Player, { any }) -> boolean?) -> (),
	sendGlobalMessage: (self: any, key: string, userId: number | string, data: { any }) -> (),
}

return data_service
