// Eight adjoining regions form a ring around an unobstructed centre.
export const DOCK_SLOT_IDS = [
  "left-top",
  "left-bottom",
  "top-left",
  "top-right",
  "right-top",
  "right-bottom",
  "bottom-left",
  "bottom-right",
];

export const LEGACY_DOCK_SLOTS = {
  left: "left-top",
  right: "right-top",
  top: "top-left",
  bottom: "bottom-left",
};

export function getDockSlots(viewportWidth, viewportHeight) {
  const sideWidth = Math.floor(viewportWidth / 6);
  const horizontalHeight = Math.floor(viewportHeight * 0.28);
  const centreColumn = Math.floor(viewportWidth / 2);
  const centreRow = Math.floor(viewportHeight / 2);
  const rightColumn = viewportWidth - sideWidth;
  const bottomRow = viewportHeight - horizontalHeight;

  return [
    { id: "left-top", x: 0, y: 0, width: sideWidth, height: centreRow },
    {
      id: "left-bottom",
      x: 0,
      y: centreRow,
      width: sideWidth,
      height: viewportHeight - centreRow,
    },
    {
      id: "top-left",
      x: sideWidth,
      y: 0,
      width: centreColumn - sideWidth,
      height: horizontalHeight,
    },
    {
      id: "top-right",
      x: centreColumn,
      y: 0,
      width: rightColumn - centreColumn,
      height: horizontalHeight,
    },
    {
      id: "right-top",
      x: rightColumn,
      y: 0,
      width: sideWidth,
      height: centreRow,
    },
    {
      id: "right-bottom",
      x: rightColumn,
      y: centreRow,
      width: sideWidth,
      height: viewportHeight - centreRow,
    },
    {
      id: "bottom-left",
      x: sideWidth,
      y: bottomRow,
      width: centreColumn - sideWidth,
      height: horizontalHeight,
    },
    {
      id: "bottom-right",
      x: centreColumn,
      y: bottomRow,
      width: rightColumn - centreColumn,
      height: horizontalHeight,
    },
  ];
}

export function getDockSlotAtPoint(
  pointerX,
  pointerY,
  viewportWidth,
  viewportHeight,
) {
  return (
    getDockSlots(viewportWidth, viewportHeight).find(
      (slot) =>
        pointerX >= slot.x &&
        pointerX < slot.x + slot.width &&
        pointerY >= slot.y &&
        pointerY < slot.y + slot.height,
    )?.id || null
  );
}
