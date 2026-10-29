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

`Config.CleanUpEmptyInventories = true` removes empty rows from `tss_inventory_containers` once during startup, before inventories load. Player inventories and non-empty or malformed item data are preserved. Deleted rows lose their saved metadata, settings and custom rules too. Set it to `false` to keep empty inventories.

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

For example `additem 1 radio 1`, then open with TAB. TAB opens your inventory plus the glovebox while seated, or a nearby unlocked trunk when standing at its rear. Trunk targets use the boot bone through tss_bridge. A successfully opened trunk inventory opens its boot door; it stays open until the last viewer closes or loses access. First access creates persistent storage keyed by plate. Configure all 23 classes and model overrides in data/vehicles.lua; add custom model classes there or in data/vehicle_models.lua.

Give yourself `wallet` or `backpack` with additem, then double-click or right-click Use. Each gets a unique persistent container. Wallets accept cards/cash; backpacks accept wallets but exclude other backpacks by default.

Drag an allowed item onto a carried container's icon to store it without opening its window. Item rules, capacity, weight and nesting are checked on the server. Use the repack button in an inventory title bar to compact its grid; it tries several layouts and keeps the best result without changing item IDs, amounts or metadata. Shop catalogues cannot be repacked by players.

`Config.UseItemsFromContainers = true` allows item use inside carried backpacks, wallets and nested containers, including containers in extra slots. It applies to window actions, usable-item exports and item keybinds. Stashes, vehicle compartments and containers the player is not carrying are excluded. Set it to `false` to restrict item use to the main inventory and extra slots; opening carried containers still works.

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

Set `Config.MoneyAsItem = true` to link all carried `cash` items to the bridge cash account. It is enabled by default for testing. Set it to `false` and restart to use ordinary cash items without account syncing.

The account balance sets the inventory cash amount when a character loads. Account changes made by other scripts sync within one second, and inventory access also checks the balance. The total includes the main inventory, equipped extra inventory slots, and linked containers nested inside either. Moving cash between these carried inventories keeps the account balance unchanged. Dropping cash or a funded container, or moving it into a stash or vehicle, debits the account. Picking it back up credits it. Transferring a funded container to another player transfers its cash between accounts.

Cash shop purchases charge once and update the cash item. Bank purchases only charge the bank account. Failed inventory saves reverse cash account changes; failed shop saves refund the original payment account. Offline cash item edits are refused while this toggle is enabled.

Cash has zero weight and a large stack limit while syncing is enabled. If an external cash grant arrives while there is no cash stack and no free slot, the funds stay safely in the account. Existing carried cash stacks are updated first. If there is no stack, syncing uses an allowed free slot in a carried inventory. The cash item appears when a slot becomes available. Cash items represent whole currency units; fractional account amounts remain in the account. No extra SQL table is required.

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

## Built-in weapons

`Config.EnableWeaponSystem = true` enables the standalone weapon module. Set it to `false` and restart to use an external weapon resource. The disabled module does not equip weapons, change ped weapon controls, handle reloads or intercept external usable-item callbacks.

Define weapons in `data/weapons.lua`. Each definition has `weapon` (the GTA weapon name), `ammoItem` (the inventory ammunition item), and `clipSize`. Omit `ammoItem` for melee weapons. Weapons must be non-stacking usable items. The supplied list is registered as 106 native TSS weapon items. Addon-only weapons still need their streamed assets, and newer GTA weapons need a compatible server game build.

Use a weapon item to equip it. Use the same instance again to holster it. R reloads while holding it and outside inventory menus. Each ammunition item represents one round; reloading takes only the rounds needed for the magazine, from main inventory, extra slots or linked carried containers. Loaded rounds are stored in the weapon instance's `metadata.ammo`. Native automatic reload is disabled while the module manages a weapon.

```text
/giveitem 1 weapon_pistol 1
/giveitem 1 pistol_ammo 24
```

Use the pistol and press R. Use it again to unequip. The module also supports the existing item keybinds. Dropping, removing or moving the equipped weapon to another inventory holsters it. Character unload, death and resource stop remove the managed ped weapon. Only server-validated carried items can be equipped, and clients cannot increase saved ammo through ammo reports.

Use one weapon controller at a time. Disable `qb-weapons` or another weapon controller while testing the built-in module, or set this resource's toggle to `false` to use that controller.

## Weapon attachments

Weapon definitions are in `data/weapons.lua`. Attachment items, slot types, tint indexes and per-weapon component names are in `data/attachments.lua`. These are native TSS data files; no QBCore dependency is required.

Right-click a carried weapon and choose **Attachments**. Drag the weapon model to rotate it. Drag a compatible attachment into the inspection area, then release it over the green fitting highlight to install it. Physical attachments use their game models while being dragged; finishes, camo and tints use `prop_cs_spray_can`. Releasing away from the fitting point cancels placement. Installing a replacement returns the old part. Right-click an installed part at its fitting point and choose **Disassemble** to return it to your inventory. ESC closes the view and restores the camera.

Fitting highlights follow the model's attachment bones. Weapons without those bones use model bounds as a fallback. For an addon model that needs different attachment points, add `attachmentAnchors = { scope = { x = 0.0, y = 0.0, z = 0.1 } }` to its weapon definition, using model-local coordinates.

Applying a finish or tint plays a short red weapon-highlight effect after the server confirms installation. It uses `scr_sr_lg_weapon_highlight` from `scr_sr_adversary`, centred on the weapon and sized to its preview model. Closing the inspection view stops the effect. The spray can is only used as the dragged item model.

```text
/giveitem 1 weapon_pistol 1
/giveitem 1 clip_attachment 1
/giveitem 1 flashlight_attachment 1
/giveitem 1 suppressor_attachment 1
```

Installed parts are stored as `metadata.attachments[slot] = { name = 'attachment_item', metadata = {} }`. Component hashes are resolved from trusted definitions when the weapon equips. Tints and finishes use their own slots. Part metadata is preserved on removal, and installed part weight contributes to weapon weight.

Extended magazines change the configured capacity. Removing a magazine returns any excess loaded rounds as ammunition items. If returned parts or rounds will not fit, the change is refused. Inventory changes are saved together; failed saves keep the original weapon and parts. Editing is blocked during crafting and weapon reloads.

Weapon `ammoMode` values are `firearm`, `melee`, `throwable`, `rechargeable`, `fuel` and `unarmed`. Throwable weapon items are consumed when their loaded unit is used. Stun/energy weapons use native recharge behaviour. Fuel tools start with `initialAmmo` and use fuel/refill units when reloaded. New launcher/refill ammunition definitions are registered alongside the weapons. Images for the newly imported entries are left for the next asset pass.

## Clothing items

Set `Config.EnableClothingSystem = true` to enable clothing. Set it to `false` to leave appearance control to your other scripts. Disabled mode adds no clothing controls and does not change the player's appearance.

Click the clothing button in your inventory title bar to open the equipment slots. Drag clothing onto its slot, or use the item to equip it. Double-click worn clothing, or right-click it and select **Unequip**, to return it to your inventory. Worn items and their metadata are saved with the character.

Clothing item definitions are in `data/clothing.lua`. `clothingSlot` decides where an item can be worn. Item metadata chooses the gender and appearance:

```lua
metadata = {
    label = 'Example Shirt',
    clothing = {
        gender = 'male', -- 'male' or 'female'
        drawable = 0,
        texture = 0,
        arms = { drawable = 0, texture = 0 }, -- optional, tops only
        undershirt = { drawable = 0, texture = 0 }, -- optional, tops only
    },
}
```

Use matching drawable and texture numbers from your clothing pack. Male and female variations have different numbers. The system supports male and female freemode characters. It checks available variations before applying them.

Example admin command (replace `1` with the player's server ID):

```text
/giveitem 1 shirt 1 {"label":"Example Shirt","clothing":{"gender":"male","drawable":0,"texture":0,"arms":{"drawable":0,"texture":0}}}
```

Available equipment slots: `top`, `undershirt`, `pants`, `shoes`, `mask`, `bag`, `accessory`, `vest`, `decals`, `hat`, `glasses`, `ears`, `watch`, `bracelet`. Definitions assign these slots; metadata cannot change an item into a different slot. Clothing bag/vest items affect appearance only; backpacks and armour keep their existing behaviour.

A top's optional `arms` and `undershirt` values help prevent clipping. A separately equipped undershirt takes priority. Unequipping restores the appearance from before the first clothing item was equipped. If there is no room to return replaced clothing, the change is refused.

Do not have another appearance script continuously overwrite the same equipped components. Initial character appearance loading is supported; saving full outfits to other clothing resources is separate.
