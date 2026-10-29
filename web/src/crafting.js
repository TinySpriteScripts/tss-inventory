// Match the same two stacks and placement order used by the server.
export function planCraft(inventory, sourceItem, targetItem) {
  if (!inventory.isOwn || inventory.type !== "player" || sourceItem.id === targetItem.id ||
      sourceItem.name === targetItem.name || sourceItem.metadata?.containerId || targetItem.metadata?.containerId) return null;
  for (const recipe of inventory.craftingRecipes || []) {
    if (!recipe.input[sourceItem.name] || !recipe.input[targetItem.name] ||
        sourceItem.amount < recipe.input[sourceItem.name] || targetItem.amount < recipe.input[targetItem.name]) continue;
    const remainingItems = inventory.items.map((item) => ({ ...item,
      amount: item.amount - (item.id === sourceItem.id ? recipe.input[sourceItem.name] :
        item.id === targetItem.id ? recipe.input[targetItem.name] : 0),
    })).filter((item) => item.amount > 0);
    const output = { name: recipe.name, amount: recipe.output ?? 1, metadata: {}, definition: recipe.definition, rotated: false };
    const outputSize = recipe.definition.size;
    const fits = (column, row) => column > 0 && row > 0 && column + outputSize.x - 1 <= inventory.size.x &&
      row + outputSize.y - 1 <= inventory.size.y && remainingItems.every((obstacle) => {
        const obstacleSize = obstacle.rotated ? { x: obstacle.definition.size.y, y: obstacle.definition.size.x } : obstacle.definition.size;
        return column >= obstacle.x + obstacleSize.x || column + outputSize.x <= obstacle.x ||
          row >= obstacle.y + obstacleSize.y || row + outputSize.y <= obstacle.y;
      });
    let position = [{ x: targetItem.x, y: targetItem.y }, { x: sourceItem.x, y: sourceItem.y }]
      .find((candidate) => fits(candidate.x, candidate.y));
    for (let row = 1; !position && row <= inventory.size.y; row += 1) {
      for (let column = 1; column <= inventory.size.x; column += 1) {
        if (fits(column, row)) {
          position = { x: column, y: row };
          break;
        }
      }
    }
    if (!position) continue;
    const consumedWeight = recipe.input[sourceItem.name] * sourceItem.definition.weight + recipe.input[targetItem.name] * targetItem.definition.weight;
    if (inventory.maxWeight != null && inventory.weight - consumedWeight + recipe.definition.weight * output.amount > inventory.maxWeight) continue;
    return { recipe: recipe.name, targetItemId: targetItem.id, item: { ...output, ...position }, duration: recipe.duration };
  }
  return null;
}
