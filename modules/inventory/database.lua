-- All SQL, schema creation and character lifecycle detection are owned here.
TSSDatabase = { ready = false }

local database = TSSDatabase
local bridge = exports.tss_bridge:GetModules({ 'Player' }, Config.TSS)
local observedCharacters = {}

local tableDefinitions = {
    [[CREATE TABLE IF NOT EXISTS `tss_inventory` (
        `inventory_id` VARCHAR(160) NOT NULL,
        `owner` VARCHAR(64) NOT NULL,
        `inventory_type` VARCHAR(64) NOT NULL,
        `label` VARCHAR(100) NOT NULL,
        `size` LONGTEXT NOT NULL,
        `items` LONGTEXT NOT NULL,
        `metadata` LONGTEXT NOT NULL,
        `settings` LONGTEXT NOT NULL,
        `rules` LONGTEXT NOT NULL,
        `revision` BIGINT UNSIGNED NOT NULL DEFAULT 0,
        `next_item_id` BIGINT UNSIGNED NOT NULL DEFAULT 1,
        `last_updated` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
        PRIMARY KEY (`inventory_id`), UNIQUE KEY `unique_inventory_owner` (`owner`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]],
    [[CREATE TABLE IF NOT EXISTS `tss_inventory_containers` (
        `inventory_id` VARCHAR(160) NOT NULL,
        `owner` VARCHAR(64) NULL,
        `inventory_type` VARCHAR(64) NOT NULL,
        `label` VARCHAR(100) NOT NULL,
        `size` LONGTEXT NOT NULL,
        `items` LONGTEXT NOT NULL,
        `metadata` LONGTEXT NOT NULL,
        `settings` LONGTEXT NOT NULL,
        `coords` LONGTEXT NULL,
        `rules` LONGTEXT NOT NULL,
        `revision` BIGINT UNSIGNED NOT NULL DEFAULT 0,
        `next_item_id` BIGINT UNSIGNED NOT NULL DEFAULT 1,
        `last_updated` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
        PRIMARY KEY (`inventory_id`), KEY `container_owner` (`owner`), KEY `container_type` (`inventory_type`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]],
}

function database.IsPersistent(inventory)
    return inventory.type ~= 'drop' and inventory.persistent ~= false
        and inventory.id:sub(1, 5) ~= 'drop:'
end

function database.CitizenId(playerSource)
    if not playerSource or not GetPlayerName(playerSource) then return nil end
    local citizenId = bridge.Player.Identifier(playerSource, 'citizenid')
    if type(citizenId) ~= 'string' or #citizenId == 0 or #citizenId > 64 then return nil end
    return citizenId
end

function database.PlayerInventoryId(playerSource)
    local citizenId = database.CitizenId(playerSource)
    return citizenId and ('player_' .. citizenId) or nil
end

function database.PlayerLabel(playerSource)
    local playerName = bridge.Player.Name(playerSource) or GetPlayerName(playerSource) or 'Player'
    return Config.PlayerDefaults.useNamePrefix
        and (playerName .. ' ' .. Config.PlayerDefaults.label) or Config.PlayerDefaults.label
end

local function tableForInventory(inventory)
    return inventory.type == 'player' and 'tss_inventory' or 'tss_inventory_containers'
end

local function decodeObject(encodedValue, fieldName)
    local succeeded, value = pcall(json.decode, encodedValue or '{}')
    if not succeeded or type(value) ~= 'table' then error('Invalid database JSON: ' .. fieldName) end
    return value
end

local function decodeRow(row)
    if not row then return nil end
    local rules = decodeObject(row.rules, 'rules')
    local inventory = {
        id = row.inventory_id,
        owner = row.owner,
        type = row.inventory_type,
        label = row.label,
        size = decodeObject(row.size, 'size'),
        items = decodeObject(row.items, 'items'),
        metadata = decodeObject(row.metadata, 'metadata'),
        settings = decodeObject(row.settings, 'settings'),
        whitelist = rules.whitelist or {},
        blacklist = rules.blacklist or {},
        maxWeight = rules.maxWeight,
        account = rules.account,
        bucket = rules.bucket,
        revision = tonumber(row.revision) or 0,
        nextItemId = tonumber(row.next_item_id) or 1,
        last_updated = row.last_updated,
    }

    if row.coords and row.coords ~= 'null' then inventory.coords = decodeObject(row.coords, 'coords') end
    if inventory.type == 'shop' then inventory.shopId = inventory.id:sub(6) end
    if not database.IsPersistent(inventory) then error('Temporary inventory found in persistent storage') end
    return inventory
end

function database.Load(inventoryId)
    if inventoryId:sub(1, 5) == 'drop:' then return nil end
    local tableName = inventoryId:sub(1, 7) == 'player_' and 'tss_inventory' or 'tss_inventory_containers'
    return decodeRow(MySQL.single.await(('SELECT *, DATE_FORMAT(`last_updated`, \'%%Y-%%m-%%d %%H:%%i:%%s.%%f\') AS `last_updated` FROM `%s` WHERE `inventory_id` = ?'):format(tableName), { inventoryId }))
end

function database.Save(inventories)
    local persistentInventories = {}
    for _, inventory in ipairs(inventories) do
        if database.IsPersistent(inventory) then persistentInventories[#persistentInventories + 1] = inventory end
    end
    if #persistentInventories == 0 then return true end

    local timestamp = MySQL.scalar.await([[SELECT DATE_FORMAT(UTC_TIMESTAMP(3), '%Y-%m-%d %H:%i:%s.%f')]])
    local statements = {}

    for _, inventory in ipairs(persistentInventories) do
        local columns = '`inventory_id`, `owner`, `inventory_type`, `label`, `size`, `items`, `metadata`, `settings`, `rules`, `revision`, `next_item_id`, `last_updated`'
        local placeholders = '?, NULLIF(?, \'\'), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?'
        local rules = { whitelist = inventory.whitelist or {}, blacklist = inventory.blacklist or {},
            maxWeight = inventory.maxWeight, account = inventory.account, bucket = inventory.bucket }
        local parameters = { inventory.id, inventory.owner or '', inventory.type, inventory.label,
            json.encode(inventory.size), json.encode(inventory.items), json.encode(inventory.metadata),
            json.encode(inventory.settings or {}), json.encode(rules), inventory.revision, inventory.nextItemId, timestamp }
        local updates = '`owner` = VALUES(`owner`), `inventory_type` = VALUES(`inventory_type`), `label` = VALUES(`label`), `size` = VALUES(`size`), `items` = VALUES(`items`), `metadata` = VALUES(`metadata`), `settings` = VALUES(`settings`), `rules` = VALUES(`rules`), `revision` = VALUES(`revision`), `next_item_id` = VALUES(`next_item_id`), `last_updated` = VALUES(`last_updated`)'

        if inventory.type ~= 'player' then
            columns = columns .. ', `coords`'
            placeholders = placeholders .. ', ?'
            parameters[#parameters + 1] = inventory.coords and json.encode(inventory.coords) or 'null'
            updates = updates .. ', `coords` = VALUES(`coords`)'
        end

        statements[#statements + 1] = {
            query = ('INSERT INTO `%s` (%s) VALUES (%s) ON DUPLICATE KEY UPDATE %s'):format(
                tableForInventory(inventory), columns, placeholders, updates),
            values = parameters,
        }
    end

    if MySQL.transaction.await(statements) ~= true then return false, 'Database transaction failed' end
    for _, inventory in ipairs(persistentInventories) do inventory.last_updated = timestamp end
    return true
end

function database.Delete(inventory)
    if not database.IsPersistent(inventory) then return false, 'Temporary inventories do not use the database' end
    return MySQL.transaction.await({{
        query = ('DELETE FROM `%s` WHERE `inventory_id` = ?'):format(tableForInventory(inventory)),
        values = { inventory.id },
    }}) == true
end

function database.ContainersForOwner(citizenId)
    local rows = MySQL.query.await('SELECT *, DATE_FORMAT(`last_updated`, \'%Y-%m-%d %H:%i:%s.%f\') AS `last_updated` FROM `tss_inventory_containers` WHERE `owner` = ?', { citizenId })
    local inventories = {}
    for _, row in ipairs(rows or {}) do inventories[#inventories + 1] = decodeRow(row) end
    return inventories
end

function database.Start(callbacks)
    MySQL.ready(function()
        local succeeded, startupError = pcall(function()
            for _, definition in ipairs(tableDefinitions) do MySQL.query.await(definition) end
        end)

        if not succeeded then
            print('[tss-inventory] Database startup failed: ' .. tostring(startupError))
            return
        end

        database.ready = true
        callbacks.onReady()

        CreateThread(function()
            while true do
                for _, playerId in ipairs(GetPlayers()) do
                    local playerSource = tonumber(playerId)
                    local citizenId = database.CitizenId(playerSource)
                    if observedCharacters[playerSource] ~= citizenId then
                        if observedCharacters[playerSource] then callbacks.onCharacterUnloaded(playerSource) end
                        observedCharacters[playerSource] = citizenId
                        if citizenId then callbacks.onCharacterLoaded(playerSource) end
                    end
                end
                Wait(1000)
            end
        end)
    end)

    AddEventHandler('playerDropped', function()
        observedCharacters[source] = nil
        callbacks.onCharacterUnloaded(source)
    end)
end

-- Used only when a modified item-bound inventory has no cached parent (offline exports).
function database.ParentInventoryIds(containerId)
    local searchPattern = containerId:gsub('!', '!!'):gsub('%%', '!%%'):gsub('_', '!_')
    local rows = MySQL.query.await([[SELECT inventory_id FROM tss_inventory
        WHERE JSON_SEARCH(items, 'one', ?, '!', '$[*].metadata.containerId') IS NOT NULL
        UNION SELECT inventory_id FROM tss_inventory_containers
        WHERE JSON_SEARCH(items, 'one', ?, '!', '$[*].metadata.containerId') IS NOT NULL]], { searchPattern, searchPattern })
    local identifiers = {}
    for _, row in ipairs(rows or {}) do identifiers[#identifiers + 1] = row.inventory_id end
    return identifiers
end
