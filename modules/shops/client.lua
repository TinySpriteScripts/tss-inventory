local bridge=exports.tss_bridge:GetModules({'World','Targets','Notify'})
local function setup()
    for id,shop in pairs(TSSShops) do
        local shopId=id
        local options={{name='tss_inventory_shop_'..id,label='Browse '..shop.label,icon='fas fa-basket-shopping',
            action=function() TriggerServerEvent('tss-inventory:openShop',shopId) end}}
        if shop.pedModel then
            bridge.World.CreateDistancePed({model=shop.pedModel,coords=shop.coords,scenario=shop.scenario or 'WORLD_HUMAN_STAND_IMPATIENT'},nil,{
                range=50,despawnRange=65,freeze=true,invincible=true,
                onSpawn=function(ped) bridge.Targets.Entity(ped,options,2.0) end,
                onDespawn=function(ped) bridge.Targets.RemoveEntity(ped) end,
            })
        else
            bridge.Targets.Circle({name='tss_inventory_shop_'..id,coords=vec3(shop.coords.x,shop.coords.y,shop.coords.z),radius=1.0},options,2.0)
        end
    end
end
CreateThread(setup)
