# Exports

```lua
local inventory = exports['tss-inventory']
```

All exports are server-side unless listed under Client.

- `playerSource`: the player's server ID.
- `inventoryId`: the inventory's saved ID, such as `player_ABC123` or `business_storage`.
- `target`: either a player server ID or an inventory ID.
- `itemId` / `slot`: the ID of an item stack, not a grid position.
- `?`: optional argument.
- Weights use grams. Grid positions start at 1.

Most changes return `true` or `false, error`. Creation returns `true, inventory` or `false, error`. Item and inventory getters return copies. Load the character before calling player inventory exports.

## Find inventories

| Export | Returns |
| --- | --- |
| `GetPlayerInventory(playerSource)` | The player's inventory; creates it if needed. |
| `GetInventory(inventoryId)` | The inventory, or nil. |
| `GetContainer(inventoryId)` | A saved container, or nil. |
| `GetContainersByOwner(citizenId)` | A list of the character's containers. |
| `GetInventoryType(typeName)` | The defaults for an inventory type. |

## Create and open inventories

| Export | Action |
| --- | --- |
| `CreateInventory(inventoryId, typeName, options?)` | Create an inventory from a type. |
| `CreateInventory(inventoryId, data)` | Create a stash using `label`, `size` or `slots`, and `maxweight`. |
| `CreateContainer(typeName, options?)` | Create a container. Set `options.inventoryId` to choose its ID. |
| `OpenStash(playerSource, stashName)` | Open a fixed stash from `data/containers.lua`. Checks distance and character ownership. |
| `OpenInventory(playerSource, inventoryId?, data?)` | Open the inventory alongside the player's inventory. Omit the ID to open their own. Supply data to create a missing stash. |
| `CloseInventory(playerSource, inventoryId?)` | Close one window, or omit the ID to close everything. |
| `DeleteContainer(inventoryId)` | Delete a container. Player inventories, shops, drops and extra slots are excluded. |
| `RegisterInventoryType(typeName, definition)` | Set defaults for newly created inventories. Requires `size`. |
| `OpenVehicleInventory(playerSource, networkId, compartment)` | Open a vehicle's `trunk` or `glovebox`. |
| `OpenItemContainer(playerSource, sourceInventoryId, itemId)` | Open a carried wallet or backpack. Its source window must already be open. |

Container options: `inventoryId`, `label`, `size={x,y}`, `metadata`, `owner`, `playerSource`, `coords={x,y,z,w?}`, `whitelist`, `blacklist`, `maxWeight`.

Use `owner` for a character ID, or `playerSource` to find the owner through the bridge. Check access in your script before opening a stash. Coordinates alone do not create a target or ped.

```lua
local created, container = inventory:CreateContainer('stash', {
    inventoryId = 'business_storage',
    label = 'Storage',
    size = { x = 8, y = 6 },
    playerSource = playerSource,
})

if created then
    inventory:OpenInventory(playerSource, container.id)
end
```

## Fixed stashes

Add an entry with `coords` to `TSSContainers` in `data/containers.lua`:

```lua
business_storage = {
    label = 'Business Storage',
    size = { x = 8, y = 6 },
    coords = vector3(760.24, 1280.56, 360.3),
    distance = 2.0,
    shared = true,
    target = true,
    openWhenNearby = true,
    metadata = {},
},
```

- `shared = true`: everyone uses the same contents. `false`: separate contents for each character. Defaults to `true`.
- `target = true`: add an interaction through the bridge. Set `false` to disable it.
- `openWhenNearby = true`: include the stash when the player opens their inventory nearby with TAB. Set `false` for target/export-only access.
- Distance-based stashes (`target = false`, `openWhenNearby = true`) can draw a marker using `Config.FixedStash`. Target stashes never draw a marker.
- `distance`: maximum distance from the coordinates. Defaults to `2.0` metres. The server also removes access when the player moves away.
- Optional `bucket` restricts access to one routing bucket. Omit it for access in any bucket.
- `whitelist`, `blacklist` and `maxWeight` use the normal inventory rules.

Marker configuration in `config.lua`:

```lua
Config.FixedStash = {
    Marker = 2, -- nil disables markers
    drawDistance = 5.0,
}
```

`drawDistance` controls visibility only; each stash's `distance` controls access.

Stashes are created on first use and saved to the database. Shared IDs are `stash_business_storage`; personal IDs are `stash_business_storage:<citizenId>`. Entries without `coords`, such as backpacks and wallets, remain carried container types.

Configured labels, positions, sizes and rules apply when reopened. Size changes preserve items and fail if the contents cannot fit. Item metadata and saved window positions are retained.

To open one from another server script while the player is nearby:

```lua
local opened, errorMessage = exports['tss-inventory']:OpenStash(playerSource, 'business_storage')
```

## Temporary loot containers (server)

Use `CreateContainer('loot', options)` and open it with `OpenInventory`:

```lua
local inventory = exports['tss-inventory']

local created, container = inventory:CreateContainer('loot', {
    inventoryId = 'loot_container1',
    label = 'Loot',
    size = { x = 8 },
    items = {
        plastic = { amount = { min = 1, max = 5 }, chance = 100 },
        bandage = { amount = 2, chance = 30 },
        water_bottle = {
            amount = 1,
            chance = 20,
            metadata = { label = 'Found Water' },
        },
    },
    maxItems = { min = 1, max = 3 },
    deleteOnEmpty = true,
    playerSource = playerSource,
})

if created then
    inventory:OpenInventory(playerSource, container.id)
end
```

- `items` uses item definition names as keys. Each type is rolled once when created.
- `amount` accepts a whole number or `{ min, max }`. Defaults to `1`.
- `chance` is a percentage from `0` to `100`. Defaults to `100`.
- `maxItems` caps distinct item types selected. Accepts a whole number or `{ min, max }`. Defaults to all supplied types. Quantities may split into multiple stacks.
- Chances are independent; fewer types than the cap may be selected. An empty roll returns `false, 'Loot roll produced no items'` when `deleteOnEmpty` is enabled.
- Omit `size.y` to calculate rows from the rolled items and their footprints. Supply it for a fixed height. Normal grid limits apply.
- `deleteOnEmpty` defaults to `true`. The container disappears for all viewers after its final item is successfully removed. Set `false` to retain an empty container until explicitly deleted or the resource restarts.
- All loot containers stay in server memory, including those with `deleteOnEmpty = false`. They never save to the database.
- `playerSource` sets the owner using the bridge. It does not open the window automatically.
- IDs must be unique. Creating an existing ID returns `false` and does not reroll it. Omit `inventoryId` to generate an ID.

Use `GetContainer(containerId)` to read it and `DeleteContainer(containerId)` to remove it manually. Failed creation returns `false, errorMessage`.

### Item-backed loot containers

A container definition with an `items` table becomes temporary rolled loot. Link an item to it with `container = 'stolen_wallet'`, `stack = false`, `useable = true` and `shouldClose = false`. The `stolen_wallet` item is already defined with the wallet image.

```lua
stolen_wallet = {
    label = 'Stolen Wallet',
    size = { x = 5, y = 1 },
    items = {
        cash = { amount = { min = 1, max = 100 }, chance = 100 },
        lockpick = { amount = { min = 1, max = 2 }, chance = 10 },
    },
    maxItems = { min = 1, max = 2 },
    deleteOnEmpty = true,
},
```

Use the item to open it. Each item instance rolls once; reopening keeps the same remaining contents. Other carried containers, extra slots and item-key bindings use the normal container access rules.

With `deleteOnEmpty = true`, taking its last item deletes both the loot inventory and the linked item in the same transaction. Failed saves restore both. Empty rolls also consume the empty item. Set `false` to retain the empty item and its inventory.

`metadata.containerId` and `metadata.lootOpened` are saved with the item. Loot contents remain in server memory only. After a resource restart, an already-opened wallet cannot reroll; using it removes the expired empty item when deletion is enabled. Cash in carried loot follows `Config.MoneyAsItem`, including automatic spending and synchronization.

```text
/giveitem 1 stolen_wallet 1
```

## Change inventories

| Export | Action |
| --- | --- |
| `ResizeInventory(inventoryId, {x,y}, repack?)` | Resize the grid. Pass true to rearrange items to fit. Fails if items cannot fit. |
| `RepackInventory(inventoryId)` | Compact an inventory, rotating items where useful. Keeps item IDs, amounts and metadata. Shop catalogues are read-only. |
| `SetInventoryLabel(inventoryId, label)` | Save a title in metadata.label. Pass false to restore the stored default title. |
| `SetInventoryOwner(inventoryId, citizenId?)` | Change or clear a container's owner. Player and extra-slot ownership cannot change. |
| `SetInventoryCoords(inventoryId, coords)` | Set coordinates, or pass false to clear them. |
| `SetInventoryMetadata(inventoryId, metadata)` | Replace the inventory's extra data. |
| `SetInventoryRules(inventoryId, rules)` | Change `whitelist`, `blacklist` or `maxWeight`. Empty lists clear item restrictions. |
| `ClearInventory(target, keepItems?)` | Empty the selected inventory. Keep one item name or a list of names if supplied. |
| `ClearStash(inventoryId)` | Empty a stash or container. |

Inventory metadata belongs to the inventory. Item metadata belongs to an individual item. Do not copy or change the container link fields `containerItem` and `containerId` yourself.

## Check items

| Export | Returns |
| --- | --- |
| `HasItem(target, items, amount?)` | Whether every requested item is present. Totals amounts across stacks. |
| `GetItemCount(target, items, exactMetadata?)` | Total amount of one item name or a list of names. |
| `GetItemByName(target, itemName)` | The first matching item, or nil. |
| `GetItemsByName(target, itemName)` | All matching items. |
| `GetItemBySlot(target, itemId)` | The item with that ID, or nil. |
| `GetItemDefinition(itemName)` | The item's definition, including defaults. |
| `GetItemDefinitions()` | All item definitions. |
| `CanCarryItem(inventoryId, itemName, amount, metadata?)` | Whether the items fit. Does not add them. |
| `CanAddItem(target, itemName, amount?, metadata?)` | The same check, also accepting a player server ID. |

`HasItem` accepts a name, a list, or named amounts:

```lua
inventory:HasItem(playerSource, 'bandage', 2)
inventory:HasItem(playerSource, { 'bandage', 'water_bottle' }, 1)
inventory:HasItem(playerSource, { bandage = 2, water_bottle = 1 })
```

A player server ID checks the personal grid. Use the inventory ID to check an extra slot or backpack. Item getters also provide `slot` and `info`, matching the item's `id` and `metadata`.

## Add, remove and move items

| Export | Action |
| --- | --- |
| `AddItem(inventoryId, itemName, amount, metadata?, notification?)` | Add items to matching stacks and free cells. |
| `AddItem(playerSource, itemName, amount, slot?, info?, reason?)` | Add to a player's inventory using the QB-style arguments. |
| `AddItemToSlot(inventoryId, itemName, amount, metadata, itemId)` | Add to an existing matching stack. |
| `RemoveItem(inventoryId, itemId, amount, notification?)` | Remove from one stack. |
| `RemoveItem(target, itemName, amount, slot?, reason?)` | Remove by name, across stacks or from the specified stack. |
| `RemoveItemsByName(inventoryId, itemName, amount, metadataFilter?, itemId?)` | Remove by name, optionally matching metadata or one item ID. |
| `MoveItem(fromId, toId, itemId, amount, x, y, rotated?)` | Move, split, stack or rotate items. |
| `SetItemLabel(inventoryId, itemId, label)` | Rename one item stack through metadata.label. Pass false to restore the item definition label. |
| `SetItemMetadata(inventoryId, itemId, metadata)` | Replace an item's extra data. |
| `SetItemData(target, itemName, key, value, itemId?)` | Set one metadata field. Use `info` or `metadata` as the key to replace all metadata. |

For automatic AddItem placement, omit `slot` or pass false. A supplied slot must be an existing matching stack. Use MoveItem for a specific grid position. Add/remove operations fail without taking part of the requested amount.

For `RemoveItemsByName`, a table filter matches its supplied fields; a string filter matches `metadata.type`. For `GetItemCount`, exactMetadata must match the whole metadata object.

```lua
-- Player-ID form.
inventory:AddItem(playerSource, 'water_bottle', 2, false, { quality = 100 })
inventory:RemoveItem(playerSource, 'water_bottle', 1, false)

-- Inventory-ID form, with a notification.
inventory:AddItem(inventoryId, 'bandage', 1, {}, true)
inventory:RemoveItem(inventoryId, itemId, 1, true)
```

The notification argument accepts true for the player's own or extra inventory, or a player server ID to notify someone specific. Omit it or pass false for no notification. This argument applies to the inventory-ID forms. Reason strings are accepted by the QB-style forms but do not create logs.

## Custom labels

`metadata.label` overrides an item or inventory's display name. Use nonempty text up to 100 bytes.

```lua
inventory:SetItemLabel(inventoryId, itemId, "Jack's Box")
inventory:SetInventoryLabel(inventoryId, "Jack's Storage")

-- Remove the custom label.
inventory:SetItemLabel(inventoryId, itemId, false)
inventory:SetInventoryLabel(inventoryId, false)
```

You can also supply label through AddItem, SetItemMetadata or SetInventoryMetadata. The item name, item ID and other metadata stay unchanged when using the label exports. Labels remain when items move and after restarting.

An item ID identifies a stack. Split it first to rename just one unit. Different labels prevent stacks from merging. A carried container's item label and its window title are separate; use the container's inventory ID to rename its window.

## Usable items

| Export | Action |
| --- | --- |
| `RegisterUsableItem(itemName, callback, ownerResource?)` | Register a callback receiving `(playerSource, item, inventoryId)`. |
| `CreateUsableItem(itemName, callback, ownerResource?)` | Register a callback with `slot` and `info` fields added to the item. |
| `CreateUseableItem(itemName, callback, ownerResource?)` | Another spelling of CreateUsableItem. |
| `GetUsableItem(itemName)` | Return `{func, resource}`, or nil. |
| `UseItem(playerSource, itemNameOrItem)` | Use a real item carried by that player. |
| `UseItem(itemName, playerSource, item?)` | The item-name-first form. |

Define the item in data/items.lua before registering it. Set `useable=false` to disable use. Callbacks do not remove items automatically.

With `Config.UseItemsFromContainers = true`, usable items may come from carried containers. Use the callback's `inventoryId` when removing the item, especially after a timer or client event. Matching player-ID/slot removals made directly inside the callback also use the selected container stack.

```lua
inventory:CreateUsableItem('bandage', function(playerSource, item, inventoryId)
    if not inventory:RemoveItem(inventoryId, item.id, 1) then return end
    -- Apply your effect here.
end)
```

Start the registering script after tss-inventory. Restart it after restarting the inventory. A core function forwarding registrations should pass `GetInvokingResource()` as ownerResource.

## Weight and slots

| Export | Returns |
| --- | --- |
| `GetInventoryWeight(inventoryId)` | The inventory's weight, including contents when DynamicContainerWeight is enabled. |
| `GetFreeWeight(target)` | Remaining grams, or math.huge if no limit is set. |
| `GetTotalWeight(items)` | The direct weight of a supplied item list. |
| `GetSlots(target)` | Used cells, free cells. Multi-cell items use multiple cells. |
| `GetSlotsByItem(items, itemName)` | Matching item IDs from a supplied item list. |
| `GetFirstSlotByItem(items, itemName)` | The first matching item ID, or nil. |

## Shops

| Export | Action |
| --- | --- |
| `RegisterShop(shopId, definition)` | Register a shop using the format in data/shops.lua. |
| `CreateShop(data)` | Register one shop from `{name,label,coords,items,size?,distance?,account?}`. |
| `OpenShop(playerSource, shopId)` | Open the shop alongside the player's inventory. |

CreateShop products accept `name`, `buyPrice` (or legacy `price`), `sellPrice`, `buy`, `sell`, `amount` or `count`, and `info` or `metadata`. Shop-level `buy` and `sell` toggles are also supported. Coordinates are required. Each product name must be unique. Use `size={x=8}`; height is calculated automatically with a minimum of two rows. Use false for unlimited stock.

### Buying and selling

Directions are from the player's perspective: `buy` allows players to buy from the shop; `sell` allows players to sell to it.

```lua
example_shop = {
    label = 'Trade Counter',
    coords = vector4(24.47, -1346.62, 28.50, 266.0),
    pedModel = 'ig_bankman',
    distance = 3.0,
    size = { x = 8 },
    account = 'cash',
    buy = true,
    sell = true,
    stock = {
        plastic = { buyPrice = 5, sellPrice = 2, amount = 100 },
        bandage = { buyPrice = 10, amount = false }, -- buy only
        aluminum = { sellPrice = 3 }, -- sell only
        radio = { buyPrice = 250, sellPrice = 100, sell = false },
    },
},
```

- Prices are per item. Legacy `price` still sets the buy price.
- Omit `sellPrice` to prevent selling a product. Omit both `buyPrice` and `price` for a sell-only product.
- Shop-level `buy = false` or `sell = false` disables that direction for every product. Product flags can further restrict a product. Both product flags set to `false` hide that product.
- An open shop shows green sell prices on eligible carried items. With multiple shop windows, the last touched shop determines these prices.
- Drag a carried stack into the shop to sell it, or right-click it for **Sell** / **Sell amount**. Cash/Bank buttons select the payment or payout account. Trades accept up to 1,000 items at once.
- Selling removes the exact selected instance and does not replenish the catalogue. Empty containers can be sold; containers with contents must be emptied first.
- Prices, quantities, ownership, distance and revisions are checked on the server. Failed payments or saves keep the items and reverse the payment.

`data/shops.lua` contains the converted public shop locations and editable product groups. Buy prices are from the supplied list; sell prices start at half, rounded down. Casino chips exchange 1:1. Ped spawning, targets and map blips use the bridge. `blip = { sprite = 52, colour = 2 }` is optional.


## World drops

| Export | Action |
| --- | --- |
| `DropItem(playerSource, itemId, amount, rotated?)` | Drop items from the player's personal inventory. |
| `CreateDrop(options)` | Create a drop. Requires `coords` and an `items` list. Optional: `size`, `label`, `metadata`, `bucket`. |
| `GetDrops()` | Return all current drops. |
| `RemoveDrop(dropInventoryId)` | Remove a drop and its contents. |

Drop items use `{name,amount?,metadata?,rotated?}`. World drops are not saved and disappear on restart. CreateDrop requires drops to be enabled. DropItem deletes items when WorldDrops.enable is false.

## Extra inventory windows

Define defaults in Config.ExtraInventories. These windows open alongside the player's inventory.

| Export | Action |
| --- | --- |
| `RegisterExtraInventory(slotName, definition)` | Register defaults until the resource restarts. |
| `GetExtraInventoryDefinitions(playerSource?)` | Get defaults, or the player's enabled definitions. |
| `CreateExtraInventory(playerSource, slotName, definition?)` | Create, update or re-enable a slot. Returns true, inventory. |
| `GetExtraInventory(playerSource, slotName)` | Get or create an enabled slot. |
| `GetExtraInventories(playerSource)` | Get or create all enabled slots. |
| `UpdateExtraInventory(playerSource, slotName, changes, repack?)` | Change supplied fields, keeping existing items. |
| `ResizeExtraInventory(playerSource, slotName, {x,y}, repack?)` | Resize the slot's grid. |
| `RemoveExtraInventory(playerSource, slotName)` | Disable an empty slot. Its saved data remains for re-enabling. |
| `OpenExtraInventory(playerSource, slotName)` | Open the slot and the player's inventory. |

Definitions accept `label`, `size`, `metadata`, `whitelist`, `blacklist` and `maxWeight`. Use the returned inventory ID with the normal item exports. Slot names allow 1–64 letters, numbers, underscores or hyphens. Each character can have up to 32 definitions.

```lua
inventory:CreateExtraInventory(playerSource, 'wallet_slot', {
    label = 'Wallet',
    size = { x = 1, y = 1 },
    whitelist = { 'wallet' },
})
```

## Window settings

| Export | Action |
| --- | --- |
| `GetInventorySettings(inventoryId, citizenId)` | Get the character's saved window position, or nil. |
| `SetInventorySettings(inventoryId, citizenId, settings)` | Set `{x,y,dock?,minimised,active?}`. |

Use false for a floating dock value. Dock positions: `left-top`, `left-bottom`, `right-top`, `right-bottom`, `top-left`, `top-right`, `bottom-left`, `bottom-right`.

## Notifications

Server: `ItemBox(playerSource, itemName, action, amount?)`.

Client: `ItemBox(itemName, action, amount?)`.

Use `added` or `removed` for action. The box displays an image and action text for 2.5 seconds. It does not add or remove items. Players choose its position with `/inventorysettings`.

## Client

| Export | Action |
| --- | --- |
| `HasItem(items, amount?)` | Check the local personal inventory. Same name/list/amount formats as the server. |
| `GetLocalInventory()` | Get the local personal inventory, or nil before loading. |
| `GetItemDefinitions()` | Get all item definitions. |
| `OpenSelf()` | Request the player's inventory, plus a nearby trunk or occupied glovebox. |
| `OpenShop(shopId)` | Request a shop. |
| `CloseInventory()` | Close the UI. |
| `ItemBox(itemName, action, amount?)` | Show an item notification. |

Client opening exports return true when the request is sent. The server decides whether it can open.

## Unsupported QB calls

Use GetPlayerInventory instead of LoadInventory. TSS saves changes automatically, so SaveInventory is not needed. SetInventory, RemoveInventory, OpenInventoryById and the QB hook/listener exports are not provided.

## Cash items

When `Config.MoneyAsItem` is enabled, adding or removing `cash` anywhere in an online player's carried inventory tree also changes their cash account. This includes extra slots and linked nested containers. Moving cash within that tree leaves the balance unchanged. Moving cash or a funded container out of the tree debits it; moving it back credits it. Cash edits to offline player inventories are refused. Payment scripts should perform one cash operation; syncing handles the matching account or item change.

## Equipped weapons

These exports apply to the built-in weapon system when `Config.EnableWeaponSystem` is enabled.

| Export | Action |
| --- | --- |
| `GetEquippedWeapon(playerSource)` | Returns the equipped inventory/item IDs, weapon name, loaded ammo and current equipment token, or nil. |
| `UnequipWeapon(playerSource)` | Holsters the managed weapon. Returns false when the built-in system is disabled. |

Use the existing `UseItem(playerSource, selector)` export to equip or toggle a carried weapon. Loaded rounds use `metadata.ammo`; client reports can only decrease that value.

## Weapon attachment inspection

| Export | Action |
| --- | --- |
| `OpenWeaponAttachments(playerSource, inventoryId, itemId)` | Opens the player's inventory and a rotatable 3D attachment view for a carried weapon instance. |
| `GetWeaponAttachmentDefinitions()` | Returns the attachment item, slot, compatibility and tint definitions. |

Installed parts are available through the normal item getters in `metadata.attachments`. Use `data/attachments.lua` to change compatible weapons and slot types. Attachment editing uses the built-in weapon system and requires `Config.EnableWeaponSystem = true`.

## Clothing (server)

Requires `Config.EnableClothingSystem = true`.

```lua
local clothing = exports['tss-inventory']:GetEquippedClothing(playerSource)
-- clothing.inventory.items contains worn items; clothing.slots lists equipment slots.

local success, errorMessage = exports['tss-inventory']:EquipClothing(playerSource, inventoryId, itemId)
local success, errorMessage = exports['tss-inventory']:UnequipClothing(playerSource, 'top')
```

`EquipClothing` moves a carried clothing item into its matching equipment slot. Replaced clothing returns to the main inventory. `UnequipClothing` returns the worn item to the main inventory. Both refuse the change if the returned item cannot fit. These exports are registered only when the clothing system is enabled.
