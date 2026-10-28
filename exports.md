# TSS Inventory exports

Call `exports['tss-inventory']:ExportName(...)`. Server mutations return `true` or `false, reason`, except creation returns `true, inventoryCopy`. Getters return copies. Inventory IDs are strings; item IDs, amounts and 1-based grid coordinates are integers. Weight is grams.

Exports requiring storage return `false, reason` until database startup completes. Personal inventories use bridge character IDs, never transient server IDs. Framework characters must be loaded first.

## Server: inventories

| Export | Arguments and behavior |
| --- | --- |
| `GetPlayerInventory` | `(playerSource)` -> load/create `player_<citizenid>`; returns copy or nil, reason. |
| `GetInventory` | `(inventoryId)` -> complete inventory copy or nil. Trusted server callers receive owner/settings. |
| `GetContainer` | `(inventoryId)` -> persistent non-player inventory copy or nil. |
| `GetContainersByOwner` | `(citizenId)` -> saved container copies. |
| `CreateInventory` | `(inventoryId, typeName, options?)` -> create named inventory; rejects existing IDs. |
| `CreateContainer` | `(typeName, options?)` -> create container; options.inventoryId is optional, otherwise ID is generated. Use dedicated APIs for player/shop/drop types. |
| `DeleteContainer` | `(inventoryId)` -> delete container from SQL and revoke viewers; refuses player/shop/drop inventories. |
| `SetInventoryOwner` | `(inventoryId, citizenId?)` -> assign/remove container owner. Player ownership is fixed. |
| `SetInventoryCoords` | `(inventoryId, {x,y,z,w?} or false)` -> set/clear persistent coordinates. |
| `OpenInventory` | `(playerSource, inventoryId?)` -> grant/open alongside personal inventory. Caller authorizes ordinary stashes; vehicle and item-bound storage still require live access checks. |
| `CloseInventory` | `(playerSource, inventoryId?)` -> revoke one window, or close entire session. |
| `OpenVehicleInventory` | `(playerSource, networkId, 'trunk' or 'glovebox')` -> validate entity, plate, distance, routing bucket, locks/occupancy; open persistent vehicle storage. |
| `OpenItemContainer` | `(playerSource, sourceInventoryId, itemId)` -> open carried wallet/backpack, lazily creating its container. Source window must already be open. |
| `ResizeInventory` | `(inventoryId, {x,y}, repack?)` -> resize; true repacks contents. Refuses any item loss. |
| `SetInventoryLabel` | `(inventoryId, label)` -> replace label, maximum 100 bytes. |
| `SetInventoryMetadata` | `(inventoryId, metadata)` -> replace inventory metadata; preserves reserved containerItem link. |
| `SetInventoryRules` | `(inventoryId, {whitelist?,blacklist?,maxWeight?})` -> replace supplied fields if existing contents comply. Empty lists clear restrictions. |
| `GetInventoryWeight` | `(inventoryId)` -> total item weight or nil. |
| `RegisterInventoryType` | `(typeName, definition)` -> register/replace creation template; requires size. |
| `GetInventoryType` | `(typeName)` -> template copy or nil. |
| `GetInventorySettings` | `(inventoryId, citizenId)` -> character's saved window settings or nil. |
| `SetInventorySettings` | `(inventoryId, citizenId, {x,y,dock?,minimised,active?})` -> replace one viewer's settings. Persistent inventories only. |

Creation options: `label`, `size={x,y}`, `metadata`, `owner` (CID), `playerSource` (resolve owner through bridge, takes precedence), `coords={x,y,z,w?}`, `whitelist`, `blacklist`, `maxWeight`. Ownership is stored data; the calling server resource decides who may open a normal stash. Coordinates do not create an interaction automatically.

Settings are stored in each row as a JSON object keyed by viewer CID. Dock is false for floating, or `left-top`, `left-bottom`, `right-top`, `right-bottom`, `top-left`, `top-right`, `bottom-left`, `bottom-right`. The UI saves floating position, docking, minimised state and active-tab preference automatically. Only the current viewer's settings are sent to the client.

```lua
local inventory = exports['tss-inventory']
local created, container = inventory:CreateContainer('stash', {
    inventoryId = 'business_test',
    playerSource = playerSource,
    label = 'Business storage',
    size = { x = 8, y = 6 },
    metadata = { business = 'test' },
})
if created then inventory:OpenInventory(playerSource, container.id) end
```

## Server: items

| Export | Arguments and behavior |
| --- | --- |
| `GetItemDefinition` | `(itemName)` -> merged item definition or nil. |
| `GetItemDefinitions` | `()` -> map of merged item definitions. |
| `GetItemCount` | `(inventoryId, itemName, exactMetadata?)` -> count, optionally requiring complete metadata equality. |
| `CanCarryItem` | `(inventoryId, itemName, amount, metadata?)` -> check grid, stacking, restrictions and weight without mutation. |
| `AddItem` | `(inventoryId, itemName, amount, metadata?, notification?)` -> fill compatible stacks then free cells, all or nothing. |
| `AddItemToSlot` | `(inventoryId, itemName, amount, metadata, itemId)` -> add to a compatible existing stack; slot means item instance ID. |
| `RemoveItem` | `(inventoryId, itemId, amount, notification?)` -> remove from one item instance. |
| `RemoveItemsByName` | `(inventoryId, itemName, amount, metadataFilter?, itemId?)` -> atomic removal across matching stacks. Table filter matches supplied fields; string matches metadata.type. |
| `MoveItem` | `(fromId, toId, itemId, amount, x, y, rotated?)` -> move, rotate, split or merge. Both persistent participants save in one transaction. Container cycles are refused. |
| `SetItemMetadata` | `(inventoryId, itemId, metadata)` -> replace item metadata; preserves reserved containerId link. |
| `RegisterUsableItem` | `(itemName, callback, ownerResource?)` -> callback receives `(playerSource, itemCopy, inventoryId)` and may call exports. Consume explicitly. Unregistered when owner resource stops. Wallet/backpack opening is built in. |

Metadata accepts JSON objects and nested objects with strings, booleans and finite numbers, maximum depth 8 and Config.MaxMetadataBytes. Server validates quantities, placement, revision and access. Catalogue items can only be purchased. `useable=false` disables normal item use.

## Server: shops and drops

| Export | Arguments and behavior |
| --- | --- |
| `RegisterShop` | `(shopId, definition)` -> register catalogue/location using data/shops.lua format: label,coords,distance,bucket?,account,size={x=8},stock. |
| `OpenShop` | `(playerSource, shopId)` -> distance/bucket-checked opening alongside personal inventory. |
| `DropItem` | `(playerSource, itemId, amount, rotated?)` -> move from personal inventory into a pooled temporary drop. When drops are disabled, delete instead. |
| `CreateDrop` | `({coords,items,size?,label?,metadata?,bucket?})` -> create temporary drop; items are `{name,amount?,metadata?,rotated?}` entries. Requires drops enabled. Bucket defaults to 0. |
| `GetDrops` | `()` -> copies of active drop inventories. |
| `RemoveDrop` | `(dropInventoryId)` -> remove contents, drop listing and viewer grants. |

Shop width defaults in example config to 8. Height starts at 2 and expands for actual product footprints within Config.MaxDimension/MaxCells. Stock quantity does not consume additional catalogue cells. Products wider than the columns or exceeding global limits reject registration without replacing the old catalogue. Paid purchases that fail SQL persistence are rolled back and refunded through the bridge; refund failures log REFUND REQUIRED.

World drops are memory-only and never create SQL rows. Player removal is saved before broadcasting a drop. Failed saves restore items. Drops disappear on resource/server restart, even if a dropped bag's separate persistent contents remain saved.

## Vehicle storage

IDs are `trunk_<hex plate>` and `glovebox_<hex plate>`. Trimmed uppercase plates are hex-encoded to preserve distinct punctuation/spaces safely. Vehicles with identical normalized plates share storage. Metadata records readable plate and initial model/class. Owner records the character that created the row; it is not a vehicle ownership permission.

Distance, routing bucket, entity identity and locks are checked on opening and every client action. Trunks require an unlocked vehicle and the player outside; gloveboxes require the player inside that vehicle. Access is revoked when those conditions stop applying. Targets use tss_bridge. TAB opens the glovebox while seated, or the nearest unlocked trunk when standing at its rear; otherwise it opens only your inventory. There are no separate vehicle keybindings.

All classes 0-22 have explicit entries in data/vehicles.lua. False disables a compartment: cycles, trains and open-wheel cars are disabled by default, and motorcycles have no glovebox. A model entry replaces its class entry; use class to assign addon models. data/vehicle_models.lua is a standalone model/class reference with no runtime framework dependency. Unknown models use conservative Config.VehicleDefaults or a known server vehicle-type class. Clients cannot choose class or size. Existing inventories retain saved sizes until resized through exports.

## Wallets and backpacks

Definitions use `container='wallet'` or `container='backpack'`, with stack=false. First use creates a unique `<type>_<suffix>` inventory and atomically saves the parent item's metadata.containerId with it. Double-click or right-click Use opens both windows. Contents follow transfers between players. Only carried containers can open, including a wallet inside a carried backpack. Moving/dropping the parent item revokes old access immediately.

Wallet accepts cash, ID and driving licences. Backpack accepts wallets but excludes backpacks by default. A parent cannot go inside itself or any descendant even if item restrictions change. SetInventoryMetadata and SetItemMetadata preserve server-owned containerItem/containerId fields. Do not copy these fields when giving a different item through exports. Removing an item leaves its saved container available for trusted admin recovery; the row is not deleted automatically.

## Client

| Export | Arguments and behavior |
| --- | --- |
| `GetLocalInventory` | `()` -> cached personal inventory copy or nil until loaded; informational only. |
| `GetItemDefinitions` | `()` -> merged shared definitions. |
| `OpenSelf` | `()` -> dispatch personal inventory request; includes the glovebox while seated, or a nearby unlocked trunk while at its rear. |
| `OpenShop` | `(shopId)` -> dispatch server-validated shop request. |
| `CloseInventory` | `()` -> close UI and release focus/session. |

Client request exports return true for dispatch, not confirmation of server approval. Server exports are for trusted resources, including the tss_bridge inventory adapter.

## Item box notifications: `ItemBox`

Server: `ItemBox(playerSource, itemName, 'added' or 'removed', amount?)`. Client: `ItemBox(itemName, 'added' or 'removed', amount?)`. Displays a small item image with Added/Removed at the right of the screen for 2.5 seconds, even with inventory closed. Does not change items or require database readiness. Amount defaults to 1; the minimal box only displays the image and action text.

AddItem accepts an optional fifth argument; RemoveItem accepts an optional fourth. Pass true to notify the connected owner of a personal inventory, or a player server ID to notify a specific player (including when changing a stash). Omit or pass false for no notification. Notifications only display after successful saves.

```lua
local inventory = exports['tss-inventory']
inventory:AddItem('player_ABC123', 'bandage', 1, {}, true)
inventory:RemoveItem('player_ABC123', itemId, 1, true)
inventory:ItemBox(playerSource, 'bandage', 'added', 1) -- notification only
```

## Player settings modal

`/inventorysettings` opens a standalone themed modal. Notification position supports top-left, top-center, top-right, middle-left, middle-right, bottom-left, bottom-center and bottom-right. The modal shows a live item-box preview; Save persists the position per character, Cancel keeps the previous position.

Personal inventory `settings.preferences` stores notificationPosition and windowLayoutVersion. Window reset increments this version so old placements are invalid for every inventory, including rows not currently loaded. Viewer layout entries retain their layoutVersion alongside x/y/dock/minimised/active. GetInventorySettings returns nil for invalidated placements. Reset does not change item contents, grid sizes or other players' preferences. No new database columns are required.

## Extra player inventories

Config.ExtraInventories defines character-owned windows that automatically open beside the personal inventory, including when opening a shop/container. The backpack_slot example is a 2x3 grid accepting only backpack. Items move using the normal grid drag/drop. Backpacks in extra slots remain carried and can open their contents. Item restrictions, sizes, weight and ownership are checked server-side. Drop actions work from owned extra windows too.

Extra rows use `extra_<citizenid>:<slotName>` in tss_inventory_containers with type extra. Per-character definitions and disabled slots persist in the personal inventory settings JSON. Normal window docking and reset settings also apply. No schema changes or database wipe are required.

All exports below are server-side and accept player server IDs. Inventory getters return copies. Slot names are 1-64 letters, digits, underscores or hyphens. Definitions support label, size={x,y}, whitelist, blacklist, maxWeight and metadata. Up to 32 definitions per character. Existing configured rows keep their saved sizes/rules; use UpdateExtraInventory or ResizeExtraInventory to change them.

| Export | Arguments and behavior |
| --- | --- |
| `RegisterExtraInventory` | `(slotName, definition)` -> register/replace a global creation template for this resource run; attach on next inventory open. Put permanent defaults in Config.ExtraInventories. |
| `GetExtraInventoryDefinitions` | `(playerSource?)` -> global definitions, or effective enabled definitions including a character's overrides. |
| `CreateExtraInventory` | `(playerSource, slotName, definition?)` -> create/update and enable for one character; returns true, inventory copy. Omit definition to enable a registered/configured or previously disabled slot. |
| `GetExtraInventory` | `(playerSource, slotName)` -> load/create enabled slot and return copy, or nil, reason. |
| `GetExtraInventories` | `(playerSource)` -> array of enabled slot copies, creating missing rows. |
| `UpdateExtraInventory` | `(playerSource, slotName, changes, repack?)` -> update supplied fields and persist definition/row atomically; returns true, inventory copy. Refuses rules/sizes that would invalidate items. |
| `ResizeExtraInventory` | `(playerSource, slotName, {x,y}, repack?)` -> safe per-character resize, returning true, inventory copy. |
| `RemoveExtraInventory` | `(playerSource, slotName)` -> disable/remove window for this character; refuses nonempty inventories. Empty row and definition remain for re-enabling. Does not delete contents or other characters' slots. |
| `OpenExtraInventory` | `(playerSource, slotName)` -> open enabled slot alongside personal inventory and other extras. |

Use regular AddItem, RemoveItem, MoveItem, SetInventoryMetadata and other item-management exports with the returned inventory.id. AddItem's notification=true also resolves an extra slot's character owner. Extra ownership cannot be reassigned, and DeleteContainer cannot remove extras; use RemoveExtraInventory after emptying the slot.

```lua
local inventory = exports['tss-inventory']
local created, extra = inventory:CreateExtraInventory(playerSource, 'wallet_slot', {
    label = 'Wallet',
    size = { x = 1, y = 1 },
    whitelist = { 'wallet' },
})
if created then inventory:OpenExtraInventory(playerSource, 'wallet_slot') end
```

## Dynamic weight

With Config.DynamicContainerWeight=true, GetInventoryWeight and client snapshots include linked container contents recursively. Personal inventories also include enabled extra slots and any containers inside them. All AddItem/CanCarryItem/MoveItem operations validate ancestor weight limits as well as the target's limit. Moving items within the carried hierarchy does not increase its total; loaded bags carry their contents' weight when moved between holders or into world drops.

Set false for direct-item weight only. No extra export arguments or database schema changes are required. Parent lookups for offline item-bound storage are performed in database.lua; ordinary carried inventories use cached parent links. Derived totals refresh after content changes even when the personal inventory's own item list stays the same.

## Private item keys and quick transfers

No new export arguments are required. UI quick-transfer requests use the same server access, revision, restriction, weight and container-cycle checks as normal moves. Half transfers round down, and one-item stacks cannot be split. Automatic placement fills compatible stacks first and can rotate into a free footprint. A failure never leaves a partially transferred stack.

Personal settings.itemKeybinds maps keyboard virtual-key strings to `{itemName,keyLabel}`. These character-owned assignments are separate from FiveM mappings and from window/preferences settings. Bindings follow item types and resolve a carried instance when used. Existing RegisterUsableItem callbacks receive the real inventory ID containing that instance; consume from that ID. Non-usable items cannot acquire a binding, but an existing binding can still be removed if useable is later disabled.
