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

Follow **Qbox: replace Ox Inventory with TSS Inventory** at the bottom of this guide. Selecting the bridge alone does not replace Qbox's built-in Ox calls.

## ESX

Set `tss_framework` to `esx`. Replace your scripts' xPlayer item checks, additions and removals with TSS HasItem, AddItem and RemoveItem calls using the player server ID. Register effects with CreateUsableItem.

To keep existing ESX scripts unchanged, edit the corresponding xPlayer item methods to call TSS. Leave `Config.CustomInventory` at its documented default unless your ESX integration requires another setting. Selecting the bridge does not redirect ESX's item methods or saved inventory.

## Check the setup

Restart in dependency order. Test adding, removing, checking and using an item, then reconnect to confirm it saved. Keep the old inventory tables until any item-data conversion is finished.

## Qbox: replace Ox Inventory with TSS Inventory

These steps are for a Qbox server using TSS Inventory as its only inventory. Back up the Qbox files before editing them. Recheck these edits after updating Qbox.

Remove both the original ox_inventory and any experimental resource named ox_inventory from the start list. This setup does not need an Ox compatibility resource.

### 1. Set the start order

Put these settings before the resources start in `server.cfg`:

```cfg
setr tss_framework qbox
setr tss_inventory tss
set inventory:accounts "[]"

ensure oxmysql
ensure ox_lib
ensure qbx_core
ensure tss_bridge
ensure tss-inventory
```

Start scripts that register usable items after the inventory. TSS reads callbacks registered through `exports.qbx_core:CreateUseableItem` automatically. Their items must exist in TSS and have `useable = true`.

`inventory:accounts "[]"` stops Qbox from updating cash through Ox. Keep `Config.MoneyAsItem` enabled if you want TSS cash items. TSS handles their balance updates; do not add a second cash-sync script.

### 2. Allow TSS at Qbox startup

Open `qbx_core/server/main.lua`.

Find the Ox Inventory version check and change its condition to:

```lua
elseif GetConvar('tss_inventory', 'auto') ~= 'tss' and not lib.checkDependency('ox_inventory', '2.42.1', true) then
```

Keep the minimum Ox version from your existing file if it differs.

Find the `inventory:framework` check and change its condition to:

```lua
elseif GetConvar('tss_inventory', 'auto') ~= 'tss' and GetConvar('inventory:framework', '') ~= 'qbx' then
```

Leave the error messages, ox_lib check and OneSync check in place.

If your Qbox version also lists `ox_inventory` in the `dependencies` section of `fxmanifest.lua`, remove that entry. Keep its other dependencies.

### 3. Load TSS item definitions

Open `qbx_core/bridge/qb/server/main.lua` and remove these two lines:

```lua
local convertItems = require 'bridge.qb.shared.compat'.convertItems
convertItems(require '@ox_inventory.data.items', require 'shared.items')
```

Open `qbx_core/bridge/qb/shared/main.lua`.

Keep the first line, `local qbShared = require 'shared.main'`. Replace the item section after it, from `qbShared.Items = {}` through the Ox item, weapon, component and ammunition loops, with:

```lua
qbShared.Items = require '@tss-inventory.modules.compat.qbox.items'
```

Keep everything from `local starterItems = require 'config.shared'.starterItems` onwards.

The supplied TSS file reads definitions before the inventory starts. It does not load the database or change Qbox's global item tables itself. Add custom items to TSS's data files, then restart the server.

### 4. Replace Qbox player item methods

Open `qbx_core/server/player.lua`. Replace the following `self.Functions` methods inside `CreatePlayer`. Keep the other player methods.

```lua
function self.Functions.AddItem(itemName, amount, slot, metadata)
    assert(not self.Offline, 'unsupported for offline players')
    return exports['tss-inventory']:AddItem(self.PlayerData.source, itemName, amount or 1, slot, metadata)
end

function self.Functions.RemoveItem(itemName, amount, slot)
    assert(not self.Offline, 'unsupported for offline players')
    return exports['tss-inventory']:RemoveItem(self.PlayerData.source, itemName, amount or 1, slot)
end

function self.Functions.GetItemBySlot(slot)
    assert(not self.Offline, 'unsupported for offline players')
    return exports['tss-inventory']:GetItemBySlot(self.PlayerData.source, slot)
end

function self.Functions.GetItemByName(itemName)
    assert(not self.Offline, 'unsupported for offline players')
    return exports['tss-inventory']:GetItemByName(self.PlayerData.source, itemName)
end

function self.Functions.GetItemsByName(itemName)
    assert(not self.Offline, 'unsupported for offline players')
    return exports['tss-inventory']:GetItemsByName(self.PlayerData.source, itemName)
end

function self.Functions.ClearInventory()
    assert(not self.Offline, 'unsupported for offline players')
    return exports['tss-inventory']:ClearInventory(self.PlayerData.source)
end
```

Do not wrap the returned items in `qbItemCompat` or convert `cash` to `money`. TSS already provides `slot`, `info` and `amount`. Its cash item is named `cash`.

### 5. Replace item checks and item use

In `qbx_core/bridge/qb/server/functions.lua`, replace `functions.HasItem` and `functions.UseItem`:

```lua
function functions.HasItem(playerSource, items, amount)
    return exports['tss-inventory']:HasItem(playerSource, items, amount)
end

function functions.UseItem(playerSource, item)
    return exports['tss-inventory']:UseItem(playerSource, item)
end
```

In `qbx_core/bridge/qb/client/functions.lua`, replace `functions.HasItem`:

```lua
function functions.HasItem(items, amount)
    return exports['tss-inventory']:HasItem(items, amount)
end
```

In `qbx_core/modules/utils.lua`, replace both `HasItem` functions. Use this in the server section:

```lua
function HasItem(playerSource, items, amount)
    return exports['tss-inventory']:HasItem(playerSource, items, amount)
end
```

Use this in the client section:

```lua
function HasItem(items, amount)
    return exports['tss-inventory']:HasItem(items, amount)
end
```

### 6. Give starter items through TSS

Open `qbx_core/server/character.lua`. Replace `giveStarterItems` with:

```lua
local function giveStarterItems(playerSource)
    local deadline = GetGameTimer() + 30000

    while GetPlayerName(playerSource) and GetGameTimer() < deadline do
        if GetResourceState('tss-inventory') == 'started' then
            local playerInventory = exports['tss-inventory']:GetPlayerInventory(playerSource)
            if playerInventory then
                for _, item in ipairs(starterItems) do
                    local metadata = type(item.metadata) == 'function' and item.metadata(playerSource) or item.metadata
                    local added, itemError = exports['tss-inventory']:AddItem(playerSource, item.name, item.amount or 1, false, metadata)
                    if not added then
                        lib.print.error(('Starter item %s could not be added: %s'):format(item.name, tostring(itemError)))
                    end
                end
                return
            end
        end
        Wait(100)
    end

    lib.print.error('Starter items could not be given because TSS Inventory was not ready.')
end
```

Make sure every starter item is defined in TSS. Use `cash` rather than `money` for its cash item. Existing Qbox starter metadata functions can be kept.

### 7. Test the server

Restart the whole server after these changes. Test:

- Creating a new character and receiving starter items.
- Reconnecting with existing items.
- Adding, removing, checking and using an item registered through Qbox.
- Cash changes, cash purchases and bank purchases.
- Opening inventory after restarting TSS Inventory and TSS Bridge.

Qbox's old `PlayerData.items` field is not the inventory's saved data. Scripts reading it directly should use TSS's getter exports instead.

Other scripts calling Ox Inventory directly still need their supported calls changed to TSS. These instructions do not add Ox hooks, restricted stash registration or every Ox export. See the export guide for the available calls.

### Scope of these Qbox changes

These steps change Qbox core and its built-in QB bridge only. Keep your other resources unchanged. Jobs and utilities that call Ox Inventory directly can be migrated separately later; the core setup does not convert them automatically.
