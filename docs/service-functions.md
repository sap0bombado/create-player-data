---
sidebar_position: 2
---

# Service Functions

The server side of your data module (`Data = require(path.to.Data).server`) is the service: it owns `Data[player]` and the methods for loading, leaving, profiles, resets, and global messages.

```lua
local Data = require(path.to.Data).server
```

Most gameplay code uses `Data[player]` directly:

```lua
Data[player].currency(function(currency)
	return currency + 10
end)
```

Use the service methods when you need behavior around loading, leaving, profiles, or global messages.

## `startSessionAsync(player)`

Loads a player's profile session and populates `Data[player]`. Returns a boolean.

```lua
local ok = Data:startSessionAsync(player)
if ok then
	Data[player].currency(50)
end
```

It is idempotent: already-loaded players return `true` without reloading. It fails (returning `false`) when the profile session could not be opened, the datastore errored, or the player left mid-load.

## `isLoaded(player)`

Checks whether a player's data is currently loaded, without triggering a load.

```lua
if Data:isLoaded(player) then
	print(Data[player].currency())
end
```

## Lifecycle Signals

`Data` fires three signals around loading:

```lua
Data.playerDataLoaded:connect(function(player) end)
Data.playerDataFailed:connect(function(player, err) end)
Data.playerDataEnded:connect(function(player) end)
```

- `playerDataLoaded(player)` — `Data[player]` now exists. Use it for migrations, defaults, and one-time cleanup; reads and writes work directly and replicate automatically.
- `playerDataFailed(player, err)` — a load failed.
- `playerDataEnded(player)` — data saved and removed (leave or `endSession`).

On the client, `Data.playerDataSynced:wait()` resolves once the server data has replicated:

```lua
Data.playerDataSynced:wait()
print(Data:get().currency())
```

## `waitForData(player)`

Yields until a player's data finishes loading, then returns the same object you get from `Data[player]`.

```lua
local data = Data:waitForData(player)
data.currency(50)
```

Usually only needed in code that may run before the data exists (early `PlayerAdded` logic, a service starting up). After data is loaded, prefer `Data[player].currency(50)`.

## `getProfile(player)`

Returns the loaded ProfileStore profile for a player, for ProfileStore-specific functionality create_player_data does not wrap.

```lua
local profile = Data:getProfile(player)
if profile then
	print(profile.Data.currency)
end
```

## `asyncGetProfile(userId)`

Loads a profile by user id (no session) and returns it. Useful for admin tools, inspection, and read-only flows where the player is not in the server.

```lua
local profile = Data:asyncGetProfile(123456789)
if profile then
	print(profile.Data.currency)
end
```

## `resetData(player)`

Deletes the player's saved profile and kicks them so they can rejoin with fresh data. Ends the current session, removes the saved data, and kicks with a message.

```lua
Data:resetData(player)
```

## `endSession(player)`

Saves and releases a player's profile, removes `Data[player]`, and fires `playerDataEnded`. It does not touch the Player instance or kick them; use it to force-save and unload without kicking.

```lua
Data:endSession(player)
Data:isLoaded(player) --> false
```

## `addPlayerRemovingCallback(fn)`

Registers a callback that runs when a player's profile is about to end. Receives `(player, data)`; good for final timestamps and cleanup. Returns a disconnect callback.

```lua
local disconnect = Data:addPlayerRemovingCallback(function(player, data)
	data.lastLeaveTime = os.time()
end)

disconnect()
```

## `sendGlobalMessage(key, userId, data)`

Sends a ProfileStore global message to a user's profile (cross-server rewards, gifts, admin actions for a player not in this server).

```lua
Data:sendGlobalMessage("GiftCoins", 123456789, {
	amount = 100,
	from = "DailyReward",
})
```

The `key` selects which callback handles the message; `userId` can be a number or string; `data` should be a plain table.

## `addGlobalCallback(key, callback)`

Registers a callback for global messages with a matching key. Receives `(player, data)`; return `false` to leave the message unprocessed.

```lua
Data:addGlobalCallback("GiftCoins", function(player, data)
	local amount = data.amount
	if typeof(amount) ~= "number" then
		return false
	end

	Data[player].currency(function(currency)
		return currency + amount
	end)
end)
```

## Quick Reference

```lua
-- Waits for Data[player] to exist
local data = Data:waitForData(player)

-- Gets the loaded ProfileStore profile
local profile = Data:getProfile(player)

-- Loads a profile by user id
local profile = Data:asyncGetProfile(userId)

-- Deletes saved data and kicks the player
Data:resetData(player)

-- Ends the session without kicking (saves and unloads)
Data:endSession(player)

-- Runs before the profile session ends
local disconnect = Data:addPlayerRemovingCallback(function(player, data) end)

-- Sends and receives ProfileStore global messages
Data:sendGlobalMessage("Key", userId, data)
Data:addGlobalCallback("Key", function(player, data) end)
```