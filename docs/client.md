---
sidebar_position: 3
---

# Client

Require the client half of your data module:

```lua
local Data = require(path.to.Data).client
```

## Waiting for data

The server sends the initial data snapshot after the profile loads. Use `playerDataSynced` to wait for it:

```lua
Data.playerDataSynced:wait()
```

Or use `Data.use()`, which calls your callback once the data arrives:

```lua
Data:use(function(data)
    print(data.currency())
end)
```

## Reading

Always access the reactive root through `:get()`:

```lua
local root = Data:get()

local money = root.currency()
local apples = root.inventory.apples()
```

The client is a read-only mirror. All changes come from the server — see [Server](./server) for writing data.

## Listening to changes

The client's main job is reacting to server changes. `.Changed` fires when a field changes:

```lua
local disconnect = root.currency.Changed(function(currency, previous)
    print("Currency:", previous, "->", currency)
end)

-- Later:
disconnect()
```

Listen to a parent table to catch changes in any child, and react to arrays and dictionaries with `.OnInsert`, `.OnRemove`, `.OnKeyAdded`, and `.OnKeyRemoved`:

```lua
root.inventory.Changed(function(inventory, previousChildValue, childKey)
    print(childKey, "changed")
end)

root.items.OnKeyAdded(function(key, item)
    print("New item:", key)
end)
```

See [Values](./values) for the full listen API.