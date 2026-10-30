import { useLayoutEffect, useRef, useState, useSyncExternalStore } from "react";
import { createPortal } from "react-dom";
import { DOCK_SLOT_IDS, getDockSlots } from "./docking.js";
import {
  inventoryState,
  subscribeToInventory,
  getStoreVersion,
  findInventory,
  getInventoryLayout,
  getItemFootprint,
  getPaymentMethod,
  selectPaymentMethod,
  getDockBounds,
  getDraggedItem,
  scheduleItemTooltip,
  hideItemTooltip,
  openItemContextMenu,
  showItemDetails,
  openQuantityDialog,
  updateDialogQuantity,
  confirmQuantityDialog,
  closeQuantityDialog,
  startDialogDrag,
  pressInventoryItem,
  touchInventory,
  getItemBinding,
  captureItemKey,
  unbindItemKey,
  requestItemAction,
  startWindowDrag,
  focusInventory,
  undockInventory,
  selectInventoryTab,
  toggleMinimised,
  closeInventoryWindow,
  resetInventoryLayout,
  repackInventory,
  setSoundPreference,
  setInventoryPreference,
  getInterfaceScale,
  previewInventorySound,
  getHudPositionStyle,
  startHudDrag,
  resetHudPositions,
  setHudPositioning,
  closeInventorySettings,
  saveInventorySettings,
  openWeaponAttachments,
  closeWeaponAttachments,
  removeWeaponAttachment,
  startWeaponRotation,
  openInstalledAttachmentMenu,
  toggleClothingPanel,
  unequipClothing,
  canGiveFromInventory,
  giveItemToClosest,
  getSellOffer,
  sellItem,
  openSaleDialog,
} from "./inventoryStore.js";

function ItemImage({
  item,
  isRotated = item.rotated === true,
  isGhost = false,
}) {
  const [hasImageError, setHasImageError] = useState(false);
  const imageName = item.definition.image;
  const imageIsAvailable =
    imageName && /^[\w.-]+\.(png|svg)$/i.test(imageName) && !hasImageError;

  if (!imageIsAvailable)
    return (
      <span className="fallback">{item.definition.label || item.name}</span>
    );

  const imageStyle =
    isRotated || isGhost
      ? {
          position: "absolute",
          left: "50%",
          top: "50%",
          width: item.definition.size.x * inventoryState.cellSize * 0.82,
          height: item.definition.size.y * inventoryState.cellSize * 0.8,
          transform: `translate(-50%, -50%) rotate(${isRotated ? 90 : 0}deg)`,
        }
      : undefined;

  return (
    <img
      src={`images/${imageName}`}
      alt=""
      draggable={false}
      style={imageStyle}
      onError={() => setHasImageError(true)}
    />
  );
}

function getItemRarityColor(item) {
  const raritySettings = inventoryState.rarity;
  const rarity = item.metadata?.rarity;
  const color = typeof rarity === "string" && raritySettings.tiers?.[rarity];
  return raritySettings.enable && typeof color === "string" && /^#[0-9a-f]{6}$/i.test(color)
    ? color
    : null;
}

function RarityFrame({ item }) {
  const rarity = item.metadata?.rarity;
  const color = getItemRarityColor(item);
  if (!color) return null;

  const red = parseInt(color.slice(1, 3), 16);
  const green = parseInt(color.slice(3, 5), 16);
  const blue = parseInt(color.slice(5, 7), 16);
  return (
    <div className="rarity-frame" data-rarity={rarity} style={{
      "--rarity-color": color,
      "--rarity-tint": `rgba(${red}, ${green}, ${blue}, 0.09)`,
    }} aria-hidden="true">
      <svg viewBox="0 0 100 100" preserveAspectRatio="none">
        <path d="M0 9V0H9 M91 0H100V9 M100 91V100H91 M9 100H0V91"
          vectorEffect="non-scaling-stroke" />
      </svg>
    </div>
  );
}

function InventoryItem({ inventory, item }) {
  const size = getItemFootprint(item);
  const activeDrag = inventoryState.drag;
  const isDragSource =
    activeDrag?.inventoryId === inventory.id && activeDrag.itemId === item.id;
  const isShop = inventory.type === "shop";
  const sellOffer = !isShop && getSellOffer(inventory, item);
  const itemClasses = [
    "item",
    isDragSource && "drag-source",
    isShop && item.canBuy !== false && item.stock === 0 && "sold-out",
  ]
    .filter(Boolean)
    .join(" ");

  return (
    <div
      className={itemClasses}
      data-inventory={inventory.id}
      data-item={item.id}
      draggable={false}
      tabIndex={0}
      aria-label={`${item.definition.label}, ${item.amount}`}
      style={{
        left: (item.x - 1) * inventoryState.cellSize,
        top: (item.y - 1) * inventoryState.cellSize,
        width: size.x * inventoryState.cellSize,
        height: size.y * inventoryState.cellSize,
      }}
      onPointerDown={(pointerEvent) =>
        pressInventoryItem(inventory, item, pointerEvent)
      }
      onContextMenu={(pointerEvent) =>
        openItemContextMenu(inventory, item, pointerEvent)
      }
      onMouseEnter={(pointerEvent) => scheduleItemTooltip(item, pointerEvent)}
      onMouseLeave={hideItemTooltip}
      onDoubleClick={(pointerEvent) => {
        if (pointerEvent.ctrlKey || pointerEvent.shiftKey) return;
        return isShop
          ? openQuantityDialog(inventory, item, true)
          : requestItemAction(inventory, item, "use");
      }}
    >
      <ItemImage item={item} />
      <RarityFrame item={item} />
      <span className="amount">
        {isShop ? (item.stock === false ? "∞" : item.stock) : item.amount}
      </span>
      {isShop && item.canBuy !== false && <span className="price">${item.buyPrice ?? item.price}</span>}
      {isShop && item.canBuy === false && item.canSell && <span className="price shop-sell-price">+${item.sellPrice}</span>}
      {sellOffer && <span className="price sell-price">+${sellOffer.product.sellPrice}</span>}
    </div>
  );
}

function PlacementCells({ inventory }) {
  const destination = inventoryState.destination;
  if (!destination || destination.attachmentSlot || destination.inventoryId !== inventory.id) return null;
  const highlight = destination.highlight;
  const cells = [];

  for (let row = highlight.y; row < highlight.y + highlight.height; row += 1) {
    for (
      let column = highlight.x;
      column < highlight.x + highlight.width;
      column += 1
    ) {
      if (
        column < 1 ||
        row < 1 ||
        column > inventory.size.x ||
        row > inventory.size.y
      )
        continue;
      cells.push(
        <div
          key={`${column}:${row}`}
          className="placement-cell"
          style={{
            left: (column - 1) * inventoryState.cellSize,
            top: (row - 1) * inventoryState.cellSize,
            width: inventoryState.cellSize,
            height: inventoryState.cellSize,
          }}
        />,
      );
    }
  }

  return (
    <div className={`placement${destination.isValid ? "" : " invalid"}${destination.craft ? " crafting-preview" : ""}`}>
      {cells}
    </div>
  );
}

function CraftingItem({ craft }) {
  const width = craft.item.definition.size.x * inventoryState.cellSize;
  const height = craft.item.definition.size.y * inventoryState.cellSize;
  return <div className="crafting-item" style={{ left: (craft.item.x - 1) * inventoryState.cellSize,
    top: (craft.item.y - 1) * inventoryState.cellSize, width, height }}>
    <ItemImage item={craft.item} />
    <svg className="crafting-progress" width={width} height={height} viewBox={`0 0 ${width} ${height}`}>
      <rect className="crafting-track" x="1.5" y="1.5" width={width - 3} height={height - 3} />
      <rect className="crafting-fill" x="1.5" y="1.5" width={width - 3} height={height - 3}
        pathLength="100" style={{ animationDuration: `${craft.duration}ms` }} />
    </svg>
  </div>;
}

function InventoryGrid({ inventory }) {
  const craft = inventoryState.crafting?.inventoryId === inventory.id ? inventoryState.crafting : null;
  return (
    <div className="body">
      <div
        className="grid"
        data-inventory={inventory.id}
        style={{
          width: inventory.size.x * inventoryState.cellSize,
          height: inventory.size.y * inventoryState.cellSize,
        }}
      >
        {inventory.items.map((item) => {
          const remainingAmount = craft?.ingredients?.[String(item.id)] ?? item.amount;
          return remainingAmount > 0 && <InventoryItem key={item.id} inventory={inventory}
            item={remainingAmount === item.amount ? item : { ...item, amount: remainingAmount }} />;
        })}
        {craft && <CraftingItem craft={craft} />}
        <PlacementCells inventory={inventory} />
      </div>
    </div>
  );
}

function InventoryStatus({ inventory }) {
  if (inventory.type === "shop") {
    return (
      <div className="status">
        <div
          className="payment-methods"
          role="group"
          aria-label="Payment method"
        >
          {["cash", "bank"].map((paymentMethod) => (
            <button
              key={paymentMethod}
              className="payment-button"
              aria-pressed={getPaymentMethod(inventory) === paymentMethod}
              onClick={() => selectPaymentMethod(inventory, paymentMethod)}
            >
              {paymentMethod === "cash" ? "Cash" : "Bank"}
            </button>
          ))}
        </div>
      </div>
    );
  }

  const hasWeightLimit =
    Number.isFinite(inventory.maxWeight) && inventory.maxWeight > 0;
  const occupiedCells = inventory.items.reduce(
    (total, item) => total + item.definition.size.x * item.definition.size.y,
    0,
  );
  const capacityRatio = hasWeightLimit
    ? (inventory.weight || 0) / inventory.maxWeight
    : occupiedCells / (inventory.size.x * inventory.size.y);
  const capacityPercent = Math.max(0, Math.min(1, capacityRatio)) * 100;
  const weightLabel = `${((inventory.weight || 0) / 1000).toFixed(2)} kg${hasWeightLimit ? ` / ${(inventory.maxWeight / 1000).toFixed(2)} kg` : ""}`;

  return (
    <div className="status">
      <span>{weightLabel}</span>
      <div
        className="capacity-bar"
        role="progressbar"
        aria-label={hasWeightLimit ? "Weight capacity" : "Grid space used"}
        aria-valuemin={0}
        aria-valuemax={100}
        aria-valuenow={Math.round(capacityPercent)}
        title={`${Math.round(capacityPercent)}% ${hasWeightLimit ? "weight capacity" : "grid space"} used`}
      >
        <div
          className="capacity-fill"
          style={{ width: `${capacityPercent}%` }}
        />
      </div>
    </div>
  );
}

function WindowButton({ children, label, onClick, className }) {
  return (
    <button
      className={className}
      title={label}
      aria-label={label}
      onPointerDown={(pointerEvent) => pointerEvent.stopPropagation()}
      onClick={onClick}
    >
      {children}
    </button>
  );
}

function WindowControls({ inventory, isDocked }) {
  return (
    <div className="controls">
      {inventory.isOwn === true && inventoryState.clothingEnabled && (
        <WindowButton label="Clothing" onClick={toggleClothingPanel}>
          <svg width="14" height="14" viewBox="0 0 20 20" fill="none" stroke="currentColor" aria-hidden="true">
            <path d="M6 3 2 6l2 4 2-1v8h8V9l2 1 2-4-4-3c-1 3-7 3-8 0Z" />
          </svg>
        </WindowButton>
      )}
      {inventory.type !== "shop" && <WindowButton label="Repack inventory" onClick={() => repackInventory(inventory)}>
        <svg width="13" height="13" viewBox="0 0 16 16" aria-hidden="true" fill="none" stroke="currentColor">
          <path d="M2 2h12" /><rect x="2" y="4" width="5" height="4" /><rect x="9" y="4" width="5" height="4" /><rect x="2" y="10" width="12" height="4" />
        </svg>
      </WindowButton>}
      <WindowButton
        label={isDocked ? "Undock active tab" : "Bring to front"}
        onClick={() =>
          isDocked ? undockInventory(inventory) : focusInventory(inventory)
        }
      >
        ▣
      </WindowButton>
      <WindowButton
        label={getInventoryLayout(inventory).minimised ? "Restore" : "Minimise"}
        onClick={() => toggleMinimised(inventory)}
      >
        {getInventoryLayout(inventory).minimised ? "+" : "−"}
      </WindowButton>
      <WindowButton
        label="Close inventory"
        onClick={() => closeInventoryWindow(inventory)}
      >
        ×
      </WindowButton>
    </div>
  );
}

function InventoryWindow({
  inventory,
  dockSlotId = null,
  groupedInventories = [],
}) {
  const layout = getInventoryLayout(inventory);
  const isDocked = dockSlotId !== null;
  const dockBounds = isDocked ? getDockBounds(dockSlotId) : null;
  const windowStyle = isDocked
    ? {
        left: dockBounds.x,
        top: dockBounds.y,
        width: dockBounds.width,
        height: layout.minimised ? undefined : dockBounds.height,
      }
    : {
        left: Math.max(0, Math.min(innerWidth - 180, layout.x)),
        top: Math.max(0, Math.min(innerHeight - 40, layout.y)),
        width: Math.min(
          inventory.size.x * inventoryState.cellSize + 16,
          innerWidth - 24,
        ),
        maxHeight: Math.max(80, innerHeight - Math.max(0, layout.y) - 35),
        zIndex: layout.frontOrder || 10,
      };

  return (
    <section
      className={`window${isDocked ? " docked" : ""}${layout.minimised ? " minimised" : ""}`}
      onPointerDownCapture={() => touchInventory(inventory)}
      data-dock={dockSlotId || undefined}
      data-inventory={isDocked ? undefined : inventory.id}
      style={windowStyle}
    >
      <div
        className="header"
        onPointerDown={
          isDocked
            ? undefined
            : (pointerEvent) => startWindowDrag(inventory, pointerEvent)
        }
      >
        {isDocked ? (
          <div className="tabs" role="tablist">
            {groupedInventories.map((groupedInventory) => (
              <button
                key={groupedInventory.id}
                role="tab"
                aria-selected={inventory.id === groupedInventory.id}
                className={`tab${inventory.id === groupedInventory.id ? " active" : ""}`}
                onClick={() =>
                  selectInventoryTab(dockSlotId, groupedInventory.id)
                }
                onPointerDown={(pointerEvent) =>
                  startWindowDrag(groupedInventory, pointerEvent)
                }
              >
                {groupedInventory.label}
              </button>
            ))}
          </div>
        ) : (
          <span className="title">{inventory.label}</span>
        )}
        <WindowControls inventory={inventory} isDocked={isDocked} />
      </div>
      <InventoryGrid inventory={inventory} />
      <InventoryStatus inventory={inventory} />
    </section>
  );
}

function ClothingWindow() {
  const [position, setPosition] = useState({ x: Math.max(12, innerWidth - 370), y: 90 });
  const [minimised, setMinimised] = useState(false);
  const dragOffset = useRef(null);
  const panel = inventoryState.clothing;
  if (!inventoryState.clothingEnabled || !inventoryState.clothingOpen) return null;
  const equipment = panel?.inventory;

  function startPanelDrag(pointerEvent) {
    if (pointerEvent.button !== 0) return;
    dragOffset.current = { x: pointerEvent.clientX - position.x, y: pointerEvent.clientY - position.y };
    pointerEvent.currentTarget.setPointerCapture(pointerEvent.pointerId);
  }

  function movePanel(pointerEvent) {
    if (!dragOffset.current) return;
    setPosition({ x: Math.max(0, Math.min(innerWidth - 180, pointerEvent.clientX - dragOffset.current.x)),
      y: Math.max(0, Math.min(innerHeight - 34, pointerEvent.clientY - dragOffset.current.y)) });
  }

  return (
    <section className={`window clothing-window${minimised ? " minimised" : ""}`}
      aria-label="Clothing equipment" style={{ left: position.x, top: position.y, zIndex: 100 }}>
      <header className="header" onPointerDown={startPanelDrag} onPointerMove={movePanel}
        onPointerUp={() => { dragOffset.current = null; }} onLostPointerCapture={() => { dragOffset.current = null; }}>
        <span className="title">Clothing</span>
        <div className="controls">
          <WindowButton label={minimised ? "Restore clothing" : "Minimise clothing"} onClick={() => setMinimised(!minimised)}>{minimised ? "+" : "−"}</WindowButton>
          <WindowButton label="Close clothing" onClick={toggleClothingPanel}>×</WindowButton>
        </div>
      </header>
      {!minimised && <div className="clothing-slots">
        {(panel?.slots || []).map((slot) => {
          const item = equipment?.items.find((candidate) => candidate.x === slot.x && candidate.y === slot.y);
          const destination = inventoryState.destination;
          const isTarget = destination?.clothingSlot === slot.id;
          const isDragging = item && inventoryState.drag?.inventoryId === equipment.id && inventoryState.drag?.itemId === item.id;
          return <div key={slot.id} className={`clothing-slot${isTarget ? destination.isValid ? " valid" : " invalid" : ""}${isDragging ? " drag-source" : ""}`}
            data-clothing-slot={slot.id} aria-label={slot.label}
            onPointerDown={item ? (pointerEvent) => pressInventoryItem(equipment, item, pointerEvent) : undefined}
            onContextMenu={item ? (pointerEvent) => openItemContextMenu(equipment, item, pointerEvent) : undefined}
            onDoubleClick={item ? () => unequipClothing(slot.id) : undefined}
            onMouseEnter={item ? (pointerEvent) => scheduleItemTooltip(item, pointerEvent) : undefined}
            onMouseLeave={hideItemTooltip}>
            {item && <><ItemImage item={item} /><RarityFrame item={item} /></>}
            <span className="clothing-slot-label">{slot.label}</span>
          </div>;
        })}
        {!equipment && <span className="clothing-loading">Loading…</span>}
      </div>}
    </section>
  );
}

function InventoryWorkspace() {
  const windows = [];

  for (const dockSlotId of DOCK_SLOT_IDS) {
    const groupedInventories = inventoryState.inventories.filter(
      (inventory) => getInventoryLayout(inventory).dock === dockSlotId,
    );
    if (!groupedInventories.length) continue;
    const activeInventory =
      groupedInventories.find(
        (inventory) => inventory.id === inventoryState.activeTabs[dockSlotId],
      ) || groupedInventories[0];
    windows.push(
      <InventoryWindow
        key={`dock:${dockSlotId}`}
        inventory={activeInventory}
        dockSlotId={dockSlotId}
        groupedInventories={groupedInventories}
      />,
    );
  }

  for (const inventory of inventoryState.inventories) {
    if (!getInventoryLayout(inventory).dock)
      windows.push(
        <InventoryWindow key={inventory.id} inventory={inventory} />,
      );
  }

  return <div id="workspace">{windows}</div>;
}

function ClampedPopup({ popupId, position, children, style }) {
  const popupReference = useRef(null);
  const [popupPosition, setPopupPosition] = useState(position);

  useLayoutEffect(() => {
    const popupBounds = popupReference.current.getBoundingClientRect();
    setPopupPosition({
      x: Math.max(4, Math.min(position.x, innerWidth - popupBounds.width - 6)),
      y: Math.max(
        4,
        Math.min(position.y, innerHeight - popupBounds.height - 6),
      ),
    });
  }, [position.x, position.y]);

  return (
    <div
      id={popupId}
      ref={popupReference}
      style={{ left: popupPosition.x, top: popupPosition.y, ...style }}
    >
      {children}
    </div>
  );
}

function DetailRow({ label, value, valueColor }) {
  return (
    <div className="detail">
      <span>{label}</span>
      <span style={valueColor ? { color: valueColor } : undefined}>{String(value)}</span>
    </div>
  );
}

function ItemTooltip() {
  const tooltip = inventoryState.tooltip;
  if (!tooltip) return <div id="tooltip" hidden />;
  const item = tooltip.item;
  const definition = item.definition;

  return (
    <ClampedPopup popupId="tooltip" position={tooltip}
      style={{ borderTopColor: getItemRarityColor(item) || undefined }}>
      <h3>{definition.label || item.name}</h3>
      <p>{definition.description || definition.category}</p>
      <DetailRow label="Weight" value={`${definition.weight / 1000} kg each`} />
      {item.canSell && item.sellPrice !== undefined && <DetailRow label="Sell price" value={`$${item.sellPrice} each`} />}
      {item.price !== undefined && (
        <>
          <DetailRow label="Buy price" value={`$${item.price} each`} />
          <DetailRow
            label="Stock"
            value={item.stock === false ? "Unlimited" : item.stock}
          />
        </>
      )}
      {Object.entries(inventoryState.visibleMetadata).map(
        ([metadataKey, metadataSettings]) => {
          const metadataValue = item.metadata?.[metadataKey];
          const metadataLabel = metadataSettings?.label ||
            (typeof metadataSettings === "string" ? metadataSettings : metadataKey);
          const progressValue = typeof metadataValue === "number" ||
            (typeof metadataValue === "string" && metadataValue.trim() !== "")
            ? Number(metadataValue) : NaN;
          if (metadataSettings?.progress === true && Number.isFinite(progressValue)) {
            const progressAmount = Math.min(100, Math.max(0, progressValue));
            return (
              <div className="detail metadata-progress-row" key={metadataKey}>
                <span>{metadataLabel}</span>
                <div className="metadata-progress" role="progressbar"
                  aria-label={metadataLabel} aria-valuemin={0} aria-valuemax={100}
                  aria-valuenow={progressAmount}>
                  <div className="metadata-progress-fill" style={{ width: `${progressAmount}%` }} />
                </div>
              </div>
            );
          }
          return metadataValue === undefined ? null : (
            <DetailRow
              key={metadataKey}
              label={metadataLabel}
              valueColor={metadataKey === "rarity" ? getItemRarityColor(item) : undefined}
              value={
                typeof metadataValue === "object"
                  ? JSON.stringify(metadataValue)
                  : metadataValue
              }
            />
          );
        },
      )}
    </ClampedPopup>
  );
}

function ItemContextMenu() {
  const contextMenu = inventoryState.contextMenu;
  if (!contextMenu) return <div id="context" hidden />;
  const { inventory, item } = contextMenu;
  if (contextMenu.attachmentSlot) {
    return <ClampedPopup popupId="context" position={contextMenu}>
      <button onClick={() => removeWeaponAttachment(contextMenu.attachmentSlot)}>Disassemble</button>
    </ClampedPopup>;
  }
  if (inventory.metadata?.clothingEquipment) {
    return <ClampedPopup popupId="context" position={contextMenu}>
      <button onClick={() => unequipClothing(item.definition.clothingSlot)}>Unequip</button>
      <button onClick={() => giveItemToClosest(inventory, item)}>Give</button>
      <button onClick={() => showItemDetails(item, contextMenu)}>Details</button>
    </ClampedPopup>;
  }
  const binding = getItemBinding(item.name);
  const isCapturing =
    inventoryState.keybindCapture?.inventoryId === inventory.id &&
    inventoryState.keybindCapture?.itemId === item.id;
  const canDrop =
    (inventory.type === "player" && inventory.isOwn !== false) ||
    inventory.isPlayerExtra === true;
  return (
    <ClampedPopup popupId="context" position={contextMenu}>
      {inventory.type === "shop" ? (
        item.canBuy !== false && item.stock !== 0 && (
          <button onClick={() => openQuantityDialog(inventory, item, true)}>
            Buy amount…
          </button>
        )
      ) : (
        <>
          {item.definition.useable !== false && (
            <button onClick={() => requestItemAction(inventory, item, "use")}>
              Use
            </button>
          )}
          {item.definition.throwable === true && canGiveFromInventory(inventory) && (
            <button onClick={() => requestItemAction(inventory, item, "takeToHand")}>Take to hand</button>
          )}
          {inventoryState.weaponSystemEnabled && item.definition.weapon && (
            <button onClick={() => openWeaponAttachments(inventory, item)}>Attachments</button>
          )}
          {(binding || item.definition.useable !== false) &&
            (binding ? (
              <button onClick={() => unbindItemKey(inventory, item)}>
                Unbind key ({binding.keyLabel})
              </button>
            ) : (
              <button onClick={() => captureItemKey(inventory, item)}>
                {isCapturing ? "Press a key…" : "Keybind"}
              </button>
            ))}
          {item.amount > 1 && (
            <button onClick={() => openQuantityDialog(inventory, item)}>
              Split stack
            </button>
          )}
          {getSellOffer(inventory, item) && <>
            <button onClick={() => sellItem(inventory, item)}>Sell</button>
            {item.amount > 1 && <button onClick={() => openSaleDialog(inventory, item)}>Sell amount…</button>}
          </>}
          {canGiveFromInventory(inventory) && <button onClick={() => giveItemToClosest(inventory, item)}>Give</button>}
          {canDrop && (
            <>
              <button
                onClick={() =>
                  requestItemAction(inventory, item, "drop", {
                    amount: item.amount,
                  })
                }
              >
                Drop
              </button>
              {item.amount > 1 && (
                <button
                  onClick={() =>
                    openQuantityDialog(inventory, item, false, "drop")
                  }
                >
                  Drop amount…
                </button>
              )}
            </>
          )}
        </>
      )}
      <button onClick={() => showItemDetails(item, contextMenu)}>
        Details
      </button>
    </ClampedPopup>
  );
}

function QuantityDialog() {
  const dialog = inventoryState.dialog;
  const quantityReference = useRef(null);

  useLayoutEffect(() => {
    if (!dialog) return;
    quantityReference.current?.focus();
    quantityReference.current?.select();
  }, [dialog?.inventoryId, dialog?.itemId, dialog?.kind]);

  if (!dialog) return <div id="dialog" hidden />;
  const inventory = findInventory(dialog.inventoryId);
  const item = inventory?.items.find(
    (candidate) => candidate.id === dialog.itemId,
  );
  if (!item) return <div id="dialog" hidden />;
  const isPurchase = dialog.kind === "purchase";
  const isSale = dialog.kind === "sale";
  const saleOffer = isSale && getSellOffer(inventory, item, dialog.shopId);
  const isDrop = dialog.kind === "drop" || dialog.kind === "confirmDrop";
  const isDropConfirmation = dialog.kind === "confirmDrop";
  const quantity = Number(dialog.quantity);
  const maximum = isPurchase
    ? item.stock === false
      ? 1000
      : Math.min(1000, item.stock)
    : isSale ? Math.min(1000, item.amount) : item.amount;
  const totalPrice =
    Number.isInteger(quantity) && quantity > 0
      ? quantity * (isSale ? saleOffer?.product.sellPrice || 0 : item.buyPrice ?? item.price ?? 0)
      : 0;
  const dialogStyle = dialog.position
    ? { left: dialog.position.x, top: dialog.position.y, transform: "none" }
    : undefined;

  return (
    <>
      <div className="modal-backdrop" />
      <div
        id="dialog"
        role="dialog"
        aria-modal="true"
        aria-labelledby="dialog-title"
        style={dialogStyle}
      >
        <h3 id="dialog-title" onPointerDown={startDialogDrag}>
          {isPurchase ? "Buy " : isSale ? "Sell " : isDrop ? "Drop " : ""}
          {item.definition.label}
        </h3>
        {isDropConfirmation ? <p className="drop-confirmation">Drop {quantity} {item.definition.label} into the world?</p> : <div
          className={
            !isPurchase && !isDrop && !isSale
              ? "quantity-entry split-quantity"
              : "quantity-entry"
          }
        >
          {!isPurchase && !isDrop && !isSale && (
            <div className="split-presets" aria-label="Quick split">
              {[25, 50, 75].map((percentage) => (
                <button
                  key={percentage}
                  onClick={() =>
                    updateDialogQuantity(
                      String(
                        Math.max(
                          1,
                          Math.min(
                            item.amount - 1,
                            Math.floor((item.amount * percentage) / 100),
                          ),
                        ),
                      ),
                    )
                  }
                >
                  {percentage}%
                </button>
              ))}
            </div>
          )}
          <input
            ref={quantityReference}
            type="number"
            min={1}
            max={maximum}
            value={dialog.quantity}
            aria-label={
              isPurchase
                ? "Buy quantity"
                : isSale ? "Sell quantity" : isDrop
                  ? "Drop quantity"
                  : "Quantity"
            }
            onChange={(changeEvent) =>
              updateDialogQuantity(changeEvent.target.value)
            }
          />
        </div>}
        {(isPurchase || isSale) && (
          <div className="purchase-total">Total: ${totalPrice}</div>
        )}
        <div className="buttons">
          <button onClick={closeQuantityDialog}>Cancel</button>
          <button className="confirm" onClick={confirmQuantityDialog}>
            {isPurchase ? "Buy" : isSale ? "Sell" : isDrop ? "Drop" : "Confirm"}
          </button>
        </div>
      </div>
    </>
  );
}

function DragGhost() {
  const drag = inventoryState.drag;
  const destination = inventoryState.destination;
  const item = destination?.craft?.item || getDraggedItem();
  if (!drag || !item || (destination?.isWeaponInspection && inventoryState.attachmentDrag?.ready)) return <div className="drag-ghost" hidden />;
  const size = getItemFootprint(item, destination?.craft ? false : drag.isRotated);
  const ghostStyle = {
    width: destination?.ghostWidth || size.x * inventoryState.cellSize,
    height: destination?.ghostHeight || size.y * inventoryState.cellSize,
    left:
      destination?.screenX ??
      inventoryState.pointer.x - drag.offsetX * inventoryState.cellSize,
    top:
      destination?.screenY ??
      inventoryState.pointer.y - drag.offsetY * inventoryState.cellSize,
  };

  return (
    <div
      className={`drag-ghost${destination?.isValid ? "" : " invalid"}${destination?.craft ? " crafting-ghost" : ""}`}
      style={ghostStyle}
    >
      <ItemImage item={item} isRotated={destination?.craft ? false : drag.isRotated} isGhost />
      <RarityFrame item={item} />
      <span className="amount">{destination?.craft || destination?.attachmentSlot ? 1 : drag.quantity}</span>
    </div>
  );
}

function NearbyPlayerTargets() {
  const drag = inventoryState.drag;
  const sourceInventory = drag && findInventory(drag.inventoryId);
  if (!drag || !canGiveFromInventory(sourceInventory)) return null;

  return <div className="nearby-player-targets" aria-hidden="true">
    {inventoryState.nearbyPlayers.map((player) => <div key={player.id} data-player-target={player.id}
      className={`weapon-part-target nearby-player-target${inventoryState.destination?.giveTarget === player.id ? " placement-ready" : ""}`}
      style={{ left: `${player.x * 100}%`, top: `${player.y * 100}%` }} />)}
  </div>;
}

function WeaponAttachmentWindow() {
  const panel = inventoryState.attachmentPanel;
  if (!panel) return null;
  const preview = inventoryState.attachmentPreview;
  const destination = inventoryState.destination;
  const draggedItem = getDraggedItem();
  return (
    <section className="weapon-inspection" aria-label="Weapon attachments">
      <div className="weapon-rotation-surface" onPointerDown={startWeaponRotation}
        aria-label="Drag to rotate weapon" />
      <header className="header weapon-inspection-header">
        <span className="title">{panel.weapon.definition.label}</span>
        <div className="controls">
          <WindowButton label="Close attachments" onClick={closeWeaponAttachments}>×</WindowButton>
        </div>
      </header>
      {preview.status !== "ready" && <div className="weapon-preview-status" role="status">
        {preview.status === "error" ? preview.message || "Weapon model unavailable" : "Loading weapon…"}
      </div>}
      {panel.slots.map((slot) => {
        const anchor = preview.anchors[slot.id];
        if (!anchor || preview.status !== "ready") return null;
        const isCompatible = Boolean(draggedItem && slot.compatibleItems.includes(draggedItem.name));
        const isHighlighted = isCompatible && destination?.isWeaponInspection;
        return <button key={slot.id} type="button"
          className={`weapon-part-target${isHighlighted ? " highlighted" : ""}${isHighlighted && destination.isValid ? " placement-ready" : ""}${slot.installed ? " installed" : ""}`}
          style={{ left: `${anchor.x * 100}%`, top: `${anchor.y * 100}%`,
            pointerEvents: draggedItem ? isCompatible ? "auto" : "none" : slot.installed ? "auto" : "none" }}
          data-attachment-slot={slot.id} aria-label={`${slot.label} attachment point`}
          onPointerDown={(pointerEvent) => pointerEvent.stopPropagation()}
          onContextMenu={(pointerEvent) => openInstalledAttachmentMenu(slot, pointerEvent)} />;
      })}
    </section>
  );
}

function DockingSlots() {
  return (
    <div
      id="docking-slots"
      hidden={!inventoryState.areDockSlotsVisible}
      aria-hidden="true"
    >
      {getDockSlots(innerWidth, innerHeight).map((slot) => (
        <div
          key={slot.id}
          data-dock-slot={slot.id}
          className={`docking-slot${inventoryState.dockTarget === slot.id ? " active" : ""}`}
          style={{
            left: slot.x,
            top: slot.y,
            width: slot.width,
            height: slot.height,
          }}
        />
      ))}
    </div>
  );
}

function InventorySettings() {
  const moveDisplaysButton = useRef(null);
  useLayoutEffect(() => {
    if (inventoryState.settingsOpen && !inventoryState.hudPositioning) moveDisplaysButton.current?.focus();
  }, [inventoryState.settingsOpen, inventoryState.hudPositioning]);
  if (!inventoryState.settingsOpen) return null;
  if (inventoryState.hudPositioning) return <div className="hud-position-toolbar">
    <span>Drag the previews to position your displays.</span>
    <button onClick={() => setHudPositioning(false)}>Done</button>
  </div>;
  const saving = inventoryState.settingsSaving;
  const muted = inventoryState.settingsDraft.soundMuted === true;
  const soundsDisabled = saving || !inventoryState.sounds.enabled;
  const volume = Math.round((inventoryState.settingsDraft.soundVolume ?? inventoryState.sounds.volume ?? 0.2) * 100);

  return (
    <div className="settings-overlay">
      <section id="inventory-settings" role="dialog" aria-modal="true" aria-labelledby="settings-title">
        <header>
          <strong id="settings-title">Inventory settings</strong>
          <button aria-label="Close settings" disabled={saving} onClick={closeInventorySettings}>
            <svg width="12" height="12" viewBox="0 0 12 12" fill="none" stroke="currentColor" aria-hidden="true">
              <path d="M2 2l8 8M10 2l-8 8" />
            </svg>
          </button>
        </header>
        <div className="settings-content">
          <section className="settings-group" aria-labelledby="display-settings-title">
            <h4 id="display-settings-title">Displays</h4>
            <label className="settings-toggle"><input type="checkbox" checked={inventoryState.settingsDraft.weaponDisplay !== false} disabled={saving}
              onChange={(event) => setInventoryPreference("weaponDisplay", event.target.checked)} />Weapon display</label>
            <label className="settings-toggle"><input type="checkbox" checked={inventoryState.settingsDraft.itemNotifications !== false} disabled={saving}
              onChange={(event) => setInventoryPreference("itemNotifications", event.target.checked)} />Item notifications</label>
            <div className="settings-volume">
              <label htmlFor="notification-duration">Notification duration <span>{((inventoryState.settingsDraft.notificationDuration ?? 2500) / 1000).toFixed(1)}s</span></label>
              <input id="notification-duration" type="range" min="1000" max="10000" step="500"
                value={inventoryState.settingsDraft.notificationDuration ?? 2500} disabled={saving || inventoryState.settingsDraft.itemNotifications === false}
                onChange={(event) => setInventoryPreference("notificationDuration", Number(event.target.value))} />
            </div>
            <p>Place your weapon display and item notifications.</p>
            <div className="settings-button-row">
              <button ref={moveDisplaysButton} disabled={saving} onClick={() => setHudPositioning(true)}>Move displays</button>
              <button disabled={saving} onClick={resetHudPositions}>Reset positions</button>
            </div>
          </section>
          <section className="settings-group" aria-labelledby="sound-settings-title">
            <h4 id="sound-settings-title">Sounds</h4>
            <label className="sound-mute">
              <input type="checkbox" checked={muted} disabled={soundsDisabled}
                onChange={(event) => setSoundPreference("soundMuted", event.target.checked)} />
              Mute UI sounds
            </label>
            <div className="settings-volume">
              <label htmlFor="sound-volume">Volume <span>{volume}%</span></label>
              <input id="sound-volume" type="range" min="0" max="100" step="1" value={volume}
                disabled={soundsDisabled || muted}
                onChange={(event) => setSoundPreference("soundVolume", Number(event.target.value) / 100)} />
            </div>
            <button disabled={soundsDisabled || muted} onClick={previewInventorySound}>Test sound</button>
          </section>
          <section className="settings-group" aria-labelledby="window-settings-title">
            <h4 id="window-settings-title">Inventory</h4>
            <label className="settings-field" htmlFor="ui-scale">UI size
              <select id="ui-scale" value={inventoryState.settingsDraft.uiScale || "small"} disabled={saving}
                onChange={(event) => setInventoryPreference("uiScale", event.target.value)}>
                <option value="small">Small</option><option value="medium">Medium</option><option value="large">Large</option>
              </select>
            </label>
            <label className="settings-toggle"><input type="checkbox" checked={inventoryState.settingsDraft.confirmDropping === true} disabled={saving}
              onChange={(event) => setInventoryPreference("confirmDropping", event.target.checked)} />Confirm dropping items</label>
            <label className="settings-toggle"><input type="checkbox" checked={inventoryState.settingsDraft.rememberContainers === true} disabled={saving}
              onChange={(event) => setInventoryPreference("rememberContainers", event.target.checked)} />Remember open carried containers</label>
            <p>Restore your default window layout.</p>
            <button disabled={saving} onClick={resetInventoryLayout}>Reset windows</button>
          </section>
        </div>
        <div className="settings-actions">
          <button disabled={saving} onClick={closeInventorySettings}>Cancel</button>
          <button className="confirm" disabled={saving} onClick={saveInventorySettings}>{saving ? "Saving..." : "Save"}</button>
        </div>
      </section>
    </div>
  );
}

function ThrowPowerMeter() {
  const power = inventoryState.throwPower;
  if (power === null) return null;
  return <div className="throw-power-meter" role="progressbar" aria-label="Throw power"
    aria-valuemin={0} aria-valuemax={100} aria-valuenow={Math.round(power * 100)}>
    <div className="throw-power-fill" style={{ height: `${power * 100}%` }} />
  </div>;
}

function EquippedWeaponHud() {
  const preview = inventoryState.settingsOpen;
  const weapon = preview ? inventoryState.equippedWeapon || { name: "weapon_pistol", label: "Pistol", image: "weapon_pistol.png", ammo: 12, clipSize: 12, showAmmo: true }
    : inventoryState.equippedWeapon;
  if (!weapon) return null;
  const settings = preview ? inventoryState.settingsDraft : inventoryState.playerSettings;
  if (!preview && settings.weaponDisplay === false) return null;
  const position = settings.weaponHudPosition || { x: 0.94, y: 0.91 };
  return <aside className={`weapon-hud${preview ? " hud-preview" : ""}`} aria-label={`Equipped ${weapon.label}`}
    style={getHudPositionStyle(position, 172, 64)} onPointerDown={(pointerEvent) => startHudDrag("weaponHudPosition", pointerEvent)}>
    <div className="weapon-hud-image"><ItemImage item={{ name: weapon.name,
      definition: { label: weapon.label, image: weapon.image, size: { x: 1, y: 1 } } }} /></div>
    {weapon.showAmmo && <span className="weapon-hud-ammo" title="Loaded ammunition / capacity">{weapon.ammo}<small> / {weapon.clipSize}</small></span>}
    {preview && <span className="hud-preview-label">Weapon display</span>}
  </aside>;
}

function ItemBoxNotifications() {
  let style = { top: "auto", bottom: 24, left: "50%", right: "auto", transform: "translateX(-50%)" };
  const settings = inventoryState.settingsOpen ? inventoryState.settingsDraft : inventoryState.playerSettings;
  if (!inventoryState.settingsOpen && settings.itemNotifications === false) return null;
  if (settings.itemBoxPosition) style = getHudPositionStyle(settings.itemBoxPosition, 150,
    inventoryState.settingsOpen ? 58 : Math.max(58, inventoryState.itemBoxes.length * 58 + (inventoryState.itemBoxes.length - 1) * 8));
  const notifications = inventoryState.settingsOpen
    ? [
        {
          id: "preview",
          definition: {
            name: "bandage",
            label: "Bandage",
            image: "bandage.png",
            size: { x: 1, y: 1 },
          },
          action: "added",
        },
      ]
    : inventoryState.itemBoxes;
  return (
    <aside
      className={`item-box-notifications${inventoryState.settingsOpen ? " hud-preview" : ""}`}
      onPointerDown={(pointerEvent) => startHudDrag("itemBoxPosition", pointerEvent)}
      data-position={settings.itemBoxPosition ? "custom" : "bottom-center"}
      style={style}
      aria-live="polite"
    >
      {notifications.map((notification) => (
        <div className="item-box-notification" key={notification.id}>
          <div className="item-box-image">
            <ItemImage
              item={{
                name: notification.definition.name,
                definition: notification.definition,
              }}
            />
          </div>
          <span>{notification.action === "added" ? "Added" : "Removed"}</span>
        </div>
      ))}
    </aside>
  );
}

export function InventoryApp() {
  useSyncExternalStore(subscribeToInventory, getStoreVersion);

  return (
    <>
      <main
        id="inventory"
        hidden={!inventoryState.isOpen || inventoryState.hudPositioning}
        style={{ "--cell": `${inventoryState.cellSize}px`, "--ui-scale": getInterfaceScale() }}
      >
        <NearbyPlayerTargets />
        <InventoryWorkspace />
        <ClothingWindow />
        <WeaponAttachmentWindow />
        <DockingSlots />
        <ItemTooltip />
        <ItemContextMenu />
        <QuantityDialog />
        <footer>
          <span>{inventoryState.crafting || inventoryState.craftingPending ? "ESC · Cancel crafting" : "TAB / ESC · Close"}</span>
          {!inventoryState.crafting && !inventoryState.craftingPending && <span>Drag items · Right-click for actions</span>}
          <button id="reset" onClick={resetInventoryLayout}>
            Reset layout
          </button>
        </footer>
      </main>
      {createPortal(
        <>
          <DragGhost />
          <InventorySettings />
          <ItemBoxNotifications />
          <EquippedWeaponHud />
          <ThrowPowerMeter />
        </>,
        document.body,
      )}
    </>
  );
}
