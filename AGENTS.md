# AGENTS.md

## Overview

`create_player_data` is a **library wrapper around ProfileStore**: persistent, typed,
server-authored player data that auto-replicates to a client mirror. It is **not a
framework** — it never hooks `PlayerAdded` or drives game loops. Games call its API
(`startSessionAsync`, `endSession`, `Data[player]...`, `Data...`) themselves.

## Philosophy

1. **Library, not framework.** The game decides when to load, save, end, or reset a session.
2. **Minimal, YAGNI.** Shortest correct change; no speculative abstractions or config for
   values that never change. Add a method/flag/type only when a real caller exists.
3. **Simple over clever.** Clear names beat clever one-liners.
4. **Root-cause fixes.** Guard the shared path, not each caller. `endSession` is the single
   teardown reused by reset/removal/explicit calls.
5. **Lazy.** Reuse existing helpers (`_resolve_wait`, `_on_player_data_failed`,
   `endSession`, `value.new`) instead of duplicating.

## Conventions
- **Exported types** lower-snake (`client<T>`, `server<T>`, `value<T>`, `data_options<T>`,
  `data_service<T>`, `Public<T>`, `DataTemplate`, `DataOptions`).
- **Public methods** camelCase; **private fields/methods** underscore+snake (`_profiles`,
  `_loading`, `_sessions`, `_resolve_wait`, `_stop_loading`, `_get_profile_key`,
  `_setup_player`, `_wait_for_global_callback`).
- **Signals** camelCase (`playerDataLoaded`, `playerDataFailed`, `playerDataEnded`,
  `playerDataSynced`). create-signal API is lowercase (`:connect`/`:wait`/`:fire`); engine
  events use `:Connect`.
- **Module constants** UPPER_SNAKE (`DATA_PREFIX`, `DEFAULT_PROFILE_STORE_INDEX`).

## Format / tooling
- Format **only** with Stylua (`stylua.toml`: single quotes, col 175, sorted requires); run
  `stylua --check` on changed `src/` files. Do **NOT** run selene (`selene.toml` is stale).
- Requires Luau's **new type solver**; generics typed, `any` only at ProfileStore/`__call`
  boundaries. `server.luau`/`client.luau` each return early on the wrong RunService realm.
- `const` at module load; `local` for mutable module-based buffers.

## Dependencies (`pesde.toml`)
- `signal` (create-signal), `profile_store` (ProfileStore), `remo` (network `sync`/`replicate`).
- Never hand-edit generated `roblox_packages/` / `roblox_server_packages/`.

## Data safety
Datastore-safe values only: numbers, strings, booleans, arrays, dicts, `nil` for optional
keys. No Instances/CFrame/Vector3/functions/threads/userdata. Enforced via template +
`profile:Reconcile()`.

## Architecture / roles

| File | Role |
|------|------|
| `init.luau` | Public factory: `createPlayerData<T>(options) -> { client, server }` |
| `server.luau` | ProfileStore wrapper: idempotent `startSessionAsync` (wait-signal concurrency), replication emitter, endSession/reset, global messages, removal callbacks. |
| `client.luau` | Replicates server data into a local reactive root via `sync`/`replicate` remotes; reads wait on `playerDataSynced`. |
| `value.lua` | Uniform reactive `Value` per field (get/set/update + `.Changed`/`.Insert`/`.Remove`, no diffing). |
| `utils.luau` | `data_options<T>` type. |
| `network.luau` | `remo` remotes: `sync`, `replicate`. |

## Verification / careful editing (server.luau)
Reason about `yields` and concurrency: concurrent `startSessionAsync`, leave-during-load,
wait-signal resolution, `_pending_message_waits` cleanup. `_resolve_wait` is reached from
load, failure, waitForData, and end paths — trace all callers when touching it. No test
suite; keep invariants in moonwave docstrings. Run `stylua --check` after editing.

## Known tech-debt (don't "fix" without asking)
Branding drift only — deliberate, leave as-is:
- `moonwave.toml` `title` `DataServiceTyped`, `default.project.json` `name`
  `dataservicetyped`, `pesde.toml` description says "fork of dataServiceTyped".
- Some public connect names intentionally follow create-signal's lowercase API — keep that.