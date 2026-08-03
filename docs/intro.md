---
sidebar_position: 1
---

# create_player_data

**create_player_data** is persistent, typed, automatically replicated player data for Roblox Luau. It is a library, not a framework: you call `startSessionAsync` yourself instead of it hooking into `PlayerAdded` for you.

The API is intentionally small. On the server:

```lua
Data[player].currency() -- get
Data[player].currency(50) -- set
Data[player].currency(function(currency) -- update
	return currency + 10
end)
```

On the client, the root is exposed through `Data:get()`:

```lua
local root = Data:get()
root.currency()
root.currency(50)
root.currency.Changed(function(currency)
	print(currency)
end)
```

## Installation

Add `create_player_data` to your `pesde.toml`:

```toml
[dependencies]
create_player_data = { pesde = "sap0bombado/create_player_data@0.1.0" }
```

Then run:

```bash
pesde install
```

:::important
create_player_data uses Luau's new type solver for its typed data API. Enable the new type solver in Workspace properties or Luau LSP settings for types and IntelliSense to work correctly.
:::

## Create Your Data

Create one shared data module. Most games call it `Data.luau`.

```lua title="Data.luau"
local ReplicatedStorage = game:GetService 'ReplicatedStorage'

local createPlayerData = require '@pkg/create-player-data'

type ItemData = {
	health: number,
	dmg: number,
}

local template = {
	currency = 0,
	inventory = {
		apples = 5,
		oranges = 10,
	},
	settings = {
		music = true,
		sfx = true,
	},
	items = {} :: { [string]: ItemData },
	equippedItemId = nil :: string?,
	questProgress = {} :: { number },
}

return createPlayerData({
	template = template,
})
```

Keep saved data datastore-safe: numbers, strings, booleans, arrays, dictionaries, and `nil` for optional values. Do not store Instances, CFrames, Vector3s, functions, threads, or userdata.

## Require It

Require `.server` on the server and `.client` on the client, so the local variable is `Data` everywhere:

```lua
-- server
local Data = require(path.to.Data).server

-- client
local Data = require(path.to.Data).client
```

On the server, `Data` is the service: it holds `Data[player]` and the lifecycle methods (`startSessionAsync`, `isLoaded`, endSession, ...). On the client it is the replicated mirror: call `Data:get()` for the reactive root, and `Data.use(callback)` or wait on `Data.playerDataSynced` before reading.

## Load Data

create_player_data does not load players automatically. Connect `startSessionAsync` in your own `PlayerAdded` handler:

```lua
local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player)
	task.spawn(function()
		Data:startSessionAsync(player)
	end)
end)
```

`startSessionAsync` yields until the profile session opens, then returns a boolean. It is idempotent: calling it again for an already-loaded player returns `true` without reloading.

```lua
local ok = Data:startSessionAsync(player)
if ok then
	Data[player].currency(50)
end
```

Check whether a player is loaded without triggering a load:

```lua
if Data:isLoaded(player) then
	print(Data[player].currency())
end
```

Data is saved automatically when the player leaves.

## Lifecycle Signals

`Data` fires three signals around loading:

```lua
Data.playerDataLoaded:connect(function(player)
	print(player.Name, "data loaded")
end)

Data.playerDataFailed:connect(function(player, err)
	warn(player.Name, "failed to load:", err)
end)

Data.playerDataEnded:connect(function(player)
	print(player.Name, "data ended")
end)
```

- `playerDataLoaded(player)` fires after `Data[player]` becomes available. Use it for migrations, defaults, and one-time cleanup.
- `playerDataFailed(player, err)` fires when a load fails (profile returned `nil`, the datastore errored, or the player left mid-load).
- `playerDataEnded(player)` fires after the player's data has been saved and removed — on leave or when you end the session with `Data:endSession(player)`.

On the client, `Data.playerDataSynced:wait()` resolves once the server data has replicated:

```lua
Data.playerDataSynced:wait()
print(Data:get().currency())
```

## Get

Call a field with no arguments.

```lua
local currency = Data[player].currency()
local apples = Data[player].inventory.apples()
local musicEnabled = Data[player].settings.music()
```

## Set

Call a field with a new value. Clear optional values with `nil`.

```lua
Data[player].currency(50)
Data[player].inventory.apples(12)
Data[player].settings.music(false)
Data[player].equippedItemId("wooden_sword")
Data[player].equippedItemId(nil)
```

Server changes save and replicate to that player's client automatically. Client changes via `Data:get()` update the local mirror and fire client callbacks, but do not save or replicate.

## Update

Call a field with a function to update from the current value.

```lua
Data[player].currency(function(currency)
	return currency + 10
end)

Data[player].inventory.apples(function(apples)
	return math.max(0, apples - 1)
end)
```

## Listen

Use `.Changed` on any field or table. Both server and client look the same.

```lua
local disconnect = Data[player].currency.Changed(function(currency, previousCurrency)
	print("Currency:", previousCurrency, "->", currency)
end)

disconnect()
```

Listen to a parent table to see which child changed:

```lua
Data[player].inventory.Changed(function(inventory, previousChildValue, childKey)
	print(childKey, "changed")
end)
```

## Optional Replication

Server writes replicate by default. Pass `false` as the last argument to skip replication for that mutation (the server data still changes and still saves).

```lua
Data[player].currency(100, false)

Data[player].currency(function(currency)
	return currency + 25
end, false)
```

## Arrays

Typed arrays get `.Insert`, `.Remove`, `.OnInsert`, and `.OnRemove`.

```lua
Data[player].questProgress.Insert(10)
Data[player].questProgress.Insert(15, 2)
Data[player].questProgress.Insert(3, nil, false) -- no replicate

Data[player].questProgress.OnInsert(function(item, position) end)

local removed = Data[player].questProgress.Remove(2)
local last = Data[player].questProgress.Remove()
Data[player].questProgress.OnRemove(function(item, position) end)
```

## Dictionaries

String-keyed dictionaries work like nested data. Set an entry by assigning its table; remove it with `nil`.

```lua
Data[player].items.sword_001({
	health = 0,
	dmg = 12,
})

print(Data[player].items.sword_001.dmg())

Data[player].items.sword_001(nil)
```

Listen for keys appearing or disappearing with `.OnKeyAdded` and `.OnKeyRemoved`:

```lua
Data[player].items.OnKeyAdded(function(key, item) end)
Data[player].items.OnKeyRemoved(function(key, item) end)
```

`.OnKeyAdded`/`.OnKeyRemoved` fire on `nil <-> value` transitions; changing an existing key fires `.Changed`, not `.OnKeyAdded`.

## Options

```lua
return createPlayerData({
	template = template,
	profileStoreIndex = "Default",
	profileStoreDataPrefix = "PLAYER_",
	useMock = false,
	viewedUserId = nil,
	overridenUserId = nil,
	dontSave = false,
	resetData = false,
})
```

| Option | Description |
| --- | --- |
| `template` | Required. The default data shape for every player. |
| `profileStoreIndex` | ProfileStore name. Defaults to `"Default"`. |
| `profileStoreDataPrefix` | Prefix before the user id in the profile key. Defaults to `"PLAYER_"`. |
| `useMock` | Uses ProfileStore mock storage for testing. |
| `viewedUserId` | Loads another user's data for viewing without starting a write session. |
| `overridenUserId` | Uses another user id as the active profile id. |
| `dontSave` | Loads with `GetAsync` instead of a write session. Useful for read-only testing. |
| `resetData` | Removes the profile before loading. Useful while testing data templates. |

`overridenUserId` is spelled this way in the current API.

## Next Steps

- Read about [service functions](./service-functions) for loading, lifecycle signals, profile access, reset tools, and global messages.