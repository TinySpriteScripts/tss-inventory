local bridge = exports.tss_bridge:GetModules({ 'World', 'Targets' })
local dropControllers = {}

local function removeDropProp(inventoryId)
    local controller = dropControllers[inventoryId]
    if not controller then return end

    controller.remove()
    dropControllers[inventoryId] = nil
end

local function createDropProp(worldDrop)
    local visual = worldDrop.throwVisual
    local model = visual and (type(visual.weapon) == 'string' and GetWeapontypeModel(joaat(visual.weapon)) or visual.model)
        or Config.WorldDrops.prop
    if not model or model == '' or model == 0 then return end
    local dropPosition = worldDrop.coords
    local inventoryId = worldDrop.id

    dropControllers[inventoryId] = bridge.World.CreateDistanceProp({
        model = model,
        coords = vec3(dropPosition.x, dropPosition.y, dropPosition.z - (visual and 0.0 or 0.95)),
    }, {
        range = math.max(50.0, Config.WorldDrops.poolDistance or 5.0),
        despawnRange = math.max(65.0, (Config.WorldDrops.poolDistance or 5.0) + 10.0),
        freeze = true,
        collision = false,
        onSpawn = function(prop)
            PlaceObjectOnGroundProperly(prop)

            if Config.WorldDrops.openWithTarget == true then
                bridge.Targets.Entity(prop, {{
                    name = 'tss_inventory_' .. inventoryId,
                    label = 'Open World Drop',
                    icon = 'fas fa-box-open',
                    action = function()
                        TriggerServerEvent('tss-inventory:openWorldDrop', inventoryId)
                    end,
                }}, 2.0)
            end
        end,
        onDespawn = function(prop)
            if Config.WorldDrops.openWithTarget == true then bridge.Targets.RemoveEntity(prop) end
        end,
    })
end

RegisterNetEvent('tss-inventory:worldDrops', function(worldDrops)
    if source ~= 65535 or type(worldDrops) ~= 'table' then return end
    local visibleDropIds = {}

    if Config.WorldDrops.enable == true then
        for _, worldDrop in ipairs(worldDrops) do
            visibleDropIds[worldDrop.id] = true
            if not dropControllers[worldDrop.id] then createDropProp(worldDrop) end
        end
    end

    for inventoryId in pairs(dropControllers) do
        if not visibleDropIds[inventoryId] then removeDropProp(inventoryId) end
    end
end)

CreateThread(function()
    Wait(1000)
    TriggerServerEvent('tss-inventory:requestWorldDrops')
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for inventoryId in pairs(dropControllers) do removeDropProp(inventoryId) end
end)
