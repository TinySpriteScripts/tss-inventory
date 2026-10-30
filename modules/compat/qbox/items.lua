-- Qbox can read item definitions before the inventory starts. No database or bridge is loaded here.
local resourceName = 'tss-inventory'
local environment = setmetatable({ Config = {}, TSSItems = {} }, { __index = _G })
local definitionFiles = {
    'config.lua',
    'data/items.lua',
    'data/weapons.lua',
    'data/attachments.lua',
    'data/clothing.lua',
}

for _, fileName in ipairs(definitionFiles) do
    local source = LoadResourceFile(resourceName, fileName)
    assert(source, 'Missing TSS item definitions: ' .. fileName)
    local chunk, loadError = load(source, '@' .. resourceName .. '/' .. fileName, 't', environment)
    assert(chunk, loadError)
    chunk()
end

local items = {}
for itemName, definition in pairs(environment.TSSItems) do
    local defaults = environment.Config.ItemDefaults
    local stack = definition.stack
    if stack == nil then stack = defaults.stack end
    local useable = definition.useable
    if useable == nil then useable = defaults.useable end
    local shouldClose = definition.shouldClose
    if shouldClose == nil then shouldClose = defaults.shouldClose end
    items[itemName] = {
        name = itemName,
        label = definition.label or itemName,
        description = definition.description,
        weight = definition.weight or defaults.weight,
        image = definition.image or itemName .. '.png',
        type = definition.weapon and 'weapon' or 'item',
        unique = not stack,
        useable = useable,
        shouldClose = shouldClose,
        ammotype = definition.ammoItem,
    }
end

return items
