# TSS Inventory — grid inventory with TSS Bridge

Inventory storage remains independent of framework inventories and SQL. `tss_bridge` is now required for ped/target integrations, notifications and shop payments. McKleans Emporium is active at the Legion Square 24/7. See `SHOPS_AND_BRIDGE.md` for setup and adapter coverage. Vehicle detection, linked backpack items and weapons are not implemented. Local item images were copied from qb-inventory; it is not a runtime dependency.

## Start and try

1. Start your framework and target provider, then `ensure tss_bridge`, then `ensure tss-inventory`. After this update a clean server restart is recommended so existing bridge consumers load fresh module references.
2. TAB or `/inv` opens your own inventory. ESC/TAB closes. Rebind through FiveM key settings if another resource owns TAB; this script does not disable the existing inventory.
3. Console: `invadditem 1 radio 1`, `invadditem 1 bandage 12` (replace 1 with your player server ID).
4. Console: `invcreate demo:stash stash` then `invopen demo:stash 1`. Try `invcreate demo:bag backpack` too.
5. Hold the left mouse button on an item and drag it to another slot or inventory; tap R while holding to rotate. Release to place, or Escape to cancel. Right-click for details, use, split stack, or move quantity. Use reports no handler until a trusted server callback is registered; no other scripts are called.
6. Drag a window header or tab and hold D to reveal eight adjoining docking slots around an open centre. Release the mouse over a slot while still holding D to dock. Inventories in the same slot become tabs. Drag tabs away without D or use the square control to undock. The grid docking button has been removed; the square still brings floating windows forward. Layout persists locally; Reset layout clears it.
7. Target the Legion Square 24/7 clerk (24.47, -1346.62, 28.50). Drag a shop item into your inventory to buy one, or right-click Buy amount… for the themed quantity/total popup. Payments use framework cash through the bridge, not the inventory cash item.

World drops are now available through the new drops modules and your Config.WorldDrops settings. Right-click Drop / Drop amount… or drag an owned item onto the empty game background. Drops pool nearby, open alongside TAB by default, and are never saved. See WORLD_DROPS.md for target mode, cleanup and persistence details.

## Admin permissions

Admin commands use server `RegisterCommand(..., true)` and native ACE objects such as `command.invadditem`. Console is permitted. A FiveM `group.admin` with `command allow` already has access. Otherwise use the exact grants in `admin.example.cfg` and your existing admin principal setup. txAdmin web permissions or QBCore admin status alone do not grant these native ACE objects. The implementation follows the [official command ACL documentation](https://docs.fivem.net/docs/scripting-manual/migrating-from-deprecated/creating-commands/). Server.cfg and running resources were not changed.

| Command | Arguments |
| --- | --- |
| `/invhelp` | Show command list |
| `/invadditem` | `<playerServerId OR inventoryId> <itemName> <amount>` |
| `/invremoveitem` | `<target> <itemInstanceId> <amount>` |
| `/invcreate` | `<uniqueInventoryId> <type>` (stash, backpack, wallet, registered type) |
| `/invopen` | `<inventoryId> [playerServerId]` (omit player only in game) |
| `/invresize` | `<target> <columns> <rows> [repack]` |
| `/invmeta` | `<target> <JSON object>` |
| `/invitemmeta` | `<target> <itemInstanceId> <JSON object>` |
| `/invinspect` | `<target>` prints full inventory to server console |

Examples: `/invresize 1 10 8 repack`, `/invmeta demo:stash {"businessId":"mechanic","tier":2}`, `/invitemmeta 1 1 {"durability":85}`. Metadata setters REPLACE the object. Hover shows item instance ID. Purely numeric command targets are player IDs; use descriptive inventory IDs such as `business:mechanic:storage`.

## Definitions, storage, metadata

- Existing config and container definitions are retained. The vehicle size typo was corrected. `config.lua`, `data/items.lua`, `data/containers.lua` define defaults. Item weight is grams, sizes are columns/rows. Empty whitelist is unrestricted; nonempty whitelist and blacklist are enforced.
- Player identity uses the server-observed FiveM license: one standalone inventory per license, independent of character slots.
- Instances store their own type, label, size, metadata, whitelist, blacklist, optional maxWeight, item instances and revision. Types are templates: changes affect future creation; edit saved instances explicitly through exports.
- All grids use `Config.CellSize`; large grids scroll instead of stretching cells. Tap R while dragging to toggle item rotation; Escape cancels the drag. A translucent ghost follows the cursor, destination cells highlight red for valid placement or amber when blocked, and edge scrolling supports large grids. Rotation is saved per item instance and validated on the server. Stacks require identical names AND metadata; unstackable instances stay separate.
- Resize preserves positions unless repack is requested. Invalid shrinking fails without changes. Repack uses an area-first packing heuristic; it can refuse some theoretically packable arrangements. Move items manually and retry in those cases.
- Resource KVP storage saves every accepted mutation. Cross-inventory transfers write a redo journal before either participant and replay pending changes on restart. Back up your server resource KVP database. Storage is not the data folder or a qb database; renaming the resource requires migration.
- Removed item definitions or changed footprints that invalidate saved items fail closed rather than wiping content. Restore compatible definitions before opening those inventories.
- Metadata supports nested JSON objects, strings, finite numbers and booleans. Maximum depth 8; `Config.MaxMetadataBytes` limits encoded size. Arrays, functions, cycles and userdata are refused. Inventory and item metadata are replicated to authorised viewers, so keep secrets separately.

## Authority and access

Clients can open only their own inventory directly. A trusted server command/export must grant access to other inventory IDs. Clients cannot create items, resize, edit metadata or choose arbitrary stashes. Server movement checks session grants, instance IDs, positive integer amounts, stack caps/metadata, collisions/bounds, weight, whitelist/blacklist, both revisions and request rate. Mutations do not yield and fresh snapshots broadcast to viewers.

`OpenInventory` grants access until the inventory/UI closes or the player disconnects. Server stash integrations must check authorisation/proximity before opening and revoke grants when conditions expire. Shops separately enforce their configured proximity/routing bucket on opening and every purchase, and distant shop grants are removed. Server resources are trusted callers; never wrap mutation exports in unchecked network events. This design follows [Cfx server-event guidance](https://docs.fivem.net/docs/developers/server-security/).

## Validation and in-game acceptance

Run `lua tests/run.lua` from the resource root. Automated tests exercise the model and real server handlers with mocked FiveM natives: placement, stacking, metadata, safe transfers/resizing, revisions, access grants, commands and exports. Lua syntax and JavaScript syntax were checked. Browser tests cover floating windows, hover, context menu, quantity dialog, edge docking/tab switching, layout persistence and close.

Actual FiveM runtime, KVP native behaviour, keybind conflicts, native ACE enforcement and multiplayer still need an in-game check. Test two players viewing one stash, denied admin commands, full-grid transfer failure, resize failure, reconnect and resource restart. No live resources were started or restarted during implementation.

## Image provenance

Seven PNGs copied from the supplied local qb-inventory: radio, water_bottle, sandwich, bandage, phone, id_card and driver_license. The upstream supplied license is retained as `web/images/UPSTREAM-LICENSE.txt`; original per-image authorship is not established. No qb executable code was copied.
