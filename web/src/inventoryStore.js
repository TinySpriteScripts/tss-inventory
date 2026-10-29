import { configureSounds, playInventorySound } from "./sounds.js";
import { planCraft } from "./crafting.js";
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
let nextItemBoxId = 0;
let dragAnimationFrame = null;
let pressedItem = null;
let windowDrag = null;
let weaponRotationDrag = null;
let weaponRotationRequests = Promise.resolve();
let attachmentDragFrame = null;
let pendingAttachmentDrag = null;
let lastAttachmentDragRequest = null;
let dialogDrag = null;
let hudDrag = null;
let lastDialogPosition = null;
let layoutSavePromise = Promise.resolve();
let layoutSaveVersion = 0;
let currentPlayerInventoryId = null;
const pendingLayoutIds = new Set();

export const inventoryState = {
  isOpen: false,
  inventories: [],
  nearbyPlayers: [],
  sounds: { enabled: false, volume: 0.2, actions: {} },
  visibleMetadata: {},
  rarity: { enable: false, tiers: {} },
  weaponSystemEnabled: false,
  equippedWeapon: null,
  clothingEnabled: false,
  clothing: null,
  clothingOpen: false,
  attachmentPanel: null,
  attachmentPreview: { status: "loading", anchors: {} },
  attachmentDrag: null,
  layouts: {},
  activeTabs: {},
  paymentMethods: {},
  activeShopId: null,
  baseCellSize: 48,
  cellSize: 48,
  frontOrder: 10,
  isRequestPending: false,
  pointer: { x: 0, y: 0 },
  viewport: { width: innerWidth, height: innerHeight },
  drag: null,
  crafting: null,
  craftingPending: false,
  destination: null,
  dockTarget: null,
  isDockKeyHeld: false,
  areDockSlotsVisible: false,
  tooltip: null,
  contextMenu: null,
  dialog: null,
  itemBoxes: [],
  playerSettings: { notificationPosition: "bottom-center" },
  settingsOpen: false,
  hudPositioning: false,
  settingsDraft: { notificationPosition: "bottom-center" },
  settingsSaving: false,
  lastTouchedInventoryId: null,
  keybindCapture: null,
  itemKeybinds: {},
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

function persistServerLayouts() {
  if (isBrowserPreview) return;
  const layouts = {};
  for (const inventory of inventoryState.inventories) {
    if (inventory.type === "drop" || inventory.id.startsWith("drop:")) continue;
    const layout = inventoryState.layouts[inventory.id];
    if (!layout) continue;
    layouts[inventory.id] = {
      x: Math.round(Math.max(0, Math.min(16384, layout.x))),
      y: Math.round(Math.max(0, Math.min(16384, layout.y))),
      dock: layout.dock || false,
      minimised: Boolean(layout.minimised),
      active: Boolean(
        layout.dock && inventoryState.activeTabs[layout.dock] === inventory.id,
      ),
    };
    pendingLayoutIds.add(inventory.id);
  }
  if (!Object.keys(layouts).length) return;
  const saveVersion = ++layoutSaveVersion;
  layoutSavePromise = layoutSavePromise.then(async () => {
    const response = await sendNuiRequest("action", {
      kind: "layout",
      layouts,
    });
    if (saveVersion === layoutSaveVersion) pendingLayoutIds.clear();
    if (!response.ok)
      showNotice(response.message || "Window layout could not be saved");
  });
  return layoutSavePromise;
}

function saveLayout() {
  void persistServerLayouts();
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
  ) || (inventoryState.clothing?.inventory?.id === inventoryId ? inventoryState.clothing.inventory : undefined);
}

export function toggleClothingPanel() {
  if (!inventoryState.clothingEnabled || inventoryState.crafting || inventoryState.craftingPending) return;
  inventoryState.clothingOpen = !inventoryState.clothingOpen;
  const playerInventory = inventoryState.inventories.find((inventory) => inventory.isOwn === true);
  if (inventoryState.clothingOpen && playerInventory) void requestItemAction(playerInventory, null, "openClothing");
  publishChanges();
}

export function unequipClothing(slotId) {
  const playerInventory = findInventory(inventoryState.clothing?.playerInventoryId);
  if (playerInventory) void requestItemAction(playerInventory, null, "unequipClothing", {
    slot: slotId, clothingRevision: inventoryState.clothing?.inventory?.revision,
  });
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
    const windowWidth = Math.min(
      Math.max(220, inventory.size.x * inventoryState.cellSize + 16),
      innerWidth - 24,
    );
    const windowHeight = Math.min(
      inventory.size.y * inventoryState.cellSize + 60,
      innerHeight - 32,
    );
    const defaultX =
      inventory.type === "shop"
        ? innerWidth - windowWidth - 60
        : 60 + inventoryIndex * 350;
    const defaultY = 90 + inventoryIndex * 45;
    inventoryState.layouts[inventory.id] = {
      x: Math.max(12, Math.min(defaultX, innerWidth - windowWidth - 12)),
      y: Math.max(12, Math.min(defaultY, innerHeight - windowHeight - 12)),
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
  if (typeof message === "string" && message.length) void sendNuiRequest("notify", { message });
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
  inventoryState.keybindCapture = null;
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
  if (inventoryState.isRequestPending || inventoryState.crafting || inventoryState.craftingPending) return;
  if (actionKind === "drop" && inventoryState.playerSettings.confirmDropping && !details.confirmed) {
    clearPopups();
    inventoryState.dialog = { kind: "confirmDrop", inventoryId: inventory.id, itemId: item.id,
      quantity: String(details.amount ?? item.amount), details, position: lastDialogPosition };
    publishChanges();
    return;
  }
  const { confirmed, ...actionDetails } = details;
  inventoryState.isRequestPending = true;
  if (actionKind === "craft") inventoryState.craftingPending = true;
  clearPopups();
  publishChanges();

  try {
    const response = await sendNuiRequest("action", {
      kind: actionKind,
      from: inventory.id,
      revision: inventory.revision,
      itemId: item?.id,
      ...actionDetails,
    });
    if (!response.ok) {
      playInventorySound("reject");
      showNotice(response.message || "Action refused");
    } else {
      if (["move", "quickMove", "storeInContainer", "repack"].includes(actionKind)) playInventorySound("move");
      else if (actionKind === "buy" || actionKind === "sell") playInventorySound("purchase");
      else if (["equipClothing", "unequipClothing", "installAttachment", "removeAttachment"].includes(actionKind)
        || actionKind === "use" && (item?.definition.weapon || item?.definition.clothingSlot)) playInventorySound("equip");
      if ((actionKind === "buy" || actionKind === "sell") && response.message) showNotice(response.message);
    }
  } finally {
    inventoryState.isRequestPending = false;
    if (actionKind === "craft") inventoryState.craftingPending = false;
    publishChanges();
  }
}

let givingPreviewRequests = Promise.resolve();

export function canGiveFromInventory(inventory) {
  return Boolean(inventory && ((inventory.type === "player" && inventory.isOwn !== false)
    || inventory.isPlayerExtra || inventory.metadata?.containerItem));
}

function setGivingPreview(active) {
  if (!active) inventoryState.nearbyPlayers = [];
  givingPreviewRequests = givingPreviewRequests.catch(() => {}).then(() => sendNuiRequest("givingPreview", { active }));
}

export function getSellOffer(inventory, item, shopId = inventoryState.activeShopId) {
  if (!canGiveFromInventory(inventory) || !item) return null;
  const shop = shopId ? findInventory(shopId) : inventoryState.inventories.find((candidate) => candidate.type === "shop");
  const product = shop?.items.find((candidate) => candidate.name === item.name && candidate.canSell && Number.isFinite(candidate.sellPrice));
  return product ? { shop, product } : null;
}

export function sellItem(inventory, item, amount = Math.min(item.amount, 1000), shopId) {
  const offer = getSellOffer(inventory, item, shopId);
  if (!offer) return showNotice("This shop does not buy that item");
  return requestItemAction(inventory, item, "sell", { to: offer.shop.id, targetRevision: offer.shop.revision,
    amount, account: getPaymentMethod(offer.shop) });
}

export function openSaleDialog(inventory, item) {
  const offer = getSellOffer(inventory, item);
  if (!offer) return;
  openQuantityDialog(inventory, item, false, "sale");
  inventoryState.dialog.shopId = offer.shop.id;
  publishChanges();
}

export function giveItemToClosest(inventory, item) {
  return requestItemAction(inventory, item, "give", { amount: item.amount });
}

export function repackInventory(inventory) {
  return requestItemAction(inventory, null, "repack");
}

export function openWeaponAttachments(inventory, item) {
  return requestItemAction(inventory, item, "openAttachments");
}

export function closeWeaponAttachments() {
  stopAttachmentDrag();
  inventoryState.attachmentPanel = null;
  inventoryState.attachmentPreview = { status: "loading", anchors: {} };
  stopWeaponRotation();
  void sendNuiRequest("closeWeaponPreview");
  publishChanges();
  void sendNuiRequest("action", { kind: "closeAttachments" });
}

export function removeWeaponAttachment(slot) {
  const panel = inventoryState.attachmentPanel;
  if (!panel) return;
  const inventory = findInventory(panel.inventoryId) || { id: panel.inventoryId, revision: panel.revision };
  return requestItemAction(inventory, panel.weapon, "removeAttachment", {
    weaponInventoryId: panel.inventoryId, weaponItemId: panel.itemId,
    weaponRevision: panel.revision, slot,
  });
}

export function openInstalledAttachmentMenu(slot, pointerEvent) {
  pointerEvent.preventDefault();
  pointerEvent.stopPropagation();
  const panel = inventoryState.attachmentPanel;
  if (!panel || !slot.installed || inventoryState.drag) return;
  clearPopups();
  inventoryState.contextMenu = {
    x: pointerEvent.clientX, y: pointerEvent.clientY,
    inventory: findInventory(panel.inventoryId) || { id: panel.inventoryId },
    item: slot.installed, attachmentSlot: slot.id,
  };
  publishChanges();
}

function stopAttachmentDrag() {
  if (attachmentDragFrame !== null) cancelAnimationFrame(attachmentDragFrame);
  attachmentDragFrame = null;
  pendingAttachmentDrag = null;
  lastAttachmentDragRequest = null;
  if (inventoryState.attachmentDrag) void sendNuiRequest("weaponPreviewDrag", { active: false });
  inventoryState.attachmentDrag = null;
}

function updateAttachmentDrag() {
  const panel = inventoryState.attachmentPanel;
  const destination = inventoryState.destination;
  const item = getDraggedItem();
  if (!panel || !item || !destination?.isWeaponInspection || !destination.attachmentSlot) {
    stopAttachmentDrag();
    return;
  }
  const previous = inventoryState.attachmentDrag;
  inventoryState.attachmentDrag = { name: item.name, ready: previous?.name === item.name && previous.ready };
  const request = {
    active: true, inventoryId: panel.inventoryId, itemId: panel.itemId, attachmentName: item.name,
    pointerX: inventoryState.pointer.x / innerWidth, pointerY: inventoryState.pointer.y / innerHeight,
  };
  const previousRequest = pendingAttachmentDrag || lastAttachmentDragRequest;
  if (previousRequest && Object.keys(request).every((key) => request[key] === previousRequest[key])) return;
  pendingAttachmentDrag = request;
  if (attachmentDragFrame !== null) return;
  attachmentDragFrame = requestAnimationFrame(() => {
    attachmentDragFrame = null;
    const pending = pendingAttachmentDrag;
    pendingAttachmentDrag = null;
    if (!pending || !inventoryState.attachmentDrag) return;
    lastAttachmentDragRequest = pending;
    void sendNuiRequest("weaponPreviewDrag", pending);
  });
}

function requestWeaponRotation(request) {
  weaponRotationRequests = weaponRotationRequests.catch(() => {}).then(() => sendNuiRequest("rotateWeaponPreview", request));
}

export function startWeaponRotation(pointerEvent) {
  const panel = inventoryState.attachmentPanel;
  if (pointerEvent.button !== 0 || inventoryState.drag || !panel) return;
  pointerEvent.preventDefault();
  hideItemTooltip();
  weaponRotationDrag = { inventoryId: panel.inventoryId, itemId: panel.itemId,
    x: pointerEvent.clientX, y: pointerEvent.clientY };
  requestWeaponRotation({
    active: true, inventoryId: panel.inventoryId, itemId: panel.itemId,
    pointerX: pointerEvent.clientX, pointerY: pointerEvent.clientY,
    viewportWidth: innerWidth, viewportHeight: innerHeight,
  });
}

function stopWeaponRotation(pointerEvent) {
  const rotation = weaponRotationDrag;
  weaponRotationDrag = null;
  if (!rotation) return;
  requestWeaponRotation({
    active: false, inventoryId: rotation.inventoryId, itemId: rotation.itemId,
    pointerX: pointerEvent?.clientX ?? rotation.x, pointerY: pointerEvent?.clientY ?? rotation.y,
  });
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
  if (inventoryState.crafting || inventoryState.craftingPending) { pointerEvent.preventDefault(); return; }
  pointerEvent.preventDefault();
  pointerEvent.stopPropagation();
  touchInventory(inventory);
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
  if (isPurchase && item.canBuy === false) return;
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
      : dialog.kind === "sale" ? Math.min(1000, item.amount) : item.amount;

  if (!Number.isInteger(quantity) || quantity < 1 || quantity > maximum)
    return showNotice("Enter a valid quantity");
  closeQuantityDialog();

  if (dialog.kind === "sale") {
    sellItem(inventory, item, quantity, dialog.shopId);
    return;
  }

  if (dialog.kind === "drop" || dialog.kind === "confirmDrop") {
    requestItemAction(inventory, item, "drop", { ...dialog.details, amount: quantity, confirmed: true });
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

export function touchInventory(inventory) {
  if (inventory.type === "shop") { inventoryState.activeShopId = inventory.id; publishChanges(); }
  if (!(inventory.type === "player" && inventory.isOwn !== false))
    inventoryState.lastTouchedInventoryId = inventory.id;
}

export function getItemBinding(itemName) {
  return Object.entries(inventoryState.itemKeybinds).find(
    ([, binding]) => binding.itemName === itemName,
  )?.[1];
}

export function captureItemKey(inventory, item) {
  inventoryState.keybindCapture = {
    inventoryId: inventory.id,
    itemId: item.id,
  };
  publishChanges();
}

export function unbindItemKey(inventory, item) {
  return requestItemAction(inventory, item, "unbindKey");
}

async function quickTransferItem(inventory, item, half) {
  const ownInventory = inventoryState.inventories.find(
    (candidate) => candidate.type === "player" && candidate.isOwn !== false,
  );
  const destination =
    inventory.id === ownInventory?.id
      ? findInventory(inventoryState.lastTouchedInventoryId)
      : ownInventory;
  if (!destination || destination.id === inventory.id)
    return showNotice("Click the destination inventory first");
  if (half && item.amount < 2) return showNotice("Stack cannot be split");
  if (destination.type === "shop" || inventory.type === "shop")
    return showNotice("Shop items must be purchased");
  await requestItemAction(inventory, item, "quickMove", {
    to: destination.id,
    targetRevision: destination.revision,
    half,
  });
}

export function pressInventoryItem(inventory, item, pointerEvent) {
  if (inventoryState.crafting || inventoryState.craftingPending) return;
  if (
    pointerEvent.button !== 0 ||
    inventoryState.drag ||
    inventoryState.isRequestPending
  )
    return;
  pointerEvent.preventDefault();
  if (pointerEvent.ctrlKey || pointerEvent.shiftKey) {
    pointerEvent.stopPropagation();
    pressedItem = null;
    void quickTransferItem(inventory, item, pointerEvent.ctrlKey);
    return;
  }
  const itemBounds = pointerEvent.currentTarget.getBoundingClientRect();
  const itemSize = getItemFootprint(item);
  inventoryState.pointer = { x: pointerEvent.clientX, y: pointerEvent.clientY };
  pressedItem = {
    inventory,
    item,
    pointerX: pointerEvent.clientX,
    pointerY: pointerEvent.clientY,
    offsetX: Math.min(itemSize.x - 1, Math.floor(
      (pointerEvent.clientX - itemBounds.left) / inventoryState.cellSize,
    )),
    offsetY: Math.min(itemSize.y - 1, Math.floor(
      (pointerEvent.clientY - itemBounds.top) / inventoryState.cellSize,
    )),
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
  const pointerElement = document.elementFromPoint(pointer.x, pointer.y);
  const isOpenSpace = pointerElement?.closest("#inventory")
    && !pointerElement.closest(".window, .weapon-inspection, #dialog, #context, footer");
  if (drag && isOpenSpace && canGiveFromInventory(findInventory(drag.inventoryId))) {
    let closestTarget = null;
    let closestDistance = 32;
    for (const target of inventoryState.nearbyPlayers) {
      const distance = Math.hypot(pointer.x - target.x * innerWidth, pointer.y - target.y * innerHeight);
      if (distance <= closestDistance) {
        closestTarget = target;
        closestDistance = distance;
      }
    }
    if (closestTarget) return { giveTarget: closestTarget.id, isValid: true };
  }
  const clothingElement = pointerElement?.closest("[data-clothing-slot]");
  if (clothingElement && inventoryState.clothingEnabled && inventoryState.clothing?.inventory) {
    const item = getDraggedItem();
    const slotId = clothingElement.dataset.clothingSlot;
    const bounds = clothingElement.getBoundingClientRect();
    const isValid = item?.definition.clothingSlot === slotId && item?.metadata?.clothing?.gender === inventoryState.clothing.gender;
    return { inventoryId: inventoryState.clothing.inventory.id, clothingSlot: slotId, isValid,
      reason: "Clothing does not fit this slot or character", screenX: bounds.left, screenY: bounds.top,
      ghostWidth: bounds.width, ghostHeight: bounds.height };
  }
  if (pointerElement?.closest(".weapon-inspection") && inventoryState.attachmentPanel) {
    const panel = inventoryState.attachmentPanel;
    const draggedItem = getDraggedItem();
    const slot = panel.slots.find((candidate) => candidate.compatibleItems.includes(draggedItem?.name));
    const anchor = slot && inventoryState.attachmentPreview.anchors[slot.id];
    const distance = anchor ? Math.hypot(pointer.x - anchor.x * innerWidth, pointer.y - anchor.y * innerHeight) : Infinity;
    return { inventoryId: "weapon-attachments", isWeaponInspection: true, panel,
      attachmentSlot: slot?.id, isValid: distance <= 38 && inventoryState.attachmentPreview.status === "ready" };
  }
  const gridElement = document
    .elementFromPoint(pointer.x, pointer.y)
    ?.closest(".grid");
  const inventory = gridElement && findInventory(gridElement.dataset.inventory);
  const item = getDraggedItem();
  if (!drag || !inventory || !item) return null;

  const gridBounds = gridElement.getBoundingClientRect();
  if (inventory.type === "shop") {
    const offer = getSellOffer(findInventory(drag.inventoryId), item, inventory.id);
    const product = offer?.product;
    const footprint = product ? getItemFootprint(product) : { x: 1, y: 1 };
    const column = product?.x || 1;
    const row = product?.y || 1;
    return { inventoryId: inventory.id, isSale: true, isValid: Boolean(offer && drag.quantity <= 1000),
      reason: offer ? "Sell up to 1000 items at a time" : "This shop does not buy that item",
      highlight: { x: column, y: row, width: footprint.x, height: footprint.y },
      screenX: gridBounds.left + (column - 1) * inventoryState.cellSize,
      screenY: gridBounds.top + (row - 1) * inventoryState.cellSize };
  }
  const column =
    Math.floor((pointer.x - gridBounds.left) / inventoryState.cellSize) +
    1 -
    drag.offsetX;
  const row =
    Math.floor((pointer.y - gridBounds.top) / inventoryState.cellSize) +
    1 -
    drag.offsetY;
  const hoveredColumn = Math.floor((pointer.x - gridBounds.left) / inventoryState.cellSize) + 1;
  const hoveredRow = Math.floor((pointer.y - gridBounds.top) / inventoryState.cellSize) + 1;
  const hoveredItem = inventory.items.find((candidate) => {
    const footprint = getItemFootprint(candidate);
    return (inventory.id !== drag.inventoryId || candidate.id !== item.id) && hoveredColumn >= candidate.x && hoveredColumn < candidate.x + footprint.x &&
      hoveredRow >= candidate.y && hoveredRow < candidate.y + footprint.y;
  });
  if (hoveredItem?.definition.container && inventory.type !== "shop" && findInventory(drag.inventoryId)?.type !== "shop") {
    const rules = hoveredItem.definition.containerRules || {};
    const canCarry = inventory.isOwn || inventory.isPlayerExtra || Boolean(inventory.metadata?.containerItem);
    const isAllowed = (!rules.whitelist?.length || rules.whitelist.includes(item.name)) && !rules.blacklist?.includes(item.name);
    const targetSize = getItemFootprint(hoveredItem);
    return { inventoryId: inventory.id, containerItemId: hoveredItem.id,
      isValid: Boolean(canCarry && isAllowed && hoveredItem.metadata?.containerId !== drag.inventoryId),
      reason: "Item cannot be stored in this container",
      highlight: { x: hoveredItem.x, y: hoveredItem.y, width: targetSize.x, height: targetSize.y },
      screenX: gridBounds.left + (hoveredItem.x - 1) * inventoryState.cellSize,
      screenY: gridBounds.top + (hoveredItem.y - 1) * inventoryState.cellSize,
      ghostWidth: targetSize.x * inventoryState.cellSize, ghostHeight: targetSize.y * inventoryState.cellSize };
  }
  const craft = inventory.id === drag.inventoryId && hoveredItem && planCraft(inventory, item, hoveredItem);
  if (craft) return {
    inventoryId: inventory.id, column: craft.item.x, row: craft.item.y, isValid: true, craft,
    highlight: { x: craft.item.x, y: craft.item.y, width: craft.item.definition.size.x, height: craft.item.definition.size.y },
    screenX: gridBounds.left + (craft.item.x - 1) * inventoryState.cellSize,
    screenY: gridBounds.top + (craft.item.y - 1) * inventoryState.cellSize,
  };
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
    !inventory.dynamicContainerWeight &&
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
  updateAttachmentDrag();
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
  if (inventory.type === "shop" && item.canBuy === false) return showNotice("This shop only buys that item");
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
  setGivingPreview(canGiveFromInventory(inventory));
  refreshDragPreview();
  dragAnimationFrame = requestAnimationFrame(scrollDuringDrag);
}

export function cancelItemDrag(shouldPublish = true) {
  if (inventoryState.drag) setGivingPreview(false);
  stopAttachmentDrag();
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
      !pointerElement.closest(".window, .weapon-inspection, #dialog, #context, footer");
    if (
      isWorldBackground &&
      ((sourceInventory.type === "player" && sourceInventory.isOwn !== false) ||
        sourceInventory.isPlayerExtra === true)
    ) {
      requestItemAction(sourceInventory, item, "drop", {
        amount: drag.quantity,
        rotated: drag.isRotated,
      });
    }
    return;
  }
  if (destination.isWeaponInspection && !destination.isValid) {
    playInventorySound("reject");
    return;
  }
  if (!destination.isValid) {
    playInventorySound("reject");
    return showNotice(destination.reason);
  }
  if (destination.isSale) {
    void sellItem(sourceInventory, item, drag.quantity, destination.inventoryId);
    return;
  }
  if (destination.giveTarget) {
    void requestItemAction(sourceInventory, item, "give", { targetPlayer: destination.giveTarget, amount: drag.quantity });
    return;
  }
  if (destination.clothingSlot) {
    void requestItemAction(sourceInventory, item, "equipClothing", {
      slot: destination.clothingSlot, clothingRevision: inventoryState.clothing?.inventory?.revision,
    });
    return;
  }
  if (destination.attachmentSlot) {
    const panel = destination.panel;
    void requestItemAction(sourceInventory, item, "installAttachment", {
      weaponInventoryId: panel.inventoryId, weaponItemId: panel.itemId,
      weaponRevision: panel.revision, slot: destination.attachmentSlot,
    });
    return;
  }
  if (destination.containerItemId) {
    const carrier = findInventory(destination.inventoryId);
    if (carrier) void requestItemAction(sourceInventory, item, "storeInContainer", {
      amount: drag.quantity, containerInventoryId: carrier.id, containerRevision: carrier.revision,
      containerItemId: destination.containerItemId,
    });
    return;
  }
  const targetInventory = findInventory(destination.inventoryId);
  if (destination.craft) {
    void requestItemAction(sourceInventory, item, "craft", {
      recipe: destination.craft.recipe, targetItemId: destination.craft.targetItemId,
    });
    return;
  }

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
  touchInventory(inventory);
  getInventoryLayout(inventory).frontOrder = ++inventoryState.frontOrder;
  publishChanges();
}

export function undockInventory(inventory) {
  Object.assign(getInventoryLayout(inventory), {
    dock: null,
    x: 100,
    y: 100,
  });
  saveLayout();
  publishChanges();
}

export function selectInventoryTab(dockSlotId, inventoryId) {
  const inventory = findInventory(inventoryId);
  if (inventory) touchInventory(inventory);
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

export function getHudPositionStyle(position, width, height) {
  return { left: 8 + position.x * Math.max(0, innerWidth - width - 16),
    top: 8 + position.y * Math.max(0, innerHeight - height - 16), right: "auto", bottom: "auto", transform: "none" };
}

export function setHudPositioning(enabled) {
  inventoryState.hudPositioning = enabled === true;
  hudDrag = null;
  publishChanges();
}

export function startHudDrag(key, pointerEvent) {
  if (!inventoryState.settingsOpen || !inventoryState.hudPositioning || inventoryState.settingsSaving || pointerEvent.button !== 0) return;
  pointerEvent.preventDefault();
  pointerEvent.stopPropagation();
  const bounds = pointerEvent.currentTarget.getBoundingClientRect();
  hudDrag = { key, offsetX: pointerEvent.clientX - bounds.left, offsetY: pointerEvent.clientY - bounds.top,
    width: bounds.width, height: bounds.height };
  pointerEvent.currentTarget.setPointerCapture(pointerEvent.pointerId);
}

export function resetHudPositions() {
  inventoryState.settingsDraft.weaponHudPosition = false;
  inventoryState.settingsDraft.itemBoxPosition = false;
  inventoryState.settingsDraft.notificationPosition = "bottom-center";
  publishChanges();
}

export function getInterfaceScale() {
  const settings = inventoryState.settingsOpen ? inventoryState.settingsDraft : inventoryState.playerSettings;
  return { small: 1, medium: 1.125, large: 1.25 }[settings.uiScale] || 1;
}

function applyInterfaceScale() {
  inventoryState.cellSize = inventoryState.baseCellSize * getInterfaceScale();
}

export function setInventoryPreference(key, value) {
  if (["weaponDisplay", "itemNotifications", "confirmDropping", "rememberContainers"].includes(key) && typeof value === "boolean") {
    inventoryState.settingsDraft[key] = value;
  } else if (key === "notificationDuration" && Number.isInteger(value) && value >= 1000 && value <= 10000) {
    inventoryState.settingsDraft[key] = value;
  } else if (key === "uiScale" && ["small", "medium", "large"].includes(value)) {
    inventoryState.settingsDraft.uiScale = value;
  }
  applyInterfaceScale();
  publishChanges();
}

export function setSoundPreference(key, value) {
  if (key === "soundMuted" && typeof value === "boolean") inventoryState.settingsDraft.soundMuted = value;
  else if (key === "soundVolume" && Number.isFinite(value)) inventoryState.settingsDraft.soundVolume = Math.max(0, Math.min(1, value));
  publishChanges();
}

export function previewInventorySound() {
  playInventorySound("move", inventoryState.settingsDraft);
}

export async function closeInventorySettings() {
  if (inventoryState.settingsSaving) return;
  inventoryState.settingsOpen = false;
  applyInterfaceScale();
  inventoryState.hudPositioning = false;
  hudDrag = null;
  publishChanges();
  await sendNuiRequest("settingsClosed", {
    inventoryOpen: inventoryState.isOpen,
  });
}

export async function saveInventorySettings() {
  if (inventoryState.settingsSaving) return;
  inventoryState.settingsSaving = true;
  publishChanges();
  const response = await sendNuiRequest("action", {
    kind: "preferences",
    settings: inventoryState.settingsDraft,
  });
  inventoryState.settingsSaving = false;
  if (!response.ok) {
    showNotice(response.message || "Settings could not be saved");
    publishChanges();
    return;
  }
  inventoryState.playerSettings = {
    ...inventoryState.playerSettings,
    ...inventoryState.settingsDraft,
  };
  configureSounds(inventoryState.sounds, inventoryState.playerSettings);
  await closeInventorySettings();
}

export async function resetInventoryLayout() {
  await layoutSavePromise;
  const response = await sendNuiRequest("action", { kind: "resetWindows" });
  if (!response.ok)
    showNotice(response.message || "Window positions could not be reset");
  else showNotice("Window positions reset");
}

function applyWindowReset() {
  stopWeaponRotation();

  inventoryState.layouts = {};
  inventoryState.activeTabs = {};
  pendingLayoutIds.clear();
  layoutSaveVersion += 1;
  windowDrag = null;
  inventoryState.isDockKeyHeld = false;
  inventoryState.areDockSlotsVisible = false;
  inventoryState.dockTarget = null;
  try {
    localStorage.removeItem("tss-layout-v1");
  } catch {
    /* Server settings remain authoritative. */
  }
  inventoryState.inventories.forEach(getInventoryLayout);
  publishChanges();
}

export async function closeInventoryWindow(inventory) {
  if (inventoryState.crafting || inventoryState.craftingPending) return;
  await layoutSavePromise;
  inventoryState.inventories = inventoryState.inventories.filter(
    (candidate) => candidate.id !== inventory.id,
  );
  publishChanges();
  await sendNuiRequest("closeInventory", { id: inventory.id });
  if (!inventoryState.inventories.length) closeInventoryUi();
}

export async function closeInventoryUi() {
  if (inventoryState.crafting || inventoryState.craftingPending) return;
  await layoutSavePromise;
  inventoryState.isOpen = false;
  inventoryState.attachmentPanel = null;
  stopWeaponRotation();
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
  if (hudDrag) {
    const width = Math.max(1, innerWidth - hudDrag.width - 16);
    const height = Math.max(1, innerHeight - hudDrag.height - 16);
    inventoryState.settingsDraft[hudDrag.key] = {
      x: Math.max(0, Math.min(1, (pointerEvent.clientX - hudDrag.offsetX - 8) / width)),
      y: Math.max(0, Math.min(1, (pointerEvent.clientY - hudDrag.offsetY - 8) / height)),
    };
    publishChanges();
    return;
  }
  if (weaponRotationDrag) {
    weaponRotationDrag.x = pointerEvent.clientX;
    weaponRotationDrag.y = pointerEvent.clientY;
    return;
  }
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
  if (hudDrag && pointerEvent.button === 0) { hudDrag = null; return; }
  if (weaponRotationDrag && pointerEvent.button === 0) { stopWeaponRotation(pointerEvent); return; }
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
  if (inventoryState.crafting || inventoryState.craftingPending) {
    keyboardEvent.preventDefault();
    keyboardEvent.stopImmediatePropagation();
    if (keyboardEvent.key === "Escape" && !keyboardEvent.repeat) {
      void sendNuiRequest("action", { kind: "cancelCraft" });
    }
    return;
  }
  if (inventoryState.keybindCapture) {
    keyboardEvent.preventDefault();
    keyboardEvent.stopImmediatePropagation();
    if (keyboardEvent.repeat) return;
    if (keyboardEvent.key === "Escape") {
      inventoryState.keybindCapture = null;
      publishChanges();
      return;
    }
    const capture = inventoryState.keybindCapture;
    const inventory = findInventory(capture.inventoryId);
    const item = inventory?.items.find(
      (candidate) => candidate.id === capture.itemId,
    );
    if (inventory && item)
      void requestItemAction(inventory, item, "bindKey", {
        keyCode: keyboardEvent.keyCode,
        keyLabel: keyboardEvent.key === " " ? "Space" : keyboardEvent.key,
      });
    return;
  }
  if (inventoryState.settingsOpen) {
    if (keyboardEvent.key === "Escape") {
      keyboardEvent.preventDefault();
      void closeInventorySettings();
    } else if (keyboardEvent.key === "Tab") {
      keyboardEvent.preventDefault();
      const controls = Array.from(
        document.querySelectorAll(
          "#inventory-settings button:not(:disabled), #inventory-settings select:not(:disabled), #inventory-settings input:not(:disabled), .hud-position-toolbar button",
        ),
      );
      const focusedIndex = controls.indexOf(document.activeElement);
      const direction = keyboardEvent.shiftKey ? -1 : 1;
      controls[
        (focusedIndex + direction + controls.length) % controls.length
      ]?.focus();
    }
    return;
  }
  if (!inventoryState.isOpen) return;
  if (
    !keyboardEvent.repeat &&
    keyboardEvent.key !== "Escape" &&
    !inventoryState.dialog &&
    !inventoryState.drag &&
    !windowDrag &&
    !["INPUT", "TEXTAREA", "SELECT"].includes(keyboardEvent.target.tagName) &&
    !keyboardEvent.target.isContentEditable &&
    inventoryState.itemKeybinds[String(keyboardEvent.keyCode)]
  ) {
    keyboardEvent.preventDefault();
    void sendNuiRequest("useItemKey", { keyCode: keyboardEvent.keyCode });
    return;
  }
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
  if (keyboardEvent.key === "Escape" && inventoryState.attachmentPanel && !inventoryState.drag && !inventoryState.dialog) {
    keyboardEvent.preventDefault();
    closeWeaponAttachments();
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
  if (message.sounds) inventoryState.sounds = message.sounds;
  if (message.type === "equippedWeapon") {
    inventoryState.equippedWeapon = message.weapon || null;
    publishChanges();
  } else if (message.type === "nearbyPlayers") {
    inventoryState.nearbyPlayers = inventoryState.drag && canGiveFromInventory(findInventory(inventoryState.drag.inventoryId))
      ? (message.players || []) : [];
    if (inventoryState.drag) inventoryState.destination = calculateDestination();
    publishChanges();
  } else if (message.type === "clothing") {
    inventoryState.clothing = message.state || null;
    if (!message.state) inventoryState.clothingOpen = false;
    publishChanges();
  } else if (message.type === "attachments") {
    const previousPanel = inventoryState.attachmentPanel;
    inventoryState.attachmentPanel = message.panel || null;
    if (!message.panel || previousPanel?.inventoryId !== message.panel.inventoryId || previousPanel?.itemId !== message.panel.itemId) {
      inventoryState.attachmentPreview = { status: "loading", anchors: {} };
      stopWeaponRotation();
    }
    publishChanges();
  } else if (message.type === "weaponDragModel") {
    const panel = inventoryState.attachmentPanel;
    const drag = inventoryState.attachmentDrag;
    if (!panel || panel.inventoryId !== message.inventoryId || panel.itemId !== message.itemId ||
        !drag || drag.name !== message.attachmentName) return;
    inventoryState.attachmentDrag = { ...drag, ready: message.ready === true };
    publishChanges();
  } else if (message.type === "weaponPreview") {
    const panel = inventoryState.attachmentPanel;
    if (!panel || panel.inventoryId !== message.inventoryId || panel.itemId !== message.itemId) return;
    inventoryState.attachmentPreview = { ...inventoryState.attachmentPreview,
      status: message.status, message: message.message,
      anchors: message.anchors || inventoryState.attachmentPreview.anchors };
    publishChanges();
  } else if (message.type === "crafting") {
    inventoryState.crafting = message.craft || null;
    inventoryState.craftingPending = false;
    clearPopups();
    cancelItemDrag(false);
    publishChanges();
  } else if (message.type === "itemKeybinds") {
    inventoryState.itemKeybinds = message.bindings || {};
    publishChanges();
  } else if (message.type === "openSettings") {
    inventoryState.playerSettings = {
      notificationPosition: "bottom-center",
      ...message.settings,
    };
    configureSounds(inventoryState.sounds, inventoryState.playerSettings);
    inventoryState.settingsDraft = { ...inventoryState.playerSettings };
    inventoryState.settingsOpen = true;
    applyInterfaceScale();
    inventoryState.hudPositioning = false;
    clearPopups();
    cancelItemDrag(false);
    publishChanges();
  } else if (message.type === "preferences") {
    inventoryState.playerSettings = {
      notificationPosition: "bottom-center",
      ...message.settings,
    };
    applyInterfaceScale();
    publishChanges();
    configureSounds(inventoryState.sounds, inventoryState.playerSettings);
  } else if (message.type === "resetLayouts") {
    applyWindowReset();
  } else if (message.type === "itemBox") {
    if (inventoryState.playerSettings.itemNotifications === false) return;
    if (!message.definition || !["added", "removed"].includes(message.action))
      return;
    const notificationId = ++nextItemBoxId;
    inventoryState.itemBoxes = [
      ...inventoryState.itemBoxes.slice(-2),
      {
        id: notificationId,
        definition: message.definition,
        action: message.action,
        amount: message.amount || 1,
      },
    ];
    publishChanges();
    setTimeout(() => {
      inventoryState.itemBoxes = inventoryState.itemBoxes.filter(
        (notification) => notification.id !== notificationId,
      );
      publishChanges();
    }, inventoryState.playerSettings.notificationDuration ?? 2500);
  } else if (message.type === "sync") {
    const ownInventory = message.inventories?.find(
      (inventory) => inventory.isOwn === true,
    );
    if (ownInventory && currentPlayerInventoryId !== ownInventory.id) {
      currentPlayerInventoryId = ownInventory.id;
      inventoryState.layouts = {};
      inventoryState.activeTabs = {};
      inventoryState.lastTouchedInventoryId = null;
      inventoryState.itemKeybinds = {};
      pendingLayoutIds.clear();
      layoutSaveVersion += 1;
    }
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
    for (const inventory of message.inventories || []) {
      if (
        inventory.layoutSettings === undefined ||
        pendingLayoutIds.has(inventory.id) ||
        windowDrag?.inventoryId === inventory.id
      )
        continue;
      if (inventory.layoutSettings === false)
        delete inventoryState.layouts[inventory.id];
      else
        inventoryState.layouts[inventory.id] = {
          ...inventory.layoutSettings,
          dock: inventory.layoutSettings.dock || null,
          frontOrder:
            inventoryState.layouts[inventory.id]?.frontOrder ||
            ++inventoryState.frontOrder,
        };
    }
    for (const inventory of message.inventories || []) {
      if (
        inventory.layoutSettings?.active &&
        inventory.layoutSettings.dock &&
        !pendingLayoutIds.has(inventory.id)
      ) {
        inventoryState.activeTabs[inventory.layoutSettings.dock] = inventory.id;
      }
    }
    if (ownInventory?.itemKeybinds)
      inventoryState.itemKeybinds = ownInventory.itemKeybinds;
    if (ownInventory?.playerSettings)
      inventoryState.playerSettings = { ...ownInventory.playerSettings };
    configureSounds(inventoryState.sounds, inventoryState.playerSettings);
    const newlyOpenedShop = (message.inventories || []).find((inventory) => inventory.type === "shop"
      && !inventoryState.inventories.some((previous) => previous.id === inventory.id));
    if (newlyOpenedShop) inventoryState.activeShopId = newlyOpenedShop.id;
    inventoryState.inventories = message.inventories || [];
    if (!inventoryState.inventories.some((inventory) => inventory.id === inventoryState.activeShopId && inventory.type === "shop")) {
      inventoryState.activeShopId = inventoryState.inventories.find((inventory) => inventory.type === "shop")?.id || null;
    }
    inventoryState.visibleMetadata = message.visibleMetadata || {};
    inventoryState.rarity = message.rarity || { enable: false, tiers: {} };
    inventoryState.weaponSystemEnabled = message.weaponSystemEnabled === true;
    inventoryState.clothingEnabled = message.clothingEnabled === true;
    inventoryState.clothing = ownInventory?.clothing || inventoryState.clothing;
    if (!inventoryState.clothingEnabled) {
      inventoryState.clothing = null;
      inventoryState.clothingOpen = false;
    }
    inventoryState.baseCellSize = message.cellSize || 48;
    applyInterfaceScale();
    inventoryState.isOpen = true;
    inventoryState.inventories.forEach(getInventoryLayout);
    if (
      inventoryState.dialog &&
      !findInventory(inventoryState.dialog.inventoryId)
    )
      inventoryState.dialog = null;
    const capture = inventoryState.keybindCapture;
    const capturedInventory = capture && findInventory(capture.inventoryId);
    const capturedItem = capturedInventory?.items.find(
      (item) => item.id === capture.itemId,
    );
    if (capture && capturedItem && inventoryState.contextMenu) {
      inventoryState.contextMenu = {
        ...inventoryState.contextMenu,
        inventory: capturedInventory,
        item: capturedItem,
      };
    } else clearPopups();
    publishChanges();
  } else if (message.type === "close") {
    hudDrag = null;
    inventoryState.hudPositioning = false;
    inventoryState.isOpen = false;
    inventoryState.clothingOpen = false;
    inventoryState.settingsOpen = false;
  applyInterfaceScale();
    inventoryState.attachmentPanel = null;
    stopWeaponRotation();
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
    stopWeaponRotation();
    windowDrag = null;
    inventoryState.isDockKeyHeld = false;
    refreshDockingPreview();
    cancelItemDrag();
  });
  document.addEventListener("pointerdown", (pointerEvent) => {
    if (inventoryState.crafting || inventoryState.craftingPending) {
      pointerEvent.preventDefault();
      pointerEvent.stopImmediatePropagation();
    }
  }, true);
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
      inventoryState.keybindCapture = null;
      publishChanges();
    }
  });
  window.addEventListener("message", handleServerMessage);
  window.addEventListener("blur", () => {
    stopWeaponRotation();
    dialogDrag = null;
    windowDrag = null;
    inventoryState.isDockKeyHeld = false;
    refreshDockingPreview();
    cancelItemDrag();
  });
  window.addEventListener("resize", () => {
    inventoryState.viewport = { width: innerWidth, height: innerHeight };
    const panel = inventoryState.attachmentPanel;
    if (panel) void sendNuiRequest("weaponPreviewViewport", { inventoryId: panel.inventoryId, itemId: panel.itemId });
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
