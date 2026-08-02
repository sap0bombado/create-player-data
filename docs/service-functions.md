---
sidebar_position: 2
---

# Service Functions

`Data.service` is the server-only API for lifecycle hooks, loading, ProfileStore access, data resets, and cross-server messages.

Require the server side of your data module first:

```lua
local Data = require(path.to.Data).server
```

Most gameplay code can use `Data[player]` directly:

```lua
Data[player].currency(function(currency)
	return currency + 10
end)
```

Use `Data.service` when you need behavior around loading, leaving, profiles, or global messages.

## `loadPlayer(player)`

Loads a player's profile session and populates `Data[player]`. Returns a boolean.

```lua
local ok = Data.service:loadPlayer(player)
if ok then
	Data[player].currency(50)
end
```

It is idempotent: already-loaded players return `true` without reloading. It fails (returning `false`) when the profile session could not be opened, the datastore errored, or the player left mid-load.

## `isLoaded(player)`

Checks whether a player's data is currently loaded, without triggering a load.

```lua
if Data.service:isLoaded(player) then
	print(Data[player].currency())
end
```

## Lifecycle Signals

`Data.service` fires three signals around loading:

```lua
Data.service.playerDataLoaded:Connect(function(player)
	print(player.Name, "data loaded")
end)

Data.service.playerDataFailed:Connect(function(player, err)
	warn(player.Name, "failed to load:", err)
end)

Data.service.playerDataEnded:Connect(function(player)
	print(player.Name, "data ended")
end)
```

On the client, `Data.controller.playerDataSynced` fires when the server data has been replicated:

```lua
Data.controller.playerDataSynced:wait()
print(Data.currency())
```

## Migrations and Defaults

Use `playerDataLoaded` for migrations, defaults, and one-time cleanup after a profile loads. At that point `Data[player]` already exists, so you can read and write directly:

```lua
Data.service.playerDataLoaded:Connect(function(player)
	if Data[player].currency() < 0 then
		Data[player].currency(0)
	end

	if Data[player].settings.sfx() == nil then
		Data[player].settings.sfx(true)
	end
end)
```

Writes replicate to the client automatically. For read-only normalization against the template, run it before the load finishes via `addPlayerRemovingCallback` or handle it in your own `PlayerAdded` flow.

## `waitForData(player)`

`waitForData` yields until a player's data has finished loading, then returns the same data object you get from `Data[player]`.

```lua
local data = Data.service:waitForData(player)

data.currency(50)
```

You usually only need this in code that might run before the player's data exists yet, such as early `PlayerAdded` logic or another service starting up at the same time as create_player_data.

After data is loaded, prefer the simple form:

```lua
Data[player].currency(50)
```

## `getProfile(player)`

Returns the loaded ProfileStore profile for a player.

```lua
local profile = Data.service:getProfile(player)
```

Use this when you need ProfileStore-specific functionality that create_player_data does not wrap. For normal reads and writes, use `Data[player]`.

```lua
local profile = Data.service:getProfile(player)

if profile then
	print(profile.Data.currency)
end
```

## `asyncGetProfile(userId)`

Loads a profile by user id and returns it.

```lua
local profile = Data.service:asyncGetProfile(123456789)

if profile then
	print(profile.Data.currency)
end
```

This is useful for admin tools, profile inspection, and read-only flows where the player is not currently in the server.

## `resetData(player)`

Deletes the player's saved profile and kicks them so they can rejoin with fresh data.

```lua
Data.service:resetData(player)
```

This is most useful for admin commands and local testing. It ends the current profile session, removes the saved data, and kicks the player with a reset message.

## `addPlayerRemovingCallback(fn)`

Registers a callback that runs when a player's profile is about to end.

```lua
local disconnect = Data.service:addPlayerRemovingCallback(function(player, data)
	data.lastLeaveTime = os.time()
end)
```

The callback receives the player and the raw data table. This is useful for final timestamps, cleanup, or writing values that should happen right before the ProfileStore session ends.

The function returns a disconnect callback:

```lua
local disconnect = Data.service:addPlayerRemovingCallback(function(player, data)
	print(player.Name, "left with", data.currency, "coins")
end)

disconnect()
```

## `sendGlobalMessage(key, userId, data)`

Sends a ProfileStore global message to a user's profile.

```lua
Data.service:sendGlobalMessage("GiftCoins", 123456789, {
	amount = 100,
	from = "DailyReward",
})
```

The `key` decides which callback handles the message. The `userId` can be a number or string. The `data` argument should be a plain table.

## `addGlobalCallback(key, callback)`

Registers a callback for global messages with a matching key.

```lua
Data.service:addGlobalCallback("GiftCoins", function(player, data)
	local amount = data.amount
	if typeof(amount) ~= "number" then
		return false
	end

	Data[player].currency(function(currency)
		return currency + amount
	end)
end)
```

The callback receives the player and the message data. Return `false` when the message should not be marked as processed.

Global messages are a good fit for cross-server rewards, purchases, gifts, and admin actions aimed at a player who may not be in the current server.

## Quick Reference

```lua
-- Waits for Data[player] to exist
local data = Data.service:waitForData(player)

-- Gets the loaded ProfileStore profile
local profile = Data.service:getProfile(player)

-- Loads a profile by user id
local profile = Data.service:asyncGetProfile(userId)

-- Deletes saved data and kicks the player
Data.service:resetData(player)

-- Runs before the profile session ends
local disconnect = Data.service:addPlayerRemovingCallback(function(player, data) end)

-- Sends and receives ProfileStore global messages
Data.service:sendGlobalMessage("Key", userId, data)
Data.service:addGlobalCallback("Key", function(player, data) end)
```
