# prism_multichar

A cinematic character selector for FiveM. Works with Qbox, QBCore and ESX Legacy through a
bridge layer, and uses illenium-appearance for clothing. The player stands in a scripted
camera shot while picking, creating or deleting a character, then gets dropped into the
world through a spawn picker.

## Features

- Three cinematic camera shots per scene, gliding slowly around the character with its own
  time of day and weather.
- A local, non-networked preview ped shows the selected slot's saved clothing. Empty slots
  show a translucent ghost ped. Drag on the stage to spin the ped around.
- Inline character creation in the right panel: first name, last name, date of birth,
  gender and nationality (nationality is skipped on ESX, since it has no field for it).
- A spawn picker with "Last location" (when one is saved) plus whatever points you list in
  `Config.Spawns`.
- Per-license and per-ACE slot limits, normalized so a lowered slot count never hides a
  character that already exists.
- Reopens automatically on relog for all three frameworks.
- Every write path is validated and rate limited server side; nothing the client sends is
  trusted on its own.

## Requirements

- `ox_lib`
- `oxmysql`
- `illenium-appearance`
- One of: `qbx_core` (Qbox), `qb-core` (QBCore), `es_extended` (ESX Legacy)

## Install

1. Drop the resource into your `resources` folder as `prism_multichar`.
2. Add `ensure prism_multichar` to your `server.cfg`, after your framework and after
   `ox_lib`, `oxmysql` and `illenium-appearance`.
3. Edit `config.lua` — at minimum check `Config.Spawns`, `Config.NewCharacterSpawn` and
   `Config.Scenes` for your map, since the defaults are plain Los Santos coordinates.
4. Follow the framework-specific steps below.
5. Restart the server.

### Qbox

Stop `qbx_core`'s own character selector so it doesn't fight with this one: open
`qbx_core`'s `config/client.lua` and set

```lua
characters.useExternalCharacters = true
```

That's the only change needed. `qbx_core`'s internal character screen checks this flag and
returns immediately if it's set, leaving the routing bucket and player state alone for us
to take over.

### QBCore

Stop `qb-multicharacter` — either remove it from your `server.cfg` or comment out its
`ensure` line. `prism_multichar` picks up the `qb-multicharacter:client:chooseChar` event
that resource used to own, so anything that still triggers it (manual relogs, admin
commands) keeps working.

### ESX Legacy

1. Stop `esx_multicharacter`.
2. In `es_extended`'s config, set

   ```lua
   Config.Multichar = true
   ```

   This is normally turned on automatically when `esx_multicharacter` is present, but
   setting it explicitly means character selection still works if that resource gets
   removed outright later.
3. `prism_multichar` adds the columns it needs (`firstname`, `lastname`, `dateofbirth`,
   `sex`, `height`, `skin`, `prism_last_played`) to the `users` table itself on first start
   if they're missing — you don't need to run any SQL by hand.
4. The `/relog` command (configurable via `Config.ESX.RelogCommand`) triggers
   `esx:playerLogout` so players can jump back to character selection without reconnecting.

## Config notes

- `Config.Framework` — `'auto'` detects the running framework by resource state. Set it
  explicitly if you run something unusual alongside one of the three.
- `Config.DefaultSlots`, `Config.SlotOverrides`, `Config.MaxSlots` — slot count is the
  highest of the default, any per-license override, and whatever
  `prism_multichar.slots.N` ACE permission the player has, capped at `MaxSlots`. A
  character never disappears because its slot number no longer fits that math; it just
  gets pushed into an extra slot beyond the configured count.
- `Config.Scenes` — each entry is a full location: coordinates, time, weather and three
  camera shots. Shots are offsets from the ped's feet and heading, where `x` is right,
  `y` is forward and `z` is up. One scene is picked at random each time the selector opens.
- `Config.StarterItems` — handed out on character creation. Qbox routes this through
  `ox_inventory`; QBCore prefers `QBCore.Shared.StarterItems` and falls back to this list;
  `id_card` and `driver_license` get the player's name and birthdate attached as metadata
  the same way `qb-multicharacter` does it.
- `Config.ESX.DeleteTables` — besides the `users` row, list any addon tables here that key
  per-character data by identifier, and they'll be cleaned up in the same transaction when
  a character is deleted. Table and column names are whitelisted against `^[%w_]+$` before
  they're ever interpolated into a query.
- `Config.WeatherSync` — disables `qb-weathersync` while a player is in the selector and
  re-enables it once they spawn, so the scripted weather for the scene doesn't get
  overridden mid-selection.

## Events and exports

Server events, fired with `(src, id)`:

- `prism_multichar:server:characterLoaded`
- `prism_multichar:server:characterCreated`
- `prism_multichar:server:characterDeleted`

Client export:

- `exports['prism_multichar']:OpenSelection()` — opens the selector for the local player.
  Used internally for the first connect and for relogs; call it yourself if you need to
  force a player back into character selection from another resource.

## UI development

`web/` is plain HTML, CSS and JS with no build step. Open `web/index.html` directly in a
browser and it loads mock character data instead of talking to the game, since
`window.invokeNative` won't exist outside FiveM. That's enough to iterate on layout and
styling without a running server.

Every visible string lives in `locales/en.json`, referenced either through a
`data-locale` attribute in the HTML or a `t('key')` lookup in `app.js`. Server callback
errors are returned as short codes (`invalid_dob`, `slot_taken`, and so on) and mapped to
`err_<code>` keys on the client, so add new codes there if you extend the server
validation.

## Adding another framework

1. Copy `bridge/server/qbcore.lua` as a starting point — it's the simplest of the three.
2. Guard the top of the file so it only installs itself when your framework is the active
   one (see how the existing bridges check `Config.Framework` and `GetResourceState`).
3. Implement `Bridge.Framework`, `Bridge.GetCharacters`, `Bridge.IsLoggedIn`,
   `Bridge.Login`, `Bridge.CreateCharacter`, `Bridge.DeleteCharacter`,
   `Bridge.GiveStarterItems` and `Bridge.OnPlayerLoaded`. `server/main.lua` only ever calls
   through this table, so it doesn't need to know your framework exists.
4. If your framework stores appearance somewhere other than the shared `playerskins`
   table, override `Bridge.FetchAppearance` the way `bridge/server/esx.lua` does for
   `users.skin`.
5. Add the file to the `server_scripts` list in `fxmanifest.lua`, after `_common.lua` —
   load order matters since each bridge file only takes over the `Bridge` table when it
   detects itself as the active framework.
6. On the client, extend `bridge/client.lua`'s framework detection and `Bridge.OnSpawned`
   with whatever events your framework expects after a player spawns, and add the
   relevant relog event to `client/main.lua`.

## License

MIT, see `LICENSE`.
