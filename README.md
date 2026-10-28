# TSS Inventory

Standalone grid inventory with a React NUI, red accents, movable windows and eight docking regions. Hold D while dragging a window to reveal docking positions; inventories in the same region share tabs. Drag items to move them, press R during dragging to rotate, and drop onto the world area to create a temporary world drop.

## Startup

Configure oxmysql's connection in server.cfg and start resources in order:

```cfg
ensure oxmysql
ensure tss_bridge
ensure tss-inventory
```

Enable the tss-inventory adapter in your bridge configuration when using it from other scripts. Player ownership uses the bridge's character identifier, so a framework character must be loaded before its personal inventory opens. Shop targeting/peds use the bridge. McKleans Emporium is configured at the Legion Square 24/7 in data/shops.lua.

## Database

All SQL, table creation, database loading/saving and character lifecycle detection are in modules/inventory/database.lua. The resource creates two canonical tables at startup:

- `tss_inventory`: personal inventories keyed by `player_<citizenid>`, with a unique character owner.
- `tss_inventory_containers`: stashes, trunks, gloveboxes, backpacks, shop catalogues and other persistent inventories; optional owner CID and coordinates.

Both store complete items (including item metadata), separate inventory metadata, viewer settings, size, rules, revision, next item ID and a millisecond `last_updated` timestamp. Settings are keyed by viewer CID so a shared inventory has independent docking and floating preferences for each character. The browser receives only the current viewer's settings.

Writes complete before success is acknowledged. Transfers save both participants together; a rejected write restores the cached state. Every accepted content/settings change updates last_updated. Each change saves immediately, so shutdown does not rely on a final flush.

This is a fresh schema, without migrations or legacy import. If these table names already exist with an older development schema, stop the resource and drop those two development tables before starting it again. Startup creates missing tables and never drops existing data automatically.

World drops are server memory only. Their contents, metadata and coordinates are never saved and disappear on resource/server restart. Dropping first saves the corresponding player inventory change. This intentionally means drops are temporary even though player inventories persist.

## Configuration and code

- config.lua: shared limits, defaults, controls and world-drop options.
- data/items.lua: local item definition table registered into TSSItems; omitted fields inherit Config.ItemDefaults. Keep item names unique across files and list each extra file in shared_scripts.
- data/containers.lua and data/vehicles.lua: creation templates/defaults.
- data/shops.lua: shop definitions and initial stock.
- modules/inventory/core.lua: pure grid, stacking, weight and resize operations.
- modules/inventory/server.lua: authoritative actions, sessions, transactions and admin commands.
- modules/inventory/client.lua: focus, requests and local cache.
- web/src: readable React UI source. Run `npm install` then `npm run build` in web after UI edits; FiveM loads web/app.js.

Changing a template affects newly created inventories. Resize/update existing inventories using exports. Saved item footprints must remain valid when changing definitions; incompatible saved content is rejected for inspection rather than silently discarded.

All server/client exports, container creation, settings, drops and shops are documented in [exports.md](exports.md).

## Admin commands

Admin commands use FiveM ACE permissions through tss_bridge. An existing `command` grant allows all commands, or grant individual permissions such as `command.additem`. Command descriptions and arguments appear in tss-chat for authorised admins. TAB and `/inv` remain available to everyone. Inventory arguments accept an inventory ID, an online player ID, or `self`.

- `inventoryhelp`: show command syntax.
- `giveitem <player ID> <item name> [amount] [JSON metadata]` (also available as `additem`)
- `removeitem <inventory ID/self> <item ID> [amount]`
- `createinventory <inventory ID> [type]`
- `openinventory [inventory ID/self]`
- `resizeinventory <inventory ID/self> <columns> <rows>`
- `setinventorymetadata <inventory ID/self> <JSON object>`
- `setitemmetadata <inventory ID/self> <item ID> <JSON object>`
- `inspectinventory [inventory ID/self]`

For example `additem 1 radio 1`, then open with TAB. TAB opens your inventory plus the glovebox while seated, or a nearby unlocked trunk when standing at its rear. Vehicle targets remain available. First access creates persistent storage keyed by plate. Configure all 23 classes and model overrides in data/vehicles.lua; add custom model classes there or in data/vehicle_models.lua.

Give yourself `wallet` or `backpack` with additem, then double-click or right-click Use. Each gets a unique persistent container. Wallets accept cards/cash; backpacks accept wallets but exclude other backpacks by default.

Shops use size={x=8}; height is calculated from footprints with a minimum of two rows. Legacy shop y values are ignored.

## Verification

Run `lua tests/database_inventory.lua` from the resource directory for mocked SQL and FiveM checks. This covers schema fields, character ownership/isolation, metadata, rotation, shared viewer settings, transactional rollback, paid purchase refunds, temporary drops and resource reloads. The React UI is built with `npm run build`.

Restart the updated tss_bridge before tss-inventory when applying this update. No database wipe is needed for these storage features.

Live MySQL connectivity, framework character events, targets and multiplayer behavior should also be checked in-game after resource startup.

## Player settings

Use `/inventorysettings` for notification position (eight positions with live preview) and Reset windows. Save stores the notification position per character in the personal inventory settings JSON. Cancel discards preview changes. Reset immediately restores default floating positions and invalidates that character's saved docking/minimised layouts for all inventories, including closed windows; other players' layouts remain unchanged. Escape closes settings and keeps an already-open inventory available. No schema change or table wipe is needed.

## Extra inventory windows

Config.ExtraInventories defines additional persistent player-owned grids. backpack_slot opens with your inventory and accepts a backpack without taking space in the main grid. Use the backpack directly from that window to open its contents. Slots have independent docking settings and enforce restrictions on the server. Creation, safe resizing, disabling and runtime registration exports are listed in exports.md.

The split-stack modal includes 25%, 50% and 75% buttons to the left of a compact number field. Percentages round down with a minimum of one item. Unavailable context actions are hidden, including Use when useable is explicitly false. Move quantity has been removed.

## Dynamic container weight

Config.DynamicContainerWeight is enabled by default. The personal inventory total includes carried container contents recursively and equipped extra-inventory items, including their contents. Moving items between personal storage, a backpack, nested wallet and equipped slots changes grid space without reducing total carried weight. Dropping/transferring a bag removes its full weight from the previous holder and adds it to the recipient.

The player limit and each container's own maxWeight are enforced server-side against the complete proposed transfer, so moving contents out of a backpack at the player limit does not count them twice. GetInventoryWeight and UI totals use the same calculation. Totals are derived from saved links rather than stored in the database. Set the toggle false to restore direct-item weights. Restart the resource after changing the toggle; no schema change or wipe is required.

## Quick transfers and item keys

Shift + left-click moves the full item/stack between the player and the last interacted-with external inventory. Ctrl + left-click moves half a stack, rounded down. Clicking a window, title or dock tab makes it the external target; clicking the player window does not forget that target. Clicking an external item with either shortcut moves it back to the player. The server fills matching stacks before free cells and refuses the whole transfer if space, rules or weight do not permit it. Shop catalogues still require purchases.

Usable items have Keybind in their context menu. Click it, then press a keyboard key; ESC cancels capture. A bound item shows Unbind key instead. Bindings are per character and item type, saved in the personal inventory settings JSON, so splitting or transferring stacks does not change the binding. One key targets one item type; rebinding replaces its previous assignment. Pressing it uses a matching carried item, including items in equipped slots or carried containers. Backpack/wallet keys open their storage.

Item keys use raw keyboard state while the inventory is closed and NUI key events while open. They do not add FiveM key mappings or console binds. Held keys do not repeat and chat/focused UI/pause input is ignored. Game controls themselves are not remapped. No table wipe is needed.

## Migrating other scripts

The common qb-inventory-style exports are available without a framework layer: HasItem (client/server), CanAddItem, item getters, usable registration/UseItem, metadata, weight/slot helpers and clears. AddItem/RemoveItem accept player-ID forms as well as native TSS inventory-ID forms. See exports.md for exact signatures and grid differences, and migration.md for small manual core-function replacements. No framework source is modified automatically.

## Player crafting

Define recipes in `data/crafting.lua`. The recipe key is the output item name. `input` must contain exactly two different item names and their required amounts. `time` is the crafting duration in seconds. Each craft produces one output item.

Drag either ingredient onto the other in your own player inventory. Both selected stacks must contain the required amounts. A matching recipe previews the output and marks its space green. The output uses the target item's position if it fits, then the dragged item's position, then the first available space.

Release to craft. A green outline fills around the result while crafting. Items cannot be moved or used and the inventory cannot be closed until it finishes. ESC cancels without consuming ingredients. The server checks the recipe, ingredients, space and weight, and only saves the result when its timer finishes.

## Cash as an item

Set `Config.MoneyAsItem = true` to link the main player inventory's `cash` items to the bridge cash account. It is enabled by default for testing. Set it to `false` and restart to use ordinary cash items without account syncing.

The account balance sets the inventory cash amount when a character loads. Account changes made by other scripts sync within one second, and inventory access also checks the balance. Dropping cash or moving it into storage debits the account. Picking it up or moving it back credits the account. Cash in stashes, vehicles, wallets and backpacks is physical stored money and is not included in the spendable cash account.

Cash shop purchases charge once and update the cash item. Bank purchases only charge the bank account. Failed inventory saves reverse cash account changes; failed shop saves refund the original payment account. Offline cash item edits are refused while this toggle is enabled.

Cash has zero weight and a large stack limit while syncing is enabled. If an external cash grant arrives while there is no cash stack and no free slot, the funds stay safely in the account. The cash item appears when a slot becomes available. Cash items represent whole currency units; fractional account amounts remain in the account. No extra SQL table is required.

## Close inventory on item use

Items inherit `shouldClose = true` from `Config.ItemDefaults`. Using a registered usable item closes an open inventory before its handler runs, including context-menu use, double-click, item keys and the `UseItem` export. Set `shouldClose = false` on an item definition to keep the inventory open. The example wallet and backpack use `false` so opening their storage keeps the inventory visible.

## Item rarity and give-item metadata

`Config.Rarity.enable` controls rarity frames. Each entry in `Config.Rarity.tiers` is a six-digit hex colour. Items with `metadata.rarity` matching a configured tier display that frame around their occupied slots. Missing or unknown rarity values display no frame. Item images stay unchanged.

Give player 1 a rare backpack:

```text
/giveitem 1 backpack 1 {"rarity":"rare"}
```

Give it a custom item label and additional metadata:

```text
/giveitem 1 backpack 1 {"rarity":"legendary","label":"Jack's Backpack","ownerName":"Jack"}
```

Replace `1` with the player's server ID. Specify the amount before JSON metadata. `/additem` accepts the same arguments. Both names use the bridge command metadata and accept either the `command.giveitem` or `command.additem` ACE permission.
