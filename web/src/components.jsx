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
  requestItemAction,
  startWindowDrag,
  focusInventory,
  undockInventory,
  selectInventoryTab,
  toggleMinimised,
  closeInventoryWindow,
  resetInventoryLayout,
} from "./inventoryStore.js";

function ItemImage({
  item,
  isRotated = item.rotated === true,
  isGhost = false,
}) {
  const [hasImageError, setHasImageError] = useState(false);
  const imageName = item.definition.image;
  const imageIsAvailable =
    imageName && /^[\w.-]+\.png$/i.test(imageName) && !hasImageError;

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

function InventoryItem({ inventory, item }) {
  const size = getItemFootprint(item);
  const activeDrag = inventoryState.drag;
  const isDragSource =
    activeDrag?.inventoryId === inventory.id && activeDrag.itemId === item.id;
  const isShop = inventory.type === "shop";
  const itemClasses = [
    "item",
    isDragSource && "drag-source",
    isShop && item.stock === 0 && "sold-out",
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
      onDoubleClick={() =>
        isShop
          ? openQuantityDialog(inventory, item, true)
          : requestItemAction(inventory, item, "use")
      }
    >
      <ItemImage item={item} />
      <span className="amount">
        {isShop ? (item.stock === false ? "∞" : item.stock) : item.amount}
      </span>
      {isShop && <span className="price">${item.price}</span>}
    </div>
  );
}

function PlacementCells({ inventory }) {
  const destination = inventoryState.destination;
  if (!destination || destination.inventoryId !== inventory.id) return null;
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
    <div className={`placement${destination.isValid ? "" : " invalid"}`}>
      {cells}
    </div>
  );
}

function InventoryGrid({ inventory }) {
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
        {inventory.items.map((item) => (
          <InventoryItem key={item.id} inventory={inventory} item={item} />
        ))}
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
      <WindowButton
        label={isDocked ? "Undock active tab" : "Bring to front"}
        onClick={() =>
          isDocked ? undockInventory(inventory) : focusInventory(inventory)
        }
      >
        ▣
      </WindowButton>
      {!isDocked && (
        <WindowButton
          label="Minimise"
          onClick={() => toggleMinimised(inventory)}
        >
          −
        </WindowButton>
      )}
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
        height: dockBounds.height,
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
      className={`window${isDocked ? " docked" : layout.minimised ? " minimised" : ""}`}
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

function ClampedPopup({ popupId, position, children }) {
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
      style={{ left: popupPosition.x, top: popupPosition.y }}
    >
      {children}
    </div>
  );
}

function DetailRow({ label, value }) {
  return (
    <div className="detail">
      <span>{label}</span>
      <span>{String(value)}</span>
    </div>
  );
}

function ItemTooltip() {
  const tooltip = inventoryState.tooltip;
  if (!tooltip) return <div id="tooltip" hidden />;
  const item = tooltip.item;
  const definition = item.definition;
  const size = getItemFootprint(item);

  return (
    <ClampedPopup popupId="tooltip" position={tooltip}>
      <h3>{definition.label || item.name}</h3>
      <p>{definition.description || definition.category}</p>
      <DetailRow label="Weight" value={`${definition.weight / 1000} kg each`} />
      <DetailRow label="Size" value={`${size.x} × ${size.y}`} />
      <DetailRow label="Quantity" value={item.amount} />
      <DetailRow label="Item ID" value={item.id} />
      {item.price !== undefined && (
        <>
          <DetailRow label="Price" value={`$${item.price} each`} />
          <DetailRow
            label="Stock"
            value={item.stock === false ? "Unlimited" : item.stock}
          />
        </>
      )}
      {Object.entries(inventoryState.visibleMetadata).map(
        ([metadataKey, metadataLabel]) => {
          const metadataValue = item.metadata?.[metadataKey];
          return metadataValue === undefined ? null : (
            <DetailRow
              key={metadataKey}
              label={metadataLabel}
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

  return (
    <ClampedPopup popupId="context" position={contextMenu}>
      {inventory.type === "shop" ? (
        <button
          disabled={item.stock === 0}
          onClick={() => openQuantityDialog(inventory, item, true)}
        >
          Buy amount…
        </button>
      ) : (
        <>
          <button
            disabled={!item.definition.useable}
            onClick={() => requestItemAction(inventory, item, "use")}
          >
            Use
          </button>
          <button
            disabled={item.amount < 2}
            onClick={() => openQuantityDialog(inventory, item)}
          >
            Split stack
          </button>
          <button onClick={() => openQuantityDialog(inventory, item)}>
            Move quantity…
          </button>
          {inventory.type === "player" && inventory.isOwn !== false && (
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
              <button
                disabled={item.amount < 2}
                onClick={() =>
                  openQuantityDialog(inventory, item, false, "drop")
                }
              >
                Drop amount…
              </button>
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
  const isDrop = dialog.kind === "drop";
  const quantity = Number(dialog.quantity);
  const maximum = isPurchase
    ? item.stock === false
      ? 1000
      : Math.min(1000, item.stock)
    : item.amount;
  const totalPrice =
    Number.isInteger(quantity) && quantity > 0
      ? quantity * (item.price || 0)
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
          {isPurchase ? "Buy " : isDrop ? "Drop " : ""}
          {item.definition.label}
        </h3>
        <input
          ref={quantityReference}
          type="number"
          min={1}
          max={maximum}
          value={dialog.quantity}
          aria-label={
            isPurchase ? "Buy quantity" : isDrop ? "Drop quantity" : "Quantity"
          }
          onChange={(changeEvent) =>
            updateDialogQuantity(changeEvent.target.value)
          }
        />
        {isPurchase && (
          <div className="purchase-total">Total: ${totalPrice}</div>
        )}
        <div className="buttons">
          <button onClick={closeQuantityDialog}>Cancel</button>
          <button className="confirm" onClick={confirmQuantityDialog}>
            {isPurchase ? "Buy" : isDrop ? "Drop" : "Confirm"}
          </button>
        </div>
      </div>
    </>
  );
}

function DragGhost() {
  const drag = inventoryState.drag;
  const item = getDraggedItem();
  if (!drag || !item) return <div className="drag-ghost" hidden />;
  const size = getItemFootprint(item, drag.isRotated);
  const destination = inventoryState.destination;
  const ghostStyle = {
    width: size.x * inventoryState.cellSize,
    height: size.y * inventoryState.cellSize,
    left:
      destination?.screenX ??
      inventoryState.pointer.x - drag.offsetX * inventoryState.cellSize,
    top:
      destination?.screenY ??
      inventoryState.pointer.y - drag.offsetY * inventoryState.cellSize,
  };

  return (
    <div
      className={`drag-ghost${destination?.isValid ? "" : " invalid"}`}
      style={ghostStyle}
    >
      <ItemImage item={item} isRotated={drag.isRotated} isGhost />
      <span className="amount">{drag.quantity}</span>
    </div>
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

export function InventoryApp() {
  useSyncExternalStore(subscribeToInventory, getStoreVersion);

  return (
    <>
      <main
        id="inventory"
        hidden={!inventoryState.isOpen}
        style={{ "--cell": `${inventoryState.cellSize}px` }}
      >
        <InventoryWorkspace />
        <DockingSlots />
        <ItemTooltip />
        <ItemContextMenu />
        <QuantityDialog />
        <footer>
          <span>TAB / ESC · Close</span>
          <span>Drag items · Right-click for actions</span>
          <button id="reset" onClick={resetInventoryLayout}>
            Reset layout
          </button>
        </footer>
      </main>
      {createPortal(
        <>
          <DragGhost />
          <div id="toast" hidden={!inventoryState.notice}>
            {inventoryState.notice}
          </div>
        </>,
        document.body,
      )}
    </>
  );
}
