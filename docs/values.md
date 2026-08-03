---
sidebar_position: 4
---

# Values

Every field in your data is a **value** — a reactive handle you can read, write, and listen to. Values work the same on server and client, so this page covers both. The server is the source of truth; the client is a read-only mirror that reacts to server changes.

A value is a callable: call it with no arguments to read, with a value or function to write.

## Reading

```lua
local price = playerData.currency()          -- 50
local apples = playerData.inventory.apples() -- 5
```

## Writing

```lua
playerData.currency(50)                        -- set
playerData.settings.music(false)               -- set
playerData.equippedItemId("wooden_sword")      -- set
playerData.equippedItemId(nil)                 -- clear optional values
```

Pass a function to update from the previous value:

```lua
playerData.currency(function(currency)
    return currency + 10
end)

playerData.inventory.apples(function(apples)
    return math.max(0, apples - 1)
end)
```

### Arrays

Typed arrays (e.g. `{} :: { number }`) get `.Insert` and `.Remove`:

```lua
playerData.questProgress.Insert(10)
playerData.questProgress.Insert(15, 2)       -- insert at position 2

local removed = playerData.questProgress.Remove(2)
local last = playerData.questProgress.Remove() -- remove last
```

### Dictionaries

String-keyed dictionaries work like nested data. Set a key by assigning its table. Remove it with `nil`:

```lua
playerData.items.sword_001({
    health = 0,
    dmg = 12,
})

playerData.items.sword_001(nil) -- remove
```

## Listening

Every handling method returns a disconnect function.

### `.Changed`

Fires when a field changes, receiving the new value, previous value, and the key that changed:

```lua
local disconnect = playerData.currency.Changed(function(currency, previous)
    print("Currency:", previous, "->", currency)
end)

-- Later:
disconnect()
```

Listen to a parent table to catch changes in any child:

```lua
playerData.inventory.Changed(function(inventory, previousChildValue, childKey)
    print(childKey, "changed")
end)
```

### `.OnInsert` / `.OnRemove`

Fire when an item is inserted into or removed from an array:

```lua
playerData.questProgress.OnInsert(function(item, position)
    print("Inserted", item, "at", position)
end)

playerData.questProgress.OnRemove(function(item, position)
    print("Removed", item, "from", position)
end)
```

### `.OnKeyAdded` / `.OnKeyRemoved`

Fire when a dictionary key goes from `nil` to a value, or from a value to `nil`:

```lua
playerData.items.OnKeyAdded(function(key, item) end)
playerData.items.OnKeyRemoved(function(key, item) end)
```

Changing an existing key fires `.Changed` instead.