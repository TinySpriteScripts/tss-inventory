# Qbox migration

These steps are for a Qbox server using TSS Inventory as its only inventory. Back up the Qbox files before editing them. Recheck these edits after updating Qbox.

Move the original `ox_inventory` and any experimental resource with that name outside the server's resources folder, including categories started with `ensure [ox]`.

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

## Migrate Qbox jobs and utilities

Apply these sections only to resources you run. Start each migrated resource after `tss-inventory` and add it as a dependency when the resource requires it. Replace the Ox dependency once its calls have been migrated. Check each resource's configured item names against TSS definitions. Existing Ox stash contents need a separate data migration.

In the examples below, `local inventory = exports['tss-inventory']` goes at the top of the relevant file. The [export guide](../exports.md) lists the arguments for each call.

### Taxi · INV-05

In `qbx_taxijob/server/main.lua`, remove the top-level `exports.ox_inventory:Items()` line. Replace the bonus item grant and its old item-box event with:

```lua
if player.Functions.AddItem(config.chanceItem, 1, false) then
    inventory:ItemBox(src, config.chanceItem, 'added', 1)
end
```

Keep the chance check and payment logic.

### Jewellery · INV-02

In `qbx_jewelery/server/main.lua`:

1. Remove the top-level `Items()` lookup. Use `inventory:GetItemDefinition(requiredItem)` when displaying the missing-item message. Use the item name as a fallback when no definition exists.
2. Replace the lockpick `Search` call with `inventory:GetItemCount(source, requiredItem)`. The migrated player removal method can stay.
3. Get the player's inventory with `inventory:GetPlayerInventory(source)`. Use its `id` with `inventory:CanCarryItem(playerInventory.id, itemName, amount)`, then grant the reward with `inventory:AddItem(source, itemName, amount)`. Check the add result as well as capacity before deciding whether to drop the reward.
4. Build overflow entries as `{ name = itemName, amount = quantity }`. Pass them to `inventory:CreateDrop({ label = 'Jewellery', coords = playerCoords, items = overflowItems, bucket = GetPlayerRoutingBucket(source) })`. Enable world drops and handle a failed drop creation.

### Mechanic · INV-03

1. In TSS `data/containers.lua`, add a fixed stash named `mechanicstash`. Use the original stash coordinates and weight in grams. The reported version uses `size = { x = 10, y = 50 }`, `maxWeight = 4000000`, `shared = true` and `groups = { mechanic = 0 }`.
2. Remove `RegisterStash` from `qbx_mechanicjob/server/main.lua`. Use `GetItemCount(source, itemName)` and `RemoveItem(source, itemName, amount)` for repair parts. Apply the repair after removal succeeds.
3. In `client/main.lua`, replace `Items()` with `GetItemDefinitions()` for the repair labels. Fall back to the configured item name if a definition is absent.
4. Replace the old stash open with `TriggerServerEvent('tss-inventory:openStash', 'mechanicstash')`. If retaining the job's interaction, set `target = false` and `openWhenNearby = false` on the TSS stash so there is one entry point.

### Ambulance · INV-01

1. Move the stash definitions from `qbx_ambulancejob/config/shared.lua` to TSS `data/containers.lua`. Keep their names, coordinates, weight and `groups = { ambulance = 0 }`. A 30-slot stash can use `size = { x = 6, y = 5 }`. Set `shared = false` for each personal stash.
2. Add each armory location to TSS `data/shops.lua` using a unique ID such as `AmbulanceArmory_1`. Copy the location, set `size = { x = 8 }` and `groups = { ambulance = 0 }`. Convert its inventory list to `stock` keyed by item name, with entries such as `bandage = { buyPrice = 0 }`.
3. Remove the old Ox stash and armory registration functions and their startup calls in `server/main.lua`. Port the server item checks and removals to `GetItemCount` and `RemoveItem`. In `server/hospital.lua`, use `inventory:ClearInventory(src)` at the existing hospital wipe point.
4. In `client/job.lua`, replace the item checks with `inventory:HasItem('firstaid')` and `inventory:HasItem('bandage')`. Keep the duty checks in the existing interaction functions. Request the stash with `TriggerServerEvent('tss-inventory:openStash', stashName)` and the matching armory location with `inventory:OpenShop(shopId)`.
5. Replace the manifest's Ox dependency. Test as an ambulance worker and as a civilian. Test that personal stashes are separate per character.

### Properties · INV-04

In `qbx_properties/server/property.lua`:

1. Remove the Ox `openInventory` hook and the Ox stash registration inside `EnterProperty`. Keep the interior and interaction setup.
2. In the existing `qbx_properties:server:openStash` event, derive the property from `enteredProperty[source]`. Guard against a missing player or property ID. Keep `hasAccess` and make it return false if its query finds no property. Use a stable stash ID such as `qbx_property_<propertyId>` for the shared owner/keyholder stash. If each configured stash is separate, include its validated index in that ID.
3. Create the stash on first use with `inventory:CreateInventory(stashId, { label = propertyLabel, slots = slots, maxweight = maxWeight })`. Use server-side property settings. Check the same character, entered property and access again after database calls before calling `inventory:OpenInventory(source, stashId)`.
4. Close that stash with `inventory:CloseInventory(source, stashId)` when the player leaves or loses access. Only grant opens from the checked server event. Test owner, keyholder and unauthorized access.

### Police · INV-07

1. Define each trash stash in TSS `data/containers.lua` as `policetrash_1`, `policetrash_2`, and so on. Copy the original coordinates and weight and include the eligible police jobs in `groups`. Define the locker with `shared = false` and the appropriate police groups.
2. Remove the old Ox stash registration handler in `server/main.lua`. Change the startup cleanup to `inventory:ClearStash(('stash_policetrash_%s'):format(index))` for trash only. Run it once TSS's database is ready. A stash that has never been opened may not exist yet, so skip that case. If TSS returns `Inventory database is not ready`, retry after initialization.
3. In `client/job.lua`, replace the trash and locker opens with `TriggerServerEvent('tss-inventory:openStash', stashName)` using the names without the `stash_` prefix.
4. For the other police features, port evidence item grants/removals and lookups separately. Get the equipped item server-side through `GetEquippedWeapon` and use its inventory and item IDs to read metadata. Check that the serial exists before using it. Keep nearby searches disabled until the server validates the officer, target, distance and permitted search state before granting access.

### Fuel · INV-06

For pump refuelling, migrate `ox_fuel` with petrol cans disabled first:

1. Set `config.petrolCan.enabled = false` in the fuel config. Replace its manifest's Ox dependency with TSS, and remove the Ox version check from `config.lua`. Keep the ox_lib check.
2. In `server.lua`, load `local banking = exports.tss_bridge:GetModules({ 'Banking' }).Banking`. Validate the pump interaction and vehicle, then calculate the fuel price on the server. Use one `banking.RemoveMoney(playerId, 'cash', price, 'ox_fuel')` call for payment and `banking.GetAccount(playerId, 'cash')` for the insufficient funds message.
3. In `client/utils.lua`, use the Qbox player's cash balance for the display check. In `client/state.lua`, remove the startup `getCurrentWeapon()` call and Ox weapon event listener. Return immediately from the server's `fuelCan` and `updateFuelCan` handlers while `config.petrolCan.enabled` is false.

To port petrol cans later, use `weapon_petrolcan`, `CanCarryItem`, `AddItem` and the server's `GetEquippedWeapon`. Read the exact item by its inventory and item IDs. Convert the fuel script's percentage to the TSS weapon's ammo capacity. Persist the metadata and synchronize the equipped ammo together before enabling the can. The current weapon state will otherwise retain its old ammo after a metadata edit.

## Version-check messages · BRG-01 and BRG-02

Update `tss_bridge` alongside TSS Inventory. The bridge skips resources missing from its default version catalogue. For a custom `version_check_repo`, use a published file containing the version and the exact resource name on separate lines. Custom endpoint failures still appear in the console.
