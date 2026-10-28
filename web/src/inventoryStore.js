// FiveM messages and pointer interactions live here; React owns all rendered UI.
import {
  DOCK_SLOT_IDS,
  LEGACY_DOCK_SLOTS,
  getDockSlots,
  getDockSlotAtPoint,
} from "./docking.js";
const isBrowserPreview = typeof GetParentResourceName !== "function";
const resourceName = isBrowserPreview
  ? "tss-inventory"
  : GetParentResourceName();
const subscribers = new Set();

let storeVersion = 0;
let hoverTimeout = null;
let noticeTimeout = null;
let dragAnimationFrame = null;
let pressedItem = null;
let windowDrag = null;
let dialogDrag = null;
let lastDialogPosition = null;

export const inventoryState = {
  isOpen: false,
  inventories: [],
  visibleMetadata: {},
  layouts: {},
  activeTabs: {},
  paymentMethods: {},
  cellSize: 48,
  frontOrder: 10,
  isRequestPending: false,
  pointer: { x: 0, y: 0 },
  viewport: { width: innerWidth, height: innerHeight },
  drag: null,
  destination: null,
  dockTarget: null,
  isDockKeyHeld: false,
  areDockSlotsVisible: false,
  tooltip: null,
  contextMenu: null,
  dialog: null,
  notice: null,
};

try {
  const savedLayout = JSON.parse(localStorage.getItem("tss-layout-v1") || "{}");
  inventoryState.layouts = savedLayout.layout || {};
  inventoryState.activeTabs = savedLayout.active || {};
  for (const [legacySlot, dockSlot] of Object.entries(LEGACY_DOCK_SLOTS)) {
    if (
      inventoryState.activeTabs[legacySlot] &&
      !inventoryState.activeTabs[dockSlot]
    ) {
      inventoryState.activeTabs[dockSlot] =
        inventoryState.activeTabs[legacySlot];
    }
    delete inventoryState.activeTabs[legacySlot];
  }
  inventoryState.frontOrder = Math.max(
    10,
    ...Object.values(inventoryState.layouts).map(
      (layout) => Number(layout.frontOrder) || 10,
    ),
  );
} catch {
  // Invalid browser preferences never prevent the inventory from opening.
}

export function subscribeToInventory(callback) {
  subscribers.add(callback);
  return () => subscribers.delete(callback);
}

export function getStoreVersion() {
  return storeVersion;
}

function publishChanges() {
  storeVersion += 1;
  subscribers.forEach((callback) => callback());
}

function saveLayout() {
  try {
    const persistentLayouts = Object.fromEntries(
      Object.entries(inventoryState.layouts).filter(
        ([inventoryId]) => !inventoryId.startsWith("drop:"),
      ),
    );
    const persistentActiveTabs = Object.fromEntries(
      Object.entries(inventoryState.activeTabs).filter(
        ([, inventoryId]) => !inventoryId.startsWith("drop:"),
      ),
    );
    localStorage.setItem(
      "tss-layout-v1",
      JSON.stringify({
        layout: persistentLayouts,
        active: persistentActiveTabs,
      }),
    );
  } catch {
    // The UI remains usable when local preference storage is unavailable.
  }
}

export function findInventory(inventoryId) {
  return inventoryState.inventories.find(
    (inventory) => inventory.id === inventoryId,
  );
}

export function getItemFootprint(item, isRotated = item.rotated === true) {
  const itemSize = item.definition.size;
  return isRotated ? { x: itemSize.y, y: itemSize.x } : itemSize;
}

export function getPaymentMethod(shop) {
  return (
    inventoryState.paymentMethods[shop.id] ||
    (shop.account === "bank" ? "bank" : "cash")
  );
}

export function selectPaymentMethod(shop, paymentMethod) {
  inventoryState.paymentMethods[shop.id] = paymentMethod;
  publishChanges();
}

export function getInventoryLayout(inventory, inventoryIndex = 0) {
  if (!inventoryState.layouts[inventory.id]) {
    inventoryState.layouts[inventory.id] = {
      x:
        inventory.type === "shop"
          ? Math.max(
              60,
              innerWidth - inventory.size.x * inventoryState.cellSize - 76,
            )
          : 60 + inventoryIndex * 350,
      y: 90 + inventoryIndex * 45,
      dock: null,
      minimised: false,
      frontOrder: ++inventoryState.frontOrder,
    };
  }

  const layout = inventoryState.layouts[inventory.id];
  if (layout.dock && !DOCK_SLOT_IDS.includes(layout.dock)) {
    layout.dock = LEGACY_DOCK_SLOTS[layout.dock] || null;
  }

  return layout;
}

export function getDockBounds(dockSlotId) {
  return getDockSlots(innerWidth, innerHeight).find(
    (slot) => slot.id === dockSlotId,
  );
}

function refreshDockingPreview() {
  inventoryState.areDockSlotsVisible = Boolean(
    windowDrag?.hasMoved && inventoryState.isDockKeyHeld,
  );
  inventoryState.dockTarget = inventoryState.areDockSlotsVisible
    ? getDockSlotAtPoint(
        inventoryState.pointer.x,
        inventoryState.pointer.y,
        innerWidth,
        innerHeight,
      )
    : null;
}

export function showNotice(message) {
  inventoryState.notice = message;
  clearTimeout(noticeTimeout);
  noticeTimeout = setTimeout(() => {
    inventoryState.notice = null;
    publishChanges();
  }, 3500);
  publishChanges();
}

async function sendNuiRequest(route, payload = {}) {
  if (isBrowserPreview) {
    return route === "action"
      ? {
          ok: false,
          message: "Preview only — connect to FiveM to change items",
        }
      : { ok: true };
  }

  try {
    const response = await fetch(`https://${resourceName}/${route}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    return await response.json();
  } catch {
    return { ok: false, message: "Inventory connection failed" };
  }
}

function clearPopups() {
  clearTimeout(hoverTimeout);
  inventoryState.tooltip = null;
  inventoryState.contextMenu = null;
}

export async function requestItemAction(
  inventory,
  item,
  actionKind,
  details = {},
) {
  if (inventoryState.isRequestPending) return;
  inventoryState.isRequestPending = true;
  clearPopups();
  publishChanges();

  try {
    const response = await sendNuiRequest("action", {
      kind: actionKind,
      from: inventory.id,
      revision: inventory.revision,
      itemId: item.id,
      ...details,
    });
    if (!response.ok) showNotice(response.message || "Action refused");
    else if (actionKind === "buy" && response.message)
      showNotice(response.message);
  } finally {
    inventoryState.isRequestPending = false;
    publishChanges();
  }
}

export function scheduleItemTooltip(item, pointerEvent) {
  if (inventoryState.drag) return;
  const pointerPosition = {
    x: pointerEvent.clientX + 18,
    y: pointerEvent.clientY + 14,
  };
  clearTimeout(hoverTimeout);
  hoverTimeout = setTimeout(() => {
    inventoryState.tooltip = { item, ...pointerPosition };
    publishChanges();
  }, 350);
}

export function hideItemTooltip() {
  clearTimeout(hoverTimeout);
  inventoryState.tooltip = null;
  publishChanges();
}

export function openItemContextMenu(inventory, item, pointerEvent) {
  pointerEvent.preventDefault();
  pointerEvent.stopPropagation();
  cancelItemDrag(false);
  clearPopups();
  inventoryState.contextMenu = {
    inventory,
    item,
    x: pointerEvent.clientX,
    y: pointerEvent.clientY,
  };
  publishChanges();
}

export function showItemDetails(item, contextPosition) {
  clearPopups();
  inventoryState.tooltip = { item, x: contextPosition.x, y: contextPosition.y };
  publishChanges();
}

export function openQuantityDialog(
  inventory,
  item,
  isPurchase = false,
  dialogKind = null,
) {
  if (isPurchase && item.stock === 0) return showNotice("Out of stock");
  clearPopups();
  inventoryState.dialog = {
    kind: dialogKind || (isPurchase ? "purchase" : "quantity"),
    inventoryId: inventory.id,
    itemId: item.id,
    quantity: "1",
    position: lastDialogPosition,
  };
  publishChanges();
}

export function updateDialogQuantity(quantity) {
  if (!inventoryState.dialog) return;
  inventoryState.dialog = { ...inventoryState.dialog, quantity };
  publishChanges();
}

export function closeQuantityDialog() {
  inventoryState.dialog = null;
  dialogDrag = null;
  publishChanges();
}

export function startDialogDrag(pointerEvent) {
  if (pointerEvent.button !== 0) return;
  pointerEvent.preventDefault();
  const dialogBounds = pointerEvent.currentTarget
    .closest("#dialog")
    .getBoundingClientRect();
  dialogDrag = {
    offsetX: pointerEvent.clientX - dialogBounds.left,
    offsetY: pointerEvent.clientY - dialogBounds.top,
  };
  pointerEvent.currentTarget.setPointerCapture(pointerEvent.pointerId);
}

export function confirmQuantityDialog() {
  const dialog = inventoryState.dialog;
  if (!dialog) return;
  const inventory = findInventory(dialog.inventoryId);
  const item = inventory?.items.find(
    (inventoryItem) => inventoryItem.id === dialog.itemId,
  );
  if (!item) return closeQuantityDialog();
  const quantity = Number(dialog.quantity);
  const maximum =
    dialog.kind === "purchase"
      ? item.stock === false
        ? 1000
        : Math.min(1000, item.stock)
      : item.amount;

  if (!Number.isInteger(quantity) || quantity < 1 || quantity > maximum)
    return showNotice("Enter a valid quantity");
  closeQuantityDialog();

  if (dialog.kind === "drop") {
    requestItemAction(inventory, item, "drop", { amount: quantity });
    return;
  }

  if (dialog.kind !== "purchase") {
    beginItemDrag(inventory, item, quantity, 0, 0);
    return;
  }

  const playerInventory = inventoryState.inventories.find(
    (candidate) => candidate.type === "player" && candidate.isOwn !== false,
  );
  if (!playerInventory) return showNotice("Open your player inventory first");
  requestItemAction(inventory, item, "buy", {
    to: playerInventory.id,
    targetRevision: playerInventory.revision,
    amount: quantity,
    account: getPaymentMethod(inventory),
  });
}

export function pressInventoryItem(inventory, item, pointerEvent) {
  if (
    pointerEvent.button !== 0 ||
    inventoryState.drag ||
    inventoryState.isRequestPending
  )
    return;
  pointerEvent.preventDefault();
  const itemBounds = pointerEvent.currentTarget.getBoundingClientRect();
  inventoryState.pointer = { x: pointerEvent.clientX, y: pointerEvent.clientY };
  pressedItem = {
    inventory,
    item,
    pointerX: pointerEvent.clientX,
    pointerY: pointerEvent.clientY,
    offsetX: Math.floor(
      (pointerEvent.clientX - itemBounds.left) / inventoryState.cellSize,
    ),
    offsetY: Math.floor(
      (pointerEvent.clientY - itemBounds.top) / inventoryState.cellSize,
    ),
  };
}

function metadataMatches(leftValue, rightValue) {
  if (leftValue === rightValue) return true;
  if (
    !leftValue ||
    !rightValue ||
    typeof leftValue !== "object" ||
    typeof rightValue !== "object"
  )
    return false;
  const leftKeys = Object.keys(leftValue);
  return (
    leftKeys.length === Object.keys(rightValue).length &&
    leftKeys.every(
      (key) =>
        Object.hasOwn(rightValue, key) &&
        metadataMatches(leftValue[key], rightValue[key]),
    )
  );
}

export function getDraggedItem() {
  const drag = inventoryState.drag;
  return (
    drag &&
    findInventory(drag.inventoryId)?.items.find(
      (item) => item.id === drag.itemId,
    )
  );
}

function calculateDestination() {
  const drag = inventoryState.drag;
  const pointer = inventoryState.pointer;
  const gridElement = document
    .elementFromPoint(pointer.x, pointer.y)
    ?.closest(".grid");
  const inventory = gridElement && findInventory(gridElement.dataset.inventory);
  const item = getDraggedItem();
  if (!drag || !inventory || !item) return null;

  const gridBounds = gridElement.getBoundingClientRect();
  const column =
    Math.floor((pointer.x - gridBounds.left) / inventoryState.cellSize) +
    1 -
    drag.offsetX;
  const row =
    Math.floor((pointer.y - gridBounds.top) / inventoryState.cellSize) +
    1 -
    drag.offsetY;
  const size = getItemFootprint(item, drag.isRotated);
  let highlight = { x: column, y: row, width: size.x, height: size.y };
  const result = (isValid, reason = "") => ({
    inventoryId: inventory.id,
    column,
    row,
    highlight,
    isValid,
    reason,
    screenX: gridBounds.left + (highlight.x - 1) * inventoryState.cellSize,
    screenY: gridBounds.top + (highlight.y - 1) * inventoryState.cellSize,
  });

  if (inventory.type === "shop")
    return result(false, "Shop inventory is read-only");
  if (
    findInventory(drag.inventoryId)?.type === "shop" &&
    (inventory.type !== "player" || inventory.isOwn === false)
  )
    return result(false, "Buy into your own inventory");
  if (
    column < 1 ||
    row < 1 ||
    column > inventory.size.x ||
    row > inventory.size.y
  )
    return result(false, "Outside inventory");
  if (
    (inventory.whitelist?.length && !inventory.whitelist.includes(item.name)) ||
    inventory.blacklist?.includes(item.name)
  )
    return result(false, "Item not allowed");
  if (
    inventory.id !== drag.inventoryId &&
    inventory.maxWeight != null &&
    (inventory.weight || 0) + item.definition.weight * drag.quantity >
      inventory.maxWeight
  )
    return result(false, "Weight limit exceeded");

  const otherItems = inventory.items.filter(
    (candidate) =>
      !(inventory.id === drag.inventoryId && candidate.id === item.id),
  );
  const stackTarget = otherItems.find((candidate) => {
    const candidateSize = getItemFootprint(candidate);
    return (
      column >= candidate.x &&
      column < candidate.x + candidateSize.x &&
      row >= candidate.y &&
      row < candidate.y + candidateSize.y
    );
  });

  if (stackTarget) {
    const targetSize = getItemFootprint(stackTarget);
    highlight = {
      x: stackTarget.x,
      y: stackTarget.y,
      width: targetSize.x,
      height: targetSize.y,
    };
    const canStack =
      item.definition.stack &&
      item.name === stackTarget.name &&
      metadataMatches(item.metadata, stackTarget.metadata) &&
      stackTarget.amount + drag.quantity <= item.definition.stackSize;
    return result(Boolean(canStack), "Items cannot stack here");
  }

  if (
    column + size.x - 1 > inventory.size.x ||
    row + size.y - 1 > inventory.size.y
  )
    return result(false, "Outside inventory");
  if (inventory.id === drag.inventoryId && drag.quantity < item.amount)
    otherItems.push(item);

  for (const obstacle of otherItems) {
    const obstacleSize = getItemFootprint(obstacle);
    if (
      column < obstacle.x + obstacleSize.x &&
      column + size.x > obstacle.x &&
      row < obstacle.y + obstacleSize.y &&
      row + size.y > obstacle.y
    )
      return result(false, "Space occupied");
  }

  return result(true);
}

function refreshDragPreview() {
  if (!inventoryState.drag) return;
  inventoryState.destination = calculateDestination();
  publishChanges();
}

function scrollDuringDrag() {
  if (!inventoryState.drag) return;
  const pointer = inventoryState.pointer;
  const scrollBody = document
    .elementFromPoint(pointer.x, pointer.y)
    ?.closest(".body");
  if (scrollBody) {
    const scrollBounds = scrollBody.getBoundingClientRect();
    scrollBody.scrollTop +=
      pointer.y > scrollBounds.bottom - 22
        ? 8
        : pointer.y < scrollBounds.top + 22
          ? -8
          : 0;
    scrollBody.scrollLeft +=
      pointer.x > scrollBounds.right - 22
        ? 8
        : pointer.x < scrollBounds.left + 22
          ? -8
          : 0;
    refreshDragPreview();
  }
  dragAnimationFrame = requestAnimationFrame(scrollDuringDrag);
}

function beginItemDrag(inventory, item, quantity, offsetX, offsetY) {
  pressedItem = null;
  if (inventory.type === "shop" && item.stock === 0)
    return showNotice("Out of stock");
  clearPopups();
  inventoryState.drag = {
    inventoryId: inventory.id,
    itemId: item.id,
    quantity: inventory.type === "shop" ? 1 : quantity,
    offsetX,
    offsetY,
    isRotated: item.rotated === true,
  };
  refreshDragPreview();
  dragAnimationFrame = requestAnimationFrame(scrollDuringDrag);
}

export function cancelItemDrag(shouldPublish = true) {
  pressedItem = null;
  inventoryState.drag = null;
  inventoryState.destination = null;
  if (dragAnimationFrame !== null) cancelAnimationFrame(dragAnimationFrame);
  dragAnimationFrame = null;
  if (shouldPublish) publishChanges();
}

function finishItemDrag() {
  const drag = inventoryState.drag;
  const destination = calculateDestination();
  const item = getDraggedItem();
  const sourceInventory = drag && findInventory(drag.inventoryId);
  cancelItemDrag();
  if (!sourceInventory || !item) return;
  if (!destination) {
    const pointerElement = document.elementFromPoint(
      inventoryState.pointer.x,
      inventoryState.pointer.y,
    );
    const isWorldBackground =
      pointerElement?.closest("#inventory") &&
      !pointerElement.closest(".window, #dialog, #context, footer");
    if (
      isWorldBackground &&
      sourceInventory.type === "player" &&
      sourceInventory.isOwn !== false
    ) {
      requestItemAction(sourceInventory, item, "drop", {
        amount: drag.quantity,
        rotated: drag.isRotated,
      });
    }
    return;
  }
  if (!destination.isValid) return showNotice(destination.reason);
  const targetInventory = findInventory(destination.inventoryId);

  requestItemAction(
    sourceInventory,
    item,
    sourceInventory.type === "shop" ? "buy" : "move",
    {
      to: targetInventory.id,
      targetRevision: targetInventory.revision,
      amount: sourceInventory.type === "shop" ? 1 : drag.quantity,
      x: destination.column,
      y: destination.row,
      rotated: drag.isRotated,
      ...(sourceInventory.type === "shop"
        ? { account: getPaymentMethod(sourceInventory) }
        : {}),
    },
  );
}

export function startWindowDrag(inventory, pointerEvent) {
  if (pointerEvent.button !== 0 || pointerEvent.target.closest(".controls"))
    return;
  pointerEvent.preventDefault();
  clearPopups();
  const layout = getInventoryLayout(inventory);
  windowDrag = {
    inventoryId: inventory.id,
    startX: pointerEvent.clientX,
    startY: pointerEvent.clientY,
    originalX: layout.x,
    originalY: layout.y,
    hasMoved: false,
  };
}

export function focusInventory(inventory) {
  getInventoryLayout(inventory).frontOrder = ++inventoryState.frontOrder;
  publishChanges();
}

export function undockInventory(inventory) {
  Object.assign(getInventoryLayout(inventory), {
    dock: null,
    x: 100,
    y: 100,
    minimised: false,
  });
  saveLayout();
  publishChanges();
}

export function selectInventoryTab(dockSlotId, inventoryId) {
  inventoryState.activeTabs[dockSlotId] = inventoryId;
  saveLayout();
  publishChanges();
}

export function toggleMinimised(inventory) {
  const layout = getInventoryLayout(inventory);
  layout.minimised = !layout.minimised;
  saveLayout();
  publishChanges();
}

export function resetInventoryLayout() {
  inventoryState.layouts = {};
  inventoryState.activeTabs = {};
  inventoryState.inventories.forEach(getInventoryLayout);
  saveLayout();
  publishChanges();
}

export async function closeInventoryWindow(inventory) {
  inventoryState.inventories = inventoryState.inventories.filter(
    (candidate) => candidate.id !== inventory.id,
  );
  publishChanges();
  await sendNuiRequest("closeInventory", { id: inventory.id });
  if (!inventoryState.inventories.length) closeInventoryUi();
}

export async function closeInventoryUi() {
  inventoryState.isOpen = false;
  inventoryState.dialog = null;
  clearPopups();
  cancelItemDrag(false);
  windowDrag = null;
  dialogDrag = null;
  inventoryState.isDockKeyHeld = false;
  inventoryState.areDockSlotsVisible = false;
  inventoryState.dockTarget = null;
  publishChanges();
  await sendNuiRequest("close");
}

function handlePointerMove(pointerEvent) {
  inventoryState.pointer = { x: pointerEvent.clientX, y: pointerEvent.clientY };

  if (dialogDrag) {
    const dialogBounds = document
      .getElementById("dialog")
      .getBoundingClientRect();
    lastDialogPosition = {
      x: Math.max(
        0,
        Math.min(
          innerWidth - dialogBounds.width,
          pointerEvent.clientX - dialogDrag.offsetX,
        ),
      ),
      y: Math.max(
        0,
        Math.min(
          innerHeight - dialogBounds.height,
          pointerEvent.clientY - dialogDrag.offsetY,
        ),
      ),
    };
    inventoryState.dialog = {
      ...inventoryState.dialog,
      position: lastDialogPosition,
    };
    publishChanges();
    return;
  }

  if (
    pressedItem &&
    Math.hypot(
      pointerEvent.clientX - pressedItem.pointerX,
      pointerEvent.clientY - pressedItem.pointerY,
    ) > 4
  ) {
    const press = pressedItem;
    beginItemDrag(
      press.inventory,
      press.item,
      press.item.amount,
      press.offsetX,
      press.offsetY,
    );
  }
  if (inventoryState.drag) refreshDragPreview();
  if (!windowDrag) return;

  const layout = inventoryState.layouts[windowDrag.inventoryId];
  if (
    !windowDrag.hasMoved &&
    Math.hypot(
      pointerEvent.clientX - windowDrag.startX,
      pointerEvent.clientY - windowDrag.startY,
    ) < 5
  )
    return;
  if (!windowDrag.hasMoved && layout.dock) {
    layout.dock = null;
    windowDrag.originalX = pointerEvent.clientX - 80;
    windowDrag.originalY = pointerEvent.clientY - 15;
    windowDrag.startX = pointerEvent.clientX;
    windowDrag.startY = pointerEvent.clientY;
  }
  windowDrag.hasMoved = true;
  layout.x = Math.max(
    0,
    Math.min(
      innerWidth - 160,
      windowDrag.originalX + pointerEvent.clientX - windowDrag.startX,
    ),
  );
  layout.y = Math.max(
    0,
    Math.min(
      innerHeight - 40,
      windowDrag.originalY + pointerEvent.clientY - windowDrag.startY,
    ),
  );
  refreshDockingPreview();
  publishChanges();
}

function handlePointerUp(pointerEvent) {
  if (pointerEvent.button !== 0) return;
  pressedItem = null;
  dialogDrag = null;
  if (inventoryState.drag) finishItemDrag();
  if (!windowDrag) return;
  if (windowDrag.hasMoved) {
    const dockSlotId = inventoryState.isDockKeyHeld
      ? getDockSlotAtPoint(
          pointerEvent.clientX,
          pointerEvent.clientY,
          innerWidth,
          innerHeight,
        )
      : null;
    inventoryState.layouts[windowDrag.inventoryId].dock = dockSlotId;
    inventoryState.layouts[windowDrag.inventoryId].minimised = false;
    if (dockSlotId)
      inventoryState.activeTabs[dockSlotId] = windowDrag.inventoryId;
    saveLayout();
  }
  windowDrag = null;
  inventoryState.dockTarget = null;
  inventoryState.areDockSlotsVisible = false;
  publishChanges();
}

function handleKeyDown(keyboardEvent) {
  if (!inventoryState.isOpen) return;
  if (
    keyboardEvent.code === "KeyD" &&
    !inventoryState.dialog &&
    !["INPUT", "TEXTAREA"].includes(keyboardEvent.target.tagName) &&
    !keyboardEvent.target.isContentEditable
  ) {
    keyboardEvent.preventDefault();
    inventoryState.isDockKeyHeld = true;
    refreshDockingPreview();
    publishChanges();
    return;
  }
  if (inventoryState.dialog && keyboardEvent.key === "Tab") {
    keyboardEvent.preventDefault();
    const dialogControls = Array.from(
      document.querySelectorAll("#dialog input, #dialog button:not(:disabled)"),
    );
    const focusedControlIndex = dialogControls.indexOf(document.activeElement);
    const focusDirection = keyboardEvent.shiftKey ? -1 : 1;
    const nextControlIndex =
      (focusedControlIndex + focusDirection + dialogControls.length) %
      dialogControls.length;
    dialogControls[nextControlIndex]?.focus();
    return;
  }
  const drag = inventoryState.drag;
  if (drag && keyboardEvent.code === "KeyR" && !keyboardEvent.repeat) {
    keyboardEvent.preventDefault();
    const currentSize = getItemFootprint(getDraggedItem(), drag.isRotated);
    const previousOffsetX = drag.offsetX;
    const previousOffsetY = drag.offsetY;
    drag.offsetX = drag.isRotated
      ? previousOffsetY
      : currentSize.y - 1 - previousOffsetY;
    drag.offsetY = drag.isRotated
      ? currentSize.x - 1 - previousOffsetX
      : previousOffsetX;
    drag.isRotated = !drag.isRotated;
    refreshDragPreview();
    return;
  }
  if (drag && keyboardEvent.key === "Escape") {
    keyboardEvent.preventDefault();
    cancelItemDrag();
    return;
  }
  if (
    keyboardEvent.key === "Escape" ||
    (keyboardEvent.key === "Tab" && keyboardEvent.target.tagName !== "INPUT")
  ) {
    keyboardEvent.preventDefault();
    if (inventoryState.dialog) closeQuantityDialog();
    else closeInventoryUi();
  }
}

function handleKeyUp(keyboardEvent) {
  if (keyboardEvent.code !== "KeyD") return;
  inventoryState.isDockKeyHeld = false;
  refreshDockingPreview();
  publishChanges();
}

function handleServerMessage(messageEvent) {
  const message = messageEvent.data;
  if (!message || typeof message !== "object") return;
  if (message.type === "sync") {
    cancelItemDrag(false);
    const incomingInventoryIds = new Set(
      (message.inventories || []).map((inventory) => inventory.id),
    );
    for (const previousInventory of inventoryState.inventories) {
      if (
        previousInventory.type === "drop" &&
        !incomingInventoryIds.has(previousInventory.id)
      ) {
        delete inventoryState.layouts[previousInventory.id];
        for (const [dockSlotId, activeInventoryId] of Object.entries(
          inventoryState.activeTabs,
        )) {
          if (activeInventoryId === previousInventory.id)
            delete inventoryState.activeTabs[dockSlotId];
        }
      }
    }
    inventoryState.inventories = message.inventories || [];
    inventoryState.visibleMetadata = message.visibleMetadata || {};
    inventoryState.cellSize = message.cellSize || 48;
    inventoryState.isOpen = true;
    inventoryState.inventories.forEach(getInventoryLayout);
    if (
      inventoryState.dialog &&
      !findInventory(inventoryState.dialog.inventoryId)
    )
      inventoryState.dialog = null;
    clearPopups();
    publishChanges();
  } else if (message.type === "close") {
    inventoryState.isOpen = false;
    inventoryState.dialog = null;
    windowDrag = null;
    inventoryState.isDockKeyHeld = false;
    inventoryState.areDockSlotsVisible = false;
    inventoryState.dockTarget = null;
    clearPopups();
    cancelItemDrag();
  } else if (message.type === "notice") showNotice(message.message);
}

export function initialiseInventoryUi() {
  document.addEventListener("pointermove", handlePointerMove);
  document.addEventListener("pointerup", handlePointerUp);
  document.addEventListener("pointercancel", () => {
    dialogDrag = null;
    windowDrag = null;
    inventoryState.isDockKeyHeld = false;
    refreshDockingPreview();
    cancelItemDrag();
  });
  document.addEventListener("keydown", handleKeyDown);
  document.addEventListener("keyup", handleKeyUp);
  document.addEventListener("contextmenu", (pointerEvent) =>
    pointerEvent.preventDefault(),
  );
  document.addEventListener("pointerdown", (pointerEvent) => {
    if (
      !pointerEvent.target.closest("#context") &&
      inventoryState.contextMenu
    ) {
      inventoryState.contextMenu = null;
      publishChanges();
    }
  });
  window.addEventListener("message", handleServerMessage);
  window.addEventListener("blur", () => {
    dialogDrag = null;
    windowDrag = null;
    inventoryState.isDockKeyHeld = false;
    refreshDockingPreview();
    cancelItemDrag();
  });
  window.addEventListener("resize", () => {
    inventoryState.viewport = { width: innerWidth, height: innerHeight };
    refreshDockingPreview();
    if (inventoryState.dialog?.position) {
      const dialogBounds = document
        .getElementById("dialog")
        .getBoundingClientRect();
      lastDialogPosition = {
        x: Math.max(
          0,
          Math.min(innerWidth - dialogBounds.width, lastDialogPosition.x),
        ),
        y: Math.max(
          0,
          Math.min(innerHeight - dialogBounds.height, lastDialogPosition.y),
        ),
      };
      inventoryState.dialog = {
        ...inventoryState.dialog,
        position: lastDialogPosition,
      };
    }
    publishChanges();
  });

  if (isBrowserPreview && new URLSearchParams(location.search).has("preview")) {
    const radio = {
      id: 1,
      name: "radio",
      amount: 1,
      x: 1,
      y: 1,
      metadata: { durability: 100 },
      definition: {
        label: "Radio",
        description: "Handheld communication device.",
        size: { x: 1, y: 2 },
        weight: 100,
        image: "radio.png",
        useable: true,
      },
    };
    inventoryState.inventories = [
      {
        id: "preview:pockets",
        type: "player",
        label: "Player Inventory",
        size: { x: 8, y: 10 },
        revision: 1,
        weight: 100,
        items: [radio],
      },
      {
        id: "preview:backpack",
        type: "backpack",
        label: "Backpack",
        size: { x: 8, y: 8 },
        revision: 1,
        weight: 0,
        items: [],
      },
      {
        id: "preview:stash",
        type: "stash",
        label: "Business Stash",
        size: { x: 8, y: 6 },
        revision: 1,
        weight: 0,
        items: [],
      },
    ];
    inventoryState.visibleMetadata = { durability: "Durability" };
    inventoryState.inventories.forEach(getInventoryLayout);
    inventoryState.isOpen = true;
  }
}
