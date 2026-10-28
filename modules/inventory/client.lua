local opened=false
local requestId=0
local pending={}
local ownInventory=nil
local bridge=exports.tss_bridge:GetModules({'Notify'})
local function close()
    opened=false; SetNuiFocus(false,false); SendNUIMessage({type='close'})
    TriggerServerEvent('tss-inventory:closeSession')
end
RegisterCommand('inv',function() if opened then close() else TriggerServerEvent('tss-inventory:openSelf') end end,false)
RegisterKeyMapping('inv','Open standalone inventory','keyboard',Config.OpenKey)
RegisterNetEvent('tss-inventory:sync',function(inventories,visible,cellSize)
    if source~=65535 then return end
    opened=true; SetNuiFocus(true,true)
    SendNUIMessage({type='sync',inventories=inventories,visibleMetadata=visible,cellSize=cellSize})
end)
RegisterNetEvent('tss-inventory:close',function() if source==65535 then close() end end)
RegisterNetEvent('tss-inventory:notice',function(message)
    if source~=65535 then return end
    SendNUIMessage({type='notice',message=tostring(message)})
    bridge.Notify.Send({title='Inventory',description=tostring(message),type='inform'})
end)
RegisterNetEvent('tss-inventory:result',function(id,ok,message)
    if source~=65535 then return end
    local cb=pending[id]; if cb then pending[id]=nil; cb({ok=ok,message=message}) end
end)
RegisterNUICallback('close',function(_,cb) close(); cb({ok=true}) end)
RegisterNUICallback('closeInventory',function(data,cb) TriggerServerEvent('tss-inventory:closeSession',data.id); cb({ok=true}) end)
RegisterNUICallback('action',function(data,cb)
    requestId=requestId+1; local id=requestId; pending[id]=cb
    TriggerServerEvent('tss-inventory:action',id,data)
    SetTimeout(5000,function() if pending[id] then pending[id]=nil; cb({ok=false,message='Server request timed out'}) end end)
end)
CreateThread(function()
    while true do
        if opened then
            DisableControlAction(0,1,true); DisableControlAction(0,2,true); DisableControlAction(0,24,true); DisableControlAction(0,25,true)
            DisablePlayerFiring(PlayerId(),true); Wait(0)
        else Wait(200) end
    end
end)
AddEventHandler('onResourceStop',function(name) if name==GetCurrentResourceName() then SetNuiFocus(false,false) end end)
RegisterNetEvent('tss-inventory:ownSnapshot',function(inv) if source==65535 then ownInventory=inv end end)
exports('GetLocalInventory',function() return ownInventory end)
exports('GetItemDefinitions',function() local definitions={} for name,def in pairs(TSSItems) do local out={} for k,v in pairs(Config.ItemDefaults) do out[k]=v end for k,v in pairs(def) do out[k]=v end out.name=name;definitions[name]=out end return definitions end)
exports('OpenSelf',function() TriggerServerEvent('tss-inventory:openSelf');return true end)
exports('OpenShop',function(id) TriggerServerEvent('tss-inventory:openShop',id);return true end)
exports('CloseInventory',function() close();return true end)
CreateThread(function() Wait(1000);TriggerServerEvent('tss-inventory:requestOwn') end)
