# Basic framework migration

This is a manual edit guide. It does not install a framework layer or import old inventories. Only the APIs that currently exist are used below; see exports.md for the complete list.

## Startup

Start oxmysql, your framework, tss_bridge, then tss-inventory. Start scripts that register usable items after tss-inventory. Disable the inventory you are replacing for that test run.

```cfg
setr tss_framework qb
setr tss_inventory tss

ensure oxmysql
ensure qb-core
ensure tss_bridge
ensure tss-inventory
```

For Qbox use framework `qbox` and resource `qbx_core`. For ESX use framework `esx` and resource `es_extended`.

Define every usable item in tss-inventory/data/items.lua, including its grid size. Keep matching framework item definitions if other scripts read them. TSS does not automatically copy qb-core/shared/items.lua or existing database items.

## QBCore: HasItem

Files to edit:

- Client: qb-core/client/functions.lua, `QBCore.Functions.HasItem`.
- Server: qb-core/server/functions.lua, `QBCore.Functions.HasItem`.

Paste this small helper above HasItem in both files. It supports a name, a list of names, or a map of names to required amounts.

```lua
local function hasRequiredItems(requirements, amount, getCount)
    local requested = {}
    if type(requirements) == 'string' then
        requested[requirements] = amount or 1
    elseif type(requirements) == 'table' then
        for itemKey, value in pairs(requirements) do
            local itemName = type(itemKey) == 'number' and value or itemKey
            local required = type(itemKey) == 'number' and (amount or 1) or value
            if type(itemName) ~= 'string' then return false end
            requested[itemName] = required
        end
    else
        return false
    end
    if not next(requested) then return false end
    for itemName, required in pairs(requested) do
        if type(required) ~= 'number' or required < 1 or required % 1 ~= 0
            or getCount(itemName) < required then return false end
    end
    return true
end
```

Replace the **client** function with:

```lua
function QBCore.Functions.HasItem(items, amount)
    if GetResourceState('tss-inventory') ~= 'started' then return false end
    local inventory = exports['tss-inventory']:GetLocalInventory()
    if type(inventory) ~= 'table' then return false end
    return hasRequiredItems(items, amount, function(itemName)
        local count = 0
        for _, item in ipairs(inventory.items) do
            if item.name == itemName then count = count + item.amount end
        end
        return count
    end)
end
```

Replace the **server** function with:

```lua
function QBCore.Functions.HasItem(playerSource, items, amount)
    if GetResourceState('tss-inventory') ~= 'started' then return false end
    local inventory = exports['tss-inventory']:GetPlayerInventory(playerSource)
    if type(inventory) ~= 'table' then return false end
    return hasRequiredItems(items, amount, function(itemName)
        return exports['tss-inventory']:GetItemCount(inventory.id, itemName)
    end)
end
```

These check the personal grid. Extra slots and backpack contents are separate inventories; these simple replacements do not flatten them into QBCore slots. Client checks are informational; use the server check before granting an effect or reward.

## QBCore: usable items

For each script registering an item, edit its **server.lua**. Replace its QBCore CreateUseableItem registration with the TSS export and keep the existing effect logic inside the callback:

```lua
exports['tss-inventory']:RegisterUsableItem('bandage', function(playerSource, item, inventoryId)
    -- item is read from the real inventory, not supplied by a client.
    local removed = exports['tss-inventory']:RemoveItem(inventoryId, item.id, 1)
    if not removed then return end

    -- Your existing effect event goes here.
    -- TriggerClientEvent('your-resource:applyBandage', playerSource)
end)
```

The callback receives `item.id` and `item.metadata`. For an existing callback expecting QBCore's fields, set `item.slot = item.id` and `item.info = item.metadata` before calling it. Pass inventoryId through to consumption logic when the item can come from an extra slot or carried container.

Do not consume the item twice: if the existing callback already removes it, replace that removal rather than adding another one. Restart the registering scripts after restarting tss-inventory so their callbacks register again.

Your current `qb-core/server/functions.lua` also has `QBCore.Functions.UseItem` forwarding to qb-inventory. There is currently **no TSS UseItem export** to substitute there. Item use from the TSS UI and private item keys already dispatches RegisterUsableItem callbacks. Port scripts that call the old UseItem function to this registration/callback approach; do not reactivate the deprecated client-callable QBCore AddItem/RemoveItem events.

## QBCore: add/remove calls and saving

For a script using Player.Functions.AddItem/RemoveItem, replace those calls in that script's server file with:

```lua
local inventory = exports['tss-inventory']:GetPlayerInventory(playerSource)
if type(inventory) ~= 'table' then return end

local added = exports['tss-inventory']:AddItem(inventory.id, 'water_bottle', 1, {})
local removed = exports['tss-inventory']:RemoveItemsByName(inventory.id, 'water_bottle', 1)
```

If these calls must remain unchanged across many scripts, their wrappers belong inside `QBCore.Player.CreatePlayer` in qb-core/server/player.lua. Map AddItem to the AddItem export and RemoveItem to RemoveItemsByName, resolving that player's TSS inventory ID first. TSS item IDs identify instances, not numbered QBCore grid cells.

In the same file, remove/skip qb-inventory LoadInventory/SaveInventory calls when running TSS. TSS loads and saves its own tables through modules/inventory/database.lua. Do not copy an empty PlayerData.items cache into TSS or call qb-inventory simply because its folder exists. A full PlayerData.items mirror is not included in these small replacements.

## Qbox

Use the Qbox bridge setting above. For scripts you control, replace direct ox_inventory item operations with the same TSS exports shown above. Usable callbacks should register through TSS or tss_bridge.Inventory.CreateUsableItem.

Stock Qbox code also makes ox_inventory-specific calls, including inventory-backed money accounts. Review qbx_core/server/player.lua and its QB compatibility files before removing ox_inventory. Selecting the bridge adapter alone does not replace those calls. This guide does not claim drop-in Qbox core compatibility or change your Qbox files.

## ESX

Use the ESX bridge setting above. Replace script calls such as xPlayer.getInventoryItem/addInventoryItem/removeInventoryItem with GetItemCount/AddItem/RemoveItemsByName after resolving the player's TSS inventory. Register usable callbacks through TSS as shown above.

Native ESX inventory methods, its inventory cache and persistence need explicit forwarding if you want old scripts to remain unchanged. Do not assume setting Config.CustomInventory to a made-up value enables TSS: current ESX instructions leave it false for other inventories unless their integration specifies otherwise. This guide does not change ESX files or install a custom inventory override.

## Check after your edits

Restart in dependency order, then test HasItem for single names, lists and amount maps; use and consume one registered item; reconnect to confirm persistence. Keep the old inventory's database until you have a separate, verified data-conversion plan. TSS does not automatically import qb/ox/ESX records.

Framework references: [Qbox player implementation](https://github.com/Qbox-project/qbx_core/blob/main/server/player.lua), [ESX inventory configuration](https://github.com/esx-framework/esx_core/blob/main/%5Bcore%5D/es_extended/shared/config/main.lua).
