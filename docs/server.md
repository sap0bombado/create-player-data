---
sidebar_position: 2
---

# Server

Require the server half of your data module:

```lua
local Data = require(path.to.Data).server
```

## Loading players

**create-player-data** does not hook `PlayerAdded` for you. Call `startSessionAsync` yourself:

```lua
local Players = game:GetService 'Players'

Players.PlayerAdded:Connect(function(player)
    local ok = Data:startSessionAsync(player)
    if not ok then
        player:Kick 'Could not load your data. Please rejoin.'
    end
end)
```

`startSessionAsync` is idempotent — calling it for an already loaded player returns `true` immediately.

### Accessing loaded data

Always use `:get(player)` to access a player's data root:

```lua
local playerData = Data:get(player)
playerData.currency(50)
```

If the data may not be loaded yet, omit the second argument (returns `nil`):

```lua
local playerData = Data:get(player) -- nil if not loaded
if playerData then
    playerData.currency(50)
end
```

Pass `true` to assert the data is loaded — throws an error otherwise:

```lua
local playerData = Data:get(player, true) -- errors if not loaded
```

### Waiting for data from other scripts

When another script might be loading the player, use `waitForData`:

```lua
local playerData = Data:waitForData(player)
if playerData then
    playerData.currency(50)
end
```

Yields until the data arrives, or returns `nil` if the player leaves before loading finishes.

### Checking if loaded

```lua
if Data:isLoaded(player) then
    local playerData = Data:get(player)
    print(playerData.currency())
end
```

## Changing data

The server is the source of truth. Writes here are authoritative and replicate to every client automatically. Use `:get(player)` to get the root, then mutate it:

```lua
local playerData = Data:get(player)
playerData.currency(50)
playerData.currency(function(currency)
    return currency + 10
end)
playerData.questProgress.Insert(10)
playerData.items.sword_001(nil)
```

See [Values](./values) for the full read/write/listen API.

## Lifecycle signals

Three signals let you react to data loading and unloading:

```lua
Data.onSessionStart:connect(function(player)
    local playerData = Data:get(player)
    -- Apply defaults, run migrations, give starter items
    playerData.currency(100)
end)

Data.onSessionEnd:connect(function(player)
    -- Data saved and removed. Clean up server-side state.
end)

Data.onSessionFail:connect(function(player, reason)
    warn(player.Name, 'data load failed:', reason)
end)
```

## Ending sessions

`endSession` saves and releases the profile without kicking the player:

```lua
Data:endSession(player)
```

`resetData` deletes the saved profile and kicks the player:

```lua
Data:resetData(player)
```

Use `addPlayerRemovingCallback` to run logic before a session ends. Returns a disconnect function:

```lua
local disconnect = Data:addPlayerRemovingCallback(function(player, data)
    data.lastLeaveTime = os.time()
end)
```

## Global messages

Send data to a player even when they are on a different server:

```lua
Data:sendGlobalMessage("GiftCoins", userId, {
    amount = 100,
    from = "DailyReward",
})
```

Handle these messages on the receiving server:

```lua
Data:addGlobalCallback("GiftCoins", function(player, data)
    local playerData = Data:get(player)
    if not playerData then return false end

    playerData.currency(function(currency)
        return currency + data.amount
    end)
end)
```

Return `false` from the callback to leave the message unprocessed (it will be retried). Add the callback **before** any player loads — otherwise messages arriving during startup may be missed.

## Profiles

Access the raw ProfileStore profile for advanced use cases. `getProfile` returns the loaded profile for a player:

```lua
local profile = Data:getProfile(player)
if profile then
    print(profile.Data.currency)
end
```

`asyncGetProfile` loads a profile by user ID without starting a session. Useful for admin tools:

```lua
local profile = Data:asyncGetProfile(userId)
if profile then
    print(profile.Data.currency)
end
```