# React inventory UI

The live UI is built with React. No external CDN or development server is required in FiveM: `index.html` loads the committed `app.js` bundle and `style.css`.

## Source layout

- `src/main.jsx` starts the React root.
- `src/components.jsx` contains inventory windows, grids, items, dock tabs, tooltips, context menus, the movable quantity dialog and the ghost preview.
- `src/inventoryStore.js` handles FiveM messages, server requests, payment selection, drag placement, rotation and window movement. React subscribes to its state updates.
- `src/docking.js` defines the eight adjoining dock slots and pointer hit tests independently of rendering.
- `style.css` contains readable UI styles, including thin red scrollbars and spinner-free number fields.
- `build.mjs` bundles the source and the local React runtime into `app.js`.

Keep authored variables descriptive, leave spacing between functions and event handlers, and make markup changes in the React components rather than manually creating DOM elements. `app.js` is generated output, including third-party React code; edit source files and rebuild instead of editing that bundle.

## Build

From this `web` directory:

```text
npm ci
npm run build
```

Dependencies are locked by `package-lock.json`. The checked-in bundle is already built. Node and node_modules are needed only to rebuild, not to run the resource. FiveM serves only the manifest-listed UI assets and images.

## GitHub releases

Push a tag beginning with `v` to build the UI and publish a release named after the tag:

```text
git tag v1.0.0
git push origin v1.0.0
```

Commit and push the workflow and your changes before tagging. The release includes `tss-inventory.zip`, containing the resource, built UI, images and source files. Dependencies and tests are excluded. GitHub Actions must be enabled; the workflow uses the built-in GitHub token, so no extra secret is needed.

## Shop controls

Cash and Bank are selectable buttons at the bottom right of each shop. Each shop keeps its own selection while the UI is running. Both drag-one purchases and quantity purchases send the selected account; the server accepts only cash or bank and does not fall back to another account.

The buy popup contains only the title, quantity input, total, Cancel and Buy. Drag its title to move it. Escape cancels the popup. Tab stays within its controls. Quantity spinner arrows are hidden. Inventory movement/rotation and the server remain authoritative as before.

Owned items now have Drop and Drop amount… context actions. Dropping onto the empty game background also requests a world drop; other UI surfaces cancel the move. Ground inventories use the same React windows, item grids, rotation and pickup requests as normal inventories. Temporary drop IDs are excluded from saved layout preferences.

## Docking

Drag a window header or an inventory tab, then hold D to reveal the eight dock slots. Release the mouse over a slot while still holding D to dock. Releasing D before the mouse leaves the window floating. The centre is not a dock target. Guides remain hidden during normal window moves, item drags and quantity-popup moves.

There are two half-height slots on each side and two slots across both the top and bottom. Their edges meet exactly without overlapping; the centre remains open. Each slot forms its own tab group. The grid dock button has been removed. The square control undocks the active tab, and still brings floating windows forward. Dragging a tab out without D restores a floating window. Old four-edge layout preferences migrate to the corresponding first slot on that edge.
