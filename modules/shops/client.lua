local bridge = exports.tss_bridge:GetModules({ 'World', 'Targets', 'Blips' }, Config.TSS)
local pedControllers, zones, blips = {}, {}, {}

CreateThread(function()
    for shopId, shop in pairs(TSSShops) do
        local selectedId = shopId
        local options = {{
            name = 'tss_inventory_shop_' .. shopId,
            label = 'Browse ' .. shop.label,
            icon = 'fas fa-basket-shopping',
            onSelect = function() TriggerServerEvent('tss-inventory:openShop', selectedId) end,
        }}
        local distance = shop.distance or 3.0
        if shop.pedModel then
            local controller = bridge.World.CreateDistancePed({ model = shop.pedModel, coords = shop.coords,
                scenario = shop.scenario or 'WORLD_HUMAN_STAND_IMPATIENT' }, nil, {
                range = 50, despawnRange = 65, freeze = true, invincible = true,
                onSpawn = function(ped) bridge.Targets.Entity(ped, options, distance) end,
                onDespawn = function(ped) bridge.Targets.RemoveEntity(ped) end,
            })
            if controller then pedControllers[#pedControllers + 1] = controller end
        else
            local zone = bridge.Targets.Circle({ name = 'tss_inventory_shop_' .. shopId,
                coords = vec3(shop.coords.x, shop.coords.y, shop.coords.z), radius = 1.0 }, options, distance)
            if zone then zones[#zones + 1] = zone end
        end
        if shop.blip then
            local blip = bridge.Blips.Create({ coords = shop.coords, label = shop.label,
                sprite = shop.blip.sprite, colour = shop.blip.colour, scale = shop.blip.scale or 0.65, shortRange = true })
            if blip then blips[#blips + 1] = blip end
        end
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for _, controller in ipairs(pedControllers) do if controller.remove then controller.remove() end end
    for _, zone in ipairs(zones) do bridge.Targets.RemoveZone(zone) end
    for _, blip in ipairs(blips) do bridge.Blips.Remove(blip) end
end)
