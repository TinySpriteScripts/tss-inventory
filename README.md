# TSS Inventory

A free, open-source inventory for FiveM with multi-slot items, movable windows and a clean red-accented interface.

Arrange items your way, carry storage inside storage, trade with shops and customise your equipment. TSS Bridge connects the inventory to your server's framework and interaction system.

## Features

### Inventory and windows

- Items can occupy different amounts of space and rotate to fit.
- Move, stack and split items, with quick 25%, 50% and 75% split buttons.
- See an item preview and highlighted spaces before placing it.
- Move and minimise windows, or dock them in eight positions around the screen.
- Dock multiple inventories in one position and switch between them with tabs.
- Save window layouts per character and reset them from the settings menu.
- Repack an inventory to tidy its contents automatically.

### Storage and loot

- Player inventories, shared stashes and private stashes for each character.
- Backpacks, wallets and extra inventory windows, including optional weapon slots.
- Drag items onto a container's icon to store them without opening it.
- Optional item use directly from carried containers.
- Optional shared weight: putting an item in a backpack frees space without reducing the weight you carry.
- Vehicle trunks and gloveboxes, with storage sizes for vehicle classes and individual models.
- Fixed stashes opened through a target or by pressing TAB nearby, with optional markers.
- World drops that nearby players can open and collect.
- Random loot containers, including searchable items such as stolen wallets.
- Loot items can disappear automatically when their contents are emptied.

### Shops and giving

- Convenience stores, hardware shops, Ammunation and other configured locations.
- Shops can sell to players, buy from players, or do both.
- Separate buy and sell prices for each product.
- Drag purchases into your inventory, or choose an amount from the right-click menu.
- Eligible carried items show their sell price while a shop is open.
- Drag items into the shop to sell them, or right-click to choose an amount.
- Cash and bank payments and payouts.
- Give items to the closest player from the right-click menu, or drag them onto a nearby player's on-screen circle.

### Weapons, clothing and crafting

- Optional weapon equipping, holstering, reloading and durability.
- A compact equipped-weapon display with its image and loaded ammo count.
- A rotating 3D weapon view for installing and removing attachments.
- Drag attachments onto their highlighted fitting points, with finishes and tints supported too.
- Optional clothing items with equipment slots and male/female variations.
- Drag two matching ingredients together to craft, with configurable quantities, results and crafting times.
- Crafting previews and a progress outline, with ESC to cancel.

### Item details and personal settings

- Custom item and inventory names, rarity colours and condition bars.
- Extra information stored separately on individual items and inventories.
- Optional cash items that stay in sync with the player's cash balance.
- Custom item-use keys set through the right-click menu.
- Item notifications that start at bottom centre and can be positioned freely.
- Drag the weapon display and item notification previews in settings to customise their positions.
- Subtle inventory sounds, with personal volume and mute controls.

## Requirements and setup

You need **tss_bridge**, **oxmysql** and a working database connection. Configure the bridge for your framework and target system, then start the resources in this order:

```cfg
ensure oxmysql
ensure tss_bridge
ensure tss-inventory
```

Select the TSS Inventory adapter in the bridge when connecting other scripts to it. Players need to have selected and loaded a character before using their personal inventory.

The database tables are created automatically. Player inventories, regular storage and character settings are saved. **World drops and loot contents are temporary and disappear when the resource or server restarts.** Already-opened loot items cannot be reopened for a fresh roll after a restart.

Weapons and clothing can each be disabled in the configuration if another resource handles them on your server.

## Controls

| Control | Action |
| --- | --- |
| **TAB** or **/inv** | Open or close your inventory. Also opens a glovebox when seated, or an unlocked trunk when nearby at the rear. |
| **Drag an item** | Move it between spaces or inventories. |
| **R while dragging** | Rotate the item. |
| **Right-click** | Show the item's available actions. |
| **Double-click** | Use an item or open its container. |
| **Shift + left-click** | Quickly move a stack between your inventory and the last touched storage window. |
| **Ctrl + left-click** | Split half a stack and quickly move it to that window. |
| **Hold D while moving a window** | Show the docking positions. |
| **R while holding a weapon** | Reload outside the inventory. |
| **ESC during crafting** | Cancel crafting. |
| **/inventorysettings** | Customise displays, UI size, sounds, drop confirmation and remembered containers. |

Dropping an item onto open screen space creates a world drop. Dropping it onto a nearby player's circle gives it to that player instead.

Items with `throwable = true` have a **Take to hand** option in the right-click menu. While holding one, press **E** to use it normally, or hold **R** and release to throw one item towards your camera. A quick tap drops it near your feet. Around a one-second hold gives the original throw power; 1.8 seconds reaches the first peak, roughly twice the original range. Power then falls and rises repeatedly, so release near a peak for the longest throw. Tune these values in `Config.Throwing`: `fillTime` and `drainTime` control the power cycle, `idleTimeout` clears an idle hand, and `chargeTimeout` limits how long R can be held. All are milliseconds; set either timeout to `0` to disable it. After five seconds without either action, your hand clears and the item stays in your inventory. Thrown items become temporary world drops when they land. Weapons use their own GTA models; other items use `throwModel`, falling back to the world-drop prop. Normal **Use**, item keybinds and the `UseItem` export always use items immediately. Set `throwable = false` to hide **Take to hand**.

### Move your displays

Open `/inventorysettings` and choose **Move displays**. Drag the weapon display and item notification previews where you want them, choose **Done**, then **Save**. **Cancel** discards your changes. **Reset positions** restores their default placement. Positions are saved per character and adapt to your screen size.

You can toggle the weapon display and item notifications, set notification duration from 1–10 seconds, and choose Small, Medium or Large UI size. Small is the original size. Optional drop confirmation asks before dropping items into the world. Remember open carried containers reopens your last container windows when you open the inventory again, provided you still carry those containers. These settings are saved per character.

The equipped-weapon display shows loaded ammunition / capacity when the weapon uses ammo. Melee and rechargeable weapons show just their image. Holstering hides the display.

## Configuration

| File | What to change |
| --- | --- |
| [config.lua](config.lua) | General settings, optional systems, extra windows, sounds and appearance. |
| [data/items.lua](data/items.lua) | Item names, images, sizes, weights and default information. |
| [data/containers.lua](data/containers.lua) | Carried containers, fixed stashes and item-based loot. |
| [data/shops.lua](data/shops.lua) | Products, prices and shop locations. |
| [data/vehicles.lua](data/vehicles.lua) | Trunk and glovebox sizes. |
| [data/crafting.lua](data/crafting.lua) | Crafting recipes. |
| [data/weapons.lua](data/weapons.lua) | Weapons, ammunition and durability defaults. |
| [data/attachments.lua](data/attachments.lua) | Weapon attachments, finishes and tints. |
| [data/clothing.lua](data/clothing.lua) | Clothing items and equipment slots. |

## Administration

Admin commands follow your server's command permissions. Their descriptions and arguments appear in tss-chat for authorised admins.

| Command | Action |
| --- | --- |
| `/giveitem` or `/additem` | Give an item to a player. |
| `/removeitem` | Remove an item instance. |
| `/createinventory` | Create an inventory. |
| `/openinventory` | Open an inventory. |
| `/resizeinventory` | Change its grid size. |
| `/setinventorymetadata` | Replace an inventory's extra information. |
| `/setitemmetadata` | Replace an item's extra information. |
| `/inspectinventory` | Print inventory data. |

For a quick test, replace `1` with your player ID:

```text
/giveitem 1 backpack 1
/giveitem 1 radio 1
/giveitem 1 stolen_wallet 1
```

Admins can also remove items, open and resize inventories, and edit item or inventory information.

## Connecting other scripts

The inventory includes exports for adding and removing items, opening storage, creating shops and loot, registering usable items, and changing inventories. Common qb-inventory-style calls are supported to make switching easier.

- [Export guide](exports.md): available functions and copyable examples.
- [Migration guide](migration.md): changes to make when connecting existing framework scripts.
