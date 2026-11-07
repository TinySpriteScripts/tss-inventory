// Default values match the unmodified stylesheet. Only edited areas are saved.
export const appearanceAreas = [
  { key: "accent", label: "Accent", colour: "#d94a50" },
  { key: "panel", label: "Window background", colour: "#0f1113", opacity: 85 },
  { key: "titleBar", label: "Title bar", colour: "#0f1113", opacity: 0 },
  { key: "grid", label: "Empty slots", colour: "#0f1113", opacity: 0 },
  { key: "item", label: "Occupied slots", colour: "#25282b", opacity: 94 },
  { key: "selected", label: "Selected slots", colour: "#372225", opacity: 96 },
  { key: "menu", label: "Context menu", colour: "#121416", opacity: 98 },
  { key: "tooltip", label: "Item details", colour: "#121416", opacity: 98 },
  { key: "dialog", label: "Popups", colour: "#121416", opacity: 98 },
  { key: "settings", label: "Settings panel", colour: "#111316", opacity: 98 },
  { key: "control", label: "Buttons and inputs", colour: "#202226" },
  { key: "hud", label: "Weapon display", colour: "#111316", opacity: 88 },
  { key: "notification", label: "Item notifications", colour: "#111316", opacity: 94 },
  { key: "ghost", label: "Dragged item", colour: "#1e2022", opacity: 60 },
  { key: "track", label: "Progress tracks", colour: "#ffffff", opacity: 12 },
  { key: "text", label: "Main text", colour: "#eeeeee", solidOnly: true },
  { key: "accentText", label: "Accent button text", colour: "#ffffff", solidOnly: true },
  { key: "muted", label: "Secondary text", colour: "#aaaaaa", solidOnly: true },
  { key: "border", label: "Panel and control borders", colour: "#ffffff", opacity: 15, solidOnly: true },
  { key: "gridLine", label: "Grid lines", colour: "#ffffff", opacity: 10, solidOnly: true },
  { key: "success", label: "Valid placement and crafting", colour: "#44c970", solidOnly: true },
  { key: "warning", label: "Invalid placement", colour: "#e4a25b", solidOnly: true },
  { key: "price", label: "Buy price", colour: "#ef888d", solidOnly: true },
  { key: "salePrice", label: "Sell price", colour: "#78c694", solidOnly: true },
];

export const appearanceLayoutControls = [
  { key: "windowRadius", label: "Window radius", max: 18, defaultValue: 0 },
  { key: "slotRadius", label: "Slot radius", max: 12, defaultValue: 0 },
  { key: "padding", label: "Window padding", max: 16, defaultValue: 8 },
];

export function appearanceLayout(settings) {
  const overrides = settings.appearanceEditable === true ? settings.appearance?.layout : undefined;
  return Object.fromEntries(appearanceLayoutControls.map(({ key, defaultValue }) => [
    key, overrides?.[key] ?? settings.appearanceDefaults?.layout?.[key] ?? defaultValue,
  ]));
}

export function colourChannels(colour) {
  return [1, 3, 5].map((start) => Number.parseInt(colour.slice(start, start + 2), 16));
}

export function areaPaint(area, settings) {
  const defaultPaint = {
    mode: "solid", first: area.colour, firstOpacity: area.opacity ?? 100,
    second: "#41434b", secondOpacity: 100, angle: 90, balance: 50,
  };
  return {
    ...defaultPaint,
    ...settings.appearanceDefaults?.[area.key],
    ...(settings.appearanceEditable === true ? settings.appearance?.[area.key] : undefined),
  };
}

function colourWithOpacity(colour, opacity) {
  return `rgba(${colourChannels(colour).join(", ")}, ${opacity / 100})`;
}

export function paintBackground(paint) {
  const first = colourWithOpacity(paint.first, paint.firstOpacity);
  if (paint.mode !== "gradient") return first;
  const second = colourWithOpacity(paint.second, paint.secondOpacity);
  return `linear-gradient(${paint.angle}deg, ${first}, ${paint.balance}%, ${second})`;
}

export function applyAppearance(settings) {
  const root = document.documentElement.style;
  const properties = [];
  const set = (name, value) => {
    root.setProperty(name, value);
    properties.push(name);
  };
  const layout = appearanceLayout(settings);
  set("--theme-window-radius", `${layout.windowRadius}px`);
  set("--theme-slot-radius", `${layout.slotRadius}px`);
  set("--theme-padding", `${layout.padding}px`);

  for (const area of appearanceAreas) {
    if (!settings.appearanceDefaults?.[area.key] &&
        !(settings.appearanceEditable === true && settings.appearance?.[area.key])) continue;
    const paint = areaPaint(area, settings);
    const cssName = area.key.replace(/[A-Z]/g, (letter) => `-${letter.toLowerCase()}`);
    const background = paintBackground(paint);
    set(`--theme-${cssName}`, area.key === "grid" && paint.mode === "solid"
      ? `linear-gradient(${background}, ${background})` : background);
    if (["accent", "success", "warning"].includes(area.key)) {
      set(`--theme-${cssName}-rgb`, colourChannels(paint.first).join(", "));
    }
    if (area.key === "accent") set("--theme-accent-line", colourWithOpacity(paint.first, paint.firstOpacity));
  }

  return () => properties.forEach((name) => root.removeProperty(name));
}
