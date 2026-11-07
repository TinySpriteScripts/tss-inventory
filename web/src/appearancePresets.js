const solid = (first, firstOpacity = 100) => ({ mode: "solid", first, firstOpacity });
const gradient = (first, second, angle = 135, balance = 50) => ({
  mode: "gradient", first, second, firstOpacity: 96, secondOpacity: 93, angle, balance,
});

function palette({ accent, panel, title, slot, selection, text, muted, line, success, warning, accentText, layout }) {
  const surface = solid(panel.first, 98);
  return {
    accent, panel, titleBar: solid(title), grid: solid(title, 60),
    item: solid(slot, 96), selected: solid(selection),
    menu: surface, tooltip: surface, dialog: surface, settings: surface,
    control: solid(slot), hud: surface, notification: surface,
    ghost: solid(slot, 85), track: solid(line, 55),
    text: solid(text), muted: solid(muted), accentText: solid(accentText),
    border: solid(line, 80), gridLine: solid(line, 60),
    success: solid(success), warning: solid(warning),
    price: solid(warning), salePrice: solid(success),
    layout,
  };
}

export const appearancePresets = [
  {
    id: "cyberpunk", label: "Cyberpunk",
    theme: palette({
      accent: gradient("#ff40c7", "#45e7ff", 90, 42), panel: gradient("#161028", "#0a2333"),
      title: "#24123d", slot: "#26203e", selection: "#413062",
      text: "#f8ecff", muted: "#bfaee0", line: "#6b51a5", success: "#55efca", warning: "#ffbf68",
      accentText: "#140c22", layout: { windowRadius: 5, slotRadius: 3, padding: 8 },
    }),
  },
  {
    id: "ox-lib", label: "Ox Lib",
    theme: palette({
      accent: solid("#1971c2"), panel: solid("#1a1b1e", 97),
      title: "#25262b", slot: "#2c2e33", selection: "#183e61",
      text: "#f1f3f5", muted: "#a6a7ab", line: "#495057", success: "#51cf66", warning: "#ffd43b",
      accentText: "#ffffff", layout: { windowRadius: 8, slotRadius: 4, padding: 10 },
    }),
  },
  {
    id: "zombie", label: "Zombie",
    theme: palette({
      accent: solid("#abbd63"), panel: gradient("#1a2118", "#2d241a", 160, 62),
      title: "#2d3522", slot: "#34392b", selection: "#4a512e",
      text: "#eee9d5", muted: "#b8b798", line: "#646a48", success: "#a8c974", warning: "#e49368",
      accentText: "#161c10", layout: { windowRadius: 2, slotRadius: 1, padding: 6 },
    }),
  },
  {
    id: "kora", label: "Kora",
    theme: palette({
      accent: solid("#95ff00"), panel: solid("#151515", 97),
      title: "#0a0a0a", slot: "#202020", selection: "#273415",
      text: "#ededed", muted: "#bbbbbb", line: "#353535", success: "#4ade80", warning: "#f59e0b",
      accentText: "#0a0a0a", layout: { windowRadius: 8, slotRadius: 4, padding: 10 },
    }),
  },
];
