---
sidebar_position: 5
---

# Options

Pass options to `createPlayerData`:

```lua
local Data = createPlayerData({
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

## Essentials

| Option | What it does |
| --- | --- |
| `template` | Required. Default data shape for every player. |

## Storage

| Option | What it does |
| --- | --- |
| `profileStoreIndex` | ProfileStore name. Defaults to `"Default"`. |
| `profileStoreDataPrefix` | Prefix before the user id in the profile key. Defaults to `"PLAYER_"`. |

## Testing

| Option | What it does |
| --- | --- |
| `useMock` | Uses ProfileStore mock storage for testing. |
| `dontSave` | Loads with `GetAsync` instead of a write session. |
| `resetData` | Removes the profile before loading. |

## Admin / inspection

| Option | What it does |
| --- | --- |
| `viewedUserId` | Loads another user's data for viewing, no write session. |
| `overridenUserId` | Uses another user id as the active profile. |