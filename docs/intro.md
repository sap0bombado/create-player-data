---
sidebar_position: 1
---

# Getting Started

**create-player-data** saves and syncs player data in Roblox. type-safe, zero boilerplate, and you decide when to load it.

:::important
**create-player-data** uses Luau's new type solver for its typed data API. Enable the new type solver in Workspace properties or Luau LSP settings for types and IntelliSense to work correctly.
:::

## Install

```toml title="pesde.toml"
[dependencies]
create_player_data = { pesde = "sap0bombado/create_player_data@0.1.2" }
```

```bash
pesde install
```

## Create your data module

A shared module defines what every player's data looks like:

```lua title="shared/player-data.luau"
local createPlayerData = require '@pkg/create_player_data'

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

export type template = typeof(template)

return createPlayerData<<template>>({
    template = template,
})
```

Values must be JSON-safe: numbers, strings, booleans, arrays, dictionaries, and `nil` for optional keys. No Instances, CFrame, Vector3, functions, or userdata.

## Require it

```lua
-- Server
local Data = require(path.to.Data).server

-- Client
local Data = require(path.to.Data).client
```

## Load data

**create-player-data** never loads players automatically. Call `startSessionAsync` in your own `PlayerAdded` handler:

```lua
local Players = game:GetService 'Players'

Players.PlayerAdded:Connect(function(player)
    local ok = Data:startSessionAsync(player)
    if not ok then
        player:Kick 'Could not load your data. Please rejoin.'
    end
end)
```

Once loaded, access the player's data with `:get()`:

```lua
local playerData = Data:get(player)
playerData.currency(50)
```

Data saves automatically when the player leaves. New keys added to the template are reconciled into existing profiles on their next load.

## Next steps

- [Server](./server) — loading, lifecycle, profiles, global messages
- [Options](./options) — configuration reference
- [Values](./values) — reading, writing, and listening to reactive data
- [Client](./client) — the read-only mirror