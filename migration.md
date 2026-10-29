# Framework setup

## 1. Start the resources

Add these settings before the resources start in server.cfg:

```cfg
setr tss_framework qb
setr tss_inventory tss

ensure oxmysql
ensure qb-core
ensure tss_bridge
ensure tss-inventory
```

For Qbox, use `qbox` and `qbx_core`. For ESX, use `esx` and `es_extended`.

Stop the inventory you are replacing. Start item-effect scripts after tss-inventory. Define their items and sizes in tss-inventory/data/items.lua. Existing inventories are not imported automatically.

## 2. Replace QBCore HasItem

In **qb-core/client/functions.lua**, replace `QBCore.Functions.HasItem`:

```lua
function QBCore.Functions.HasItem(items, amount)
    if GetResourceState('tss-inventory') ~= 'started' then return false end
    return exports['tss-inventory']:HasItem(items, amount)
end
```

In **qb-core/server/functions.lua**, replace `QBCore.Functions.HasItem`:

```lua
function QBCore.Functions.HasItem(playerSource, items, amount)
    if GetResourceState('tss-inventory') ~= 'started' then return false end
    return exports['tss-inventory']:HasItem(playerSource, items, amount)
end
```

These accept an item name, a list, or amounts such as `{bandage=2}`. They check the personal inventory and enabled extra slots. `HasItems` accepts the same arguments. Check items on the server before granting an effect or reward.

## 3. Replace QBCore item-use functions

In **qb-core/server/functions.lua**, replace these functions:

```lua
function QBCore.Functions.CreateUseableItem(itemName, callback)
    QBCore.UsableItems[itemName] = callback
    return exports['tss-inventory']:CreateUsableItem(itemName, callback, GetInvokingResource())
end

function QBCore.Functions.CanUseItem(itemName)
    return exports['tss-inventory']:GetUsableItem(itemName)
end

function QBCore.Functions.UseItem(playerSource, item)
    return exports['tss-inventory']:UseItem(playerSource, item)
end
```

Existing callbacks receive `slot` and `info`, along with `id` and `metadata`. Remove consumed items once, on the server. Keep the deprecated client-callable QBCore AddItem/RemoveItem events disabled.

## 4. Add QBCore player item functions

In **qb-core/server/player.lua**, put these inside `QBCore.Player.CreatePlayer`, alongside the other `self.Functions` methods:

```lua
function self.Functions.AddItem(itemName, amount, slot, info, reason)
    return exports['tss-inventory']:AddItem(self.PlayerData.source, itemName, amount or 1, slot, info, reason)
end

function self.Functions.RemoveItem(itemName, amount, slot, reason)
    return exports['tss-inventory']:RemoveItem(self.PlayerData.source, itemName, amount or 1, slot, reason)
end

function self.Functions.GetItemByName(itemName)
    return exports['tss-inventory']:GetItemByName(self.PlayerData.source, itemName)
end

function self.Functions.GetItemBySlot(slot)
    return exports['tss-inventory']:GetItemBySlot(self.PlayerData.source, slot)
end
```

Use these for online players. Pass false or nil for automatic item placement. A supplied slot is an existing item stack, not an empty grid cell.

In the same file, skip the qb-inventory LoadInventory/SaveInventory calls when using TSS. TSS loads and saves its own data. Replace scripts reading `PlayerData.items` directly with the item getter exports.

## Register an item directly

In your item-effect script's server file:

```lua
exports['tss-inventory']:CreateUsableItem('bandage', function(playerSource, item, inventoryId)
    if not exports['tss-inventory']:RemoveItem(inventoryId, item.id, 1) then return end
    -- Apply the effect here.
end)
```

Restart the registering script after restarting tss-inventory.

## Move scripts from qb-inventory

Change `exports['qb-inventory']` to `exports['tss-inventory']` for the supported calls listed in [exports.md](exports.md).

- AddItem and RemoveItem accept player server IDs.
- A slot identifies an item stack. Use MoveItem for grid coordinates.
- GetSlots counts used/free cells, including multi-cell items.
- Supply shop coordinates when using CreateShop.
- LoadInventory, SaveInventory, SetInventory, RemoveInventory, OpenInventoryById and QB hook/listener calls need separate changes; changing the resource name is not enough.

## Qbox

Set `tss_framework` to `qbox`. Replace ox_inventory calls in your scripts with the matching TSS exports in exports.md.

Before removing ox_inventory, check **qbx_core/server/player.lua** and Qbox's QB bridge files for remaining inventory and money calls. These instructions do not replace those core calls automatically.

## ESX

Set `tss_framework` to `esx`. Replace your scripts' xPlayer item checks, additions and removals with TSS HasItem, AddItem and RemoveItem calls using the player server ID. Register effects with CreateUsableItem.

To keep existing ESX scripts unchanged, edit the corresponding xPlayer item methods to call TSS. Leave `Config.CustomInventory` at its documented default unless your ESX integration requires another setting. Selecting the bridge does not redirect ESX's item methods or saved inventory.

## Check the setup

Restart in dependency order. Test adding, removing, checking and using an item, then reconnect to confirm it saved. Keep the old inventory tables until any item-data conversion is finished.
