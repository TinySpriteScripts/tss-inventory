import { createRoot } from "react-dom/client";
import { InventoryApp } from "./components.jsx";
import { initialiseInventoryUi } from "./inventoryStore.js";

initialiseInventoryUi();

const inventoryRoot = createRoot(document.getElementById("app-root"));
inventoryRoot.render(<InventoryApp />);
