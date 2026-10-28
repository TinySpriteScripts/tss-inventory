# TSS Inventory server exports

All exports are server-only, framework independent. Mutations return `true` or `false, reason`. Getters return defensive copies. Inventory IDs are strings; item instance IDs, amounts and 1-based coordinates are integers.

```lua
local inv = exports['tss-inventory']
local playerInventory = inv:GetPlayerInventory(source)
local ok, reason = inv:AddItem(playerInventory.id, 'radio', 1, {durability=100})
```

| Export | Arguments / result |
| --- | --- |
| `GetPlayerInventory` | `(playerServerId)` → inventory copy or nil; creates by license |
| `GetInventory` | `(inventoryId)` → inventory copy or nil |
| `DropItem` | `(playerServerId, itemInstanceId, quantity, optionalRotatedBoolean)` → remove from own inventory into a temporary pooled world drop; disabled world-drop config deletes instead |
| `GetItemDefinition` | `(name)` → merged item defaults/definition copy or nil |
| `GetItemCount` | `(id, name, optionalExactMetadata)` → number |
| `CanCarryItem` | `(id, name, amount, optionalMetadata)` → bool/reason, no mutation |
| `CreateInventory` | `(id, typeName, optionalOverrides)` → true, inventory copy OR false, reason |
| `OpenInventory` | `(playerServerId, inventoryId)` → grants access, opens alongside own inventory |
| `CloseInventory` | `(playerServerId, optionalInventoryId)` → revoke one grant, or all and close UI |
| `AddItem` | `(id, name, amount, optionalMetadata)` → fill matching stacks then new footprints |
| `RemoveItem` | `(id, itemInstanceId, amount)` → remove exact quantity/instance |
| `MoveItem` | `(fromId, toId, itemInstanceId, amount, x, y, optionalRotatedBoolean)` → safe move, split or merge |
| `ResizeInventory` | `(id, {x=columns,y=rows}, optionalRepackBoolean)` → safe resize |
| `SetInventoryLabel` | `(id, label)` → persisted label (100 bytes max) |
| `SetInventoryMetadata` | `(id, object)` → replace complete inventory metadata |
| `SetItemMetadata` | `(id, itemInstanceId, object)` → replace complete item metadata |
| `SetInventoryRules` | `(id, {whitelist={},blacklist={},maxWeight=grams})` → change supplied fields, refuse if contents violate new rules |
| `RegisterInventoryType` | `(name, definition)` → register/replace creation template; requires valid size |
| `GetInventoryType` | `(name)` → template copy or nil |
| `RegisterUsableItem` | `(name, function(playerServerId,itemCopy,inventoryId))` → trusted server use callback |

```lua
local inv = exports['tss-inventory']
inv:RegisterInventoryType('business', {
    label='Business Storage', size={x=10,y=8}, metadata={tier=1}, maxWeight=100000
})
inv:CreateInventory('business:mechanic', 'business', {
    label='Mechanic Supplies', metadata={businessId='mechanic',tier=2}
})
-- Caller must verify permission before granting access.
inv:OpenInventory(source, 'business:mechanic')
local ok, reason = inv:ResizeInventory('business:mechanic', {x=12,y=8}, true)
local current = inv:GetInventory('business:mechanic')
current.metadata.tier = 3
inv:SetInventoryMetadata(current.id, current.metadata)
-- Revoke when access conditions expire:
inv:CloseInventory(source, current.id)
```

Type registration affects future creations and must be repeated after resource restart. Existing inventory instances persist their configuration. Optional third `applyExisting=true` is refused: resize each existing ID explicitly. maxWeight is grams; 0 permits only zero-weight items. Item footprints/weight are definition-wide; inventory resize edits capacity.

Use callbacks receive validated copies. Implement all effects server-side and explicitly remove/modify items when needed. None are registered by default. Callbacks belonging to stopped resources are removed. Internal network events are not the integration API.

MoveItem rotation: omit the final argument to preserve current orientation; true swaps the definition width/height, false uses original orientation. Orientation is stored as item.rotated independently from metadata. Merging keeps the destination stack orientation. Existing saved items without rotated default to false.
