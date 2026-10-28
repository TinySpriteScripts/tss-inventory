local C=TSSCore
local resource=GetCurrentResourceName()
local inventories, sessions, rate, useHandlers = {}, {}, {}, {}
local locks,shopService={},nil
local dropService = nil
local ownIds={}
local types={ player=C.copy(Config.PlayerDefaults), stash=C.copy(Config.DefaultStash) }
for name,def in pairs(TSSContainers) do types[name]=C.copy(def) end
local function metadata(value)
    if type(value)~='table' then return nil,'Metadata must be an object' end
    local function valid(v,depth)
        if depth>8 then return false end
        if type(v)=='table' then
            for k,x in pairs(v) do if type(k)~='string' or #k>128 or not valid(x,depth+1) then return false end end
            return true
        end
        return type(v)=='string' or type(v)=='boolean' or (type(v)=='number' and v==v and math.abs(v)<1e15)
    end
    if not valid(value,0) then return nil,'Metadata must contain JSON object values (maximum depth 8)' end
    local ok,encoded=pcall(json.encode,value)
    if not ok or #encoded>Config.MaxMetadataBytes then return nil,'Metadata too large' end
    return C.copy(value)
end
local function validId(id) return type(id)=='string' and #id>0 and #id<=160 and not id:find('[%c]') end
local function reply(src,msg)
    if src==0 then print('[tss-inventory] '..msg) else TriggerClientEvent('tss-inventory:notice',src,msg) end
end
local function playerId(src)
    local license=GetPlayerIdentifierByType(src,'license')
    return license and ('player:'..license) or nil
end

local function shouldPersistInventory(inventory)
    return inventory.type ~= 'drop' and inventory.persistent ~= false
        and type(inventory.id) == 'string' and inventory.id:sub(1, 5) ~= 'drop:'
end

local function loadInventory(id)
    if inventories[id] then return inventories[id] end
    if type(id) ~= 'string' or id:sub(1, 5) == 'drop:' then return nil end
    local raw=GetResourceKvpString('inventory:'..id)
    if not raw then return nil end
    local ok,inv=pcall(json.decode,raw)
    if not ok or type(inv)~='table' or inv.id~=id or not C.size(inv.size) or type(inv.items)~='table' then
        print('[tss-inventory] Refused invalid saved inventory: '..id); return nil,'Saved inventory is invalid'
    end
    if not shouldPersistInventory(inv) then return nil, 'World drops cannot be loaded from storage' end
    local check=C.copy(inv); check.items={}; local ids={}; local max=0
    if not metadata(inv.metadata) then return nil,'Invalid saved metadata' end
    for _,item in ipairs(inv.items) do
        local def=C.definition(item.name)
        if not def or (item.rotated~=nil and type(item.rotated)~='boolean') or not C.integer(item.id,1,1e12) or ids[item.id] or not C.integer(item.amount,1,def.stackSize) or not metadata(item.metadata) or not C.fits(check,item,item.x,item.y) then
            print('[tss-inventory] Refused incompatible saved items: '..id); return nil,'Saved items conflict with definitions; restore definitions before opening'
        end
        ids[item.id]=true; max=math.max(max,item.id); check.items[#check.items+1]=item
    end
    inv.nextItemId=math.max(max+1,tonumber(inv.nextItemId) or 1)
    inv.revision=tonumber(inv.revision) or 0
    inventories[id]=inv
    return inv
end
local function snapshot(inv)
    local out=C.copy(inv)
    out.owner=nil
    out.weight=C.weight(inv)
    for _,item in ipairs(out.items) do item.definition=C.definition(item.name) end
    return out
end
local function send(src)
    local session=sessions[src]; if not session then return end
    local list={}
    for id in pairs(session) do local inv=loadInventory(id); if inv then local entry=snapshot(inv);entry.isOwn=id==playerId(src);list[#list+1]=entry end end
    table.sort(list,function(a,b) if a.type=='player' and b.type~='player' then return true end if b.type=='player' and a.type~='player' then return false end return a.id<b.id end)
    TriggerClientEvent('tss-inventory:sync',src,list,Config.VisibleItemMetadata,Config.CellSize)
end
-- One KVP transaction record is written before either participant. On restart it is replayed.
-- Native KVP flushes are synchronous; no yields occur during inventory mutations.
local function commit(...)
    local changedInventories = { ... }
    local persistentInventories = {}

    for _, inventory in ipairs(changedInventories) do
        inventory.revision = inventory.revision + 1
        if shouldPersistInventory(inventory) then
            persistentInventories[#persistentInventories + 1] = inventory
        end
    end

    -- Drop records never enter the saved snapshots OR the redo journal.
    if #persistentInventories > 0 then
        SetResourceKvp('pendingTransaction', json.encode(persistentInventories))
        for _, inventory in ipairs(persistentInventories) do
            SetResourceKvp('inventory:' .. inventory.id, json.encode(inventory))
        end
        DeleteResourceKvp('pendingTransaction')
    end

    if dropService then dropService.AfterCommit(changedInventories) end

    for playerSource, inventoryId in pairs(ownIds) do
        for _, inventory in ipairs(changedInventories) do
            if inventory.id == inventoryId then
                TriggerClientEvent('tss-inventory:ownSnapshot', playerSource, snapshot(inventory))
            end
        end
    end

    for playerSource, inventorySession in pairs(sessions) do
        for _, inventory in ipairs(changedInventories) do
            if inventorySession[inventory.id] then send(playerSource); break end
        end
    end
end
do
    local pending=GetResourceKvpString('pendingTransaction')
    if pending then
        local ok,changes=pcall(json.decode,pending)
        if not ok or type(changes)~='table' then error('Invalid transaction journal; preserve KVP data and recover before starting') end
        for _,inv in ipairs(changes) do if shouldPersistInventory(inv) then SetResourceKvp('inventory:'..inv.id,json.encode(inv)) end end
        DeleteResourceKvp('pendingTransaction')
        print('[tss-inventory] Recovered pending inventory transaction')
    end
end
local function create(id,typeName,options)
    if not validId(id) or not types[typeName] then return false,'Invalid inventory ID or type' end
    if id:sub(1, 5) == 'drop:' or typeName == 'drop' then return false, 'World drop IDs are reserved' end
    local existing,loadError=loadInventory(id)
    if existing or loadError then return false,loadError or 'Inventory already exists' end
    options=options or {}
    local def=C.copy(types[typeName])
    for k,v in pairs(options) do def[k]=C.copy(v) end
    if not C.size(def.size) then return false,'Invalid dimensions' end
    local meta,err=metadata(def.metadata or {}); if not meta then return false,err end
    local inv={id=id,type=typeName,label=def.label or typeName,size=def.size,metadata=meta,owner=def.owner,
        whitelist=def.whitelist or {},blacklist=def.blacklist or {},maxWeight=def.maxWeight,items={},nextItemId=1,revision=0}
    if inv.maxWeight and (type(inv.maxWeight)~='number' or inv.maxWeight<0) then return false,'Invalid max weight' end
    inventories[id]=inv; commit(inv)
    return true,C.copy(inv)
end
local function ensurePlayer(src)
    if not src or not GetPlayerName(src) then return nil,'Player is not connected' end
    local id=playerId(src); if not id then return nil,'No license identifier available' end
    local inv,err=loadInventory(id)
    if not inv and not err then
        local options={ owner=id }
        if Config.PlayerDefaults.useNamePrefix then options.label=(GetPlayerName(src) or 'Player')..' '..Config.PlayerDefaults.label end
        local ok,e=create(id,'player',options); if not ok then return nil,e end
        inv=loadInventory(id)
    end
    if inv then ownIds[src]=inv.id end
    return inv,err
end
local function open(src,id)
    if not GetPlayerName(src) then return false,'Player is not connected' end
    local own,err=ensurePlayer(src); if not own then return false,err end
    local inv=loadInventory(id or own.id); if not inv then return false,'Inventory not found' end
    if inv.type == 'drop' and (not dropService or not dropService.IsNearby(src, inv.id)) then
        return false, 'Move closer to the world drop'
    end
    sessions[src]=sessions[src] or {}; sessions[src][own.id]=true; sessions[src][inv.id]=true
    if dropService then dropService.RefreshSession(src, false) end
    send(src); return true
end
local function get(id) local inv=loadInventory(id); return inv and C.copy(inv) end
local function mutate(id,fn,...)
    local inv=loadInventory(id); if not inv then return false,'Inventory not found' end
    if inv.type=='shop' or locks[id] then return false,'Inventory is read-only or busy' end
    local ok,err=fn(inv,...); if ok then commit(inv) end
    return ok,err
end
exports('GetInventory',get)
exports('GetPlayerInventory',function(src) local inv=ensurePlayer(tonumber(src)); return inv and C.copy(inv) end)
exports('GetItemDefinition',C.definition)
exports('GetItemDefinitions',function() local all={} for name in pairs(TSSItems) do all[name]=C.definition(name) end return all end)
exports('GetInventoryWeight',function(id) local inv=loadInventory(id);return inv and C.weight(inv) end)
exports('RemoveItemsByName',function(id,name,amount,filter,slot)
    return mutate(id,function(inv)
        if not C.integer(amount,1,100000) then return false,'Invalid amount' end
        local work=C.copy(inv);local left=amount
        for _,item in ipairs(inv.items) do
            local matches=true
            if type(filter)=='string' then matches=item.metadata.type==filter
            elseif type(filter)=='table' then for k,v in pairs(filter) do if not C.equal(item.metadata[k],v) then matches=false end end
            elseif filter~=nil then matches=false end
            if item.name==name and matches and (slot==nil or item.id==slot) then local take=math.min(left,item.amount);C.remove(work,item.id,take);left=left-take end
            if left==0 then break end
        end
        if left>0 then return false,'Not enough matching items' end
        inv.items=work.items;return true
    end)
end)
exports('AddItemToSlot',function(id,name,amount,meta,slot)
    local def=C.definition(name);if not def then return false,'Unknown item' end
    local clean,err=metadata(meta or def.metadata);if not clean then return false,err end
    return mutate(id,function(inv)
        local item=C.find(inv,slot)
        if not item or item.name~=name or not def.stack or not C.equal(item.metadata,clean) or not C.integer(amount,1,def.stackSize-item.amount) then return false,'Preferred item slot cannot accept this stack' end
        if inv.maxWeight and C.weight(inv)+def.weight*amount>inv.maxWeight then return false,'Weight limit exceeded' end
        item.amount=item.amount+amount;return true
    end)
end)
exports('RegisterShop',function(id,data) return shopService.Register(id,data) end)
exports('OpenShop',function(src,id) return shopService.Open(tonumber(src),id) end)
exports('DropItem', function(playerSource, itemId, quantity, isRotated)
    playerSource = tonumber(playerSource)
    local playerInventory, inventoryError = ensurePlayer(playerSource)
    if not playerInventory then return false, inventoryError end
    return dropService.Drop(playerSource, playerInventory, itemId, quantity, isRotated)
end)
exports('CanCarryItem',function(id,name,amount,meta)
    local inv=loadInventory(id); local def=C.definition(name)
    if not inv or not def then return false,'Unknown inventory or item' end
    local clean,err=metadata(meta or def.metadata); if not clean then return false,err end
    return C.add(C.copy(inv),name,amount,clean)
end)
exports('GetItemCount',function(id,name,meta)
    local inv=loadInventory(id); if not inv then return 0 end
    local total=0
    for _,item in ipairs(inv.items) do if item.name==name and (meta==nil or C.equal(item.metadata,meta)) then total=total+item.amount end end
    return total
end)
exports('CreateInventory',create)
exports('OpenInventory',function(src,id) return open(tonumber(src),id) end)
exports('CloseInventory',function(src,id)
    src=tonumber(src)
    if id and sessions[src] then sessions[src][id]=nil; send(src) else sessions[src]=nil; TriggerClientEvent('tss-inventory:close',src) end
    return true
end)
exports('AddItem',function(id,name,amount,meta)
    local def=C.definition(name); if not def then return false,'Unknown item' end
    local clean,err=metadata(meta or def.metadata); if not clean then return false,err end
    return mutate(id,C.add,name,amount,clean)
end)
exports('RemoveItem',function(id,itemId,amount) return mutate(id,C.remove,itemId,amount) end)
exports('ResizeInventory',function(id,size,repack) return mutate(id,C.resize,size,repack==true) end)
exports('SetInventoryMetadata',function(id,value)
    local clean,err=metadata(value); if not clean then return false,err end
    return mutate(id,function(inv) inv.metadata=clean; return true end)
end)
exports('SetItemMetadata',function(id,itemId,value)
    local clean,err=metadata(value); if not clean then return false,err end
    return mutate(id,function(inv) local item=C.find(inv,itemId); if not item then return false,'Item not found' end item.metadata=clean; return true end)
end)
exports('RegisterInventoryType',function(name,def,applyExisting)
    if type(name)~='string' or #name>64 or type(def)~='table' or not C.size(def.size) then return false,'Invalid inventory type' end
    if applyExisting then return false,'Resize instances explicitly; bulk destructive updates are not supported' end
    types[name]=C.copy(def); return true
end)
exports('GetInventoryType',function(name) return types[name] and C.copy(types[name]) end)
exports('SetInventoryLabel',function(id,label)
    if type(label)~='string' or #label>100 then return false,'Invalid label' end
    return mutate(id,function(inv) inv.label=label; return true end)
end)
exports('SetInventoryRules',function(id,rules)
    if type(rules)~='table' then return false,'Invalid rules' end
    for _,key in ipairs({'whitelist','blacklist'}) do
        if rules[key] then
            if type(rules[key])~='table' then return false,'Invalid list' end
            for _,name in ipairs(rules[key]) do if not C.definition(name) then return false,'Unknown item in list' end end
        end
    end
    if rules.maxWeight~=nil and (type(rules.maxWeight)~='number' or rules.maxWeight<0 or rules.maxWeight~=rules.maxWeight) then return false,'Invalid max weight' end
    return mutate(id,function(inv)
        local work=C.copy(inv)
        for _,key in ipairs({'whitelist','blacklist','maxWeight'}) do if rules[key]~=nil then work[key]=C.copy(rules[key]) end end
        for _,item in ipairs(work.items) do if not C.allowed(work,item.name) then return false,'Existing items violate new rules' end end
        if work.maxWeight and C.weight(work)>work.maxWeight then return false,'Existing items exceed new weight limit' end
        inv.whitelist=work.whitelist; inv.blacklist=work.blacklist; inv.maxWeight=work.maxWeight; return true
    end)
end)
exports('MoveItem',function(fromId,toId,itemId,amount,x,y,rotated)
    local a,b=loadInventory(fromId),loadInventory(toId)
    if not a or not b then return false,'Inventory not found' end
    if a.type=='shop' or b.type=='shop' or locks[a.id] or locks[b.id] then return false,'Inventory is read-only or busy' end
    local ok,err=C.move(a,b,itemId,amount,x,y,rotated)
    if ok then if a==b then commit(a) else commit(a,b) end end
    return ok,err
end)
exports('RegisterUsableItem',function(name,handler,owner)
    if not C.definition(name) or type(handler)~='function' then return false,'Invalid item or callback' end
    useHandlers[name]={handler=handler,resource=owner or GetInvokingResource()}; return true
end)
AddEventHandler('onResourceStop',function(name) for item,v in pairs(useHandlers) do if v.resource==name then useHandlers[item]=nil end end end)

local function limited(src)
    local now=GetGameTimer(); local r=rate[src]
    if not r or now-r.start>=1000 then r={start=now,count=0}; rate[src]=r end
    r.count=r.count+1; return r.count>15
end
RegisterNetEvent('tss-inventory:openSelf',function()
    local src=source; if limited(src) then return end
    local ok,err=open(src); if not ok then reply(src,err) end
end)
RegisterNetEvent('tss-inventory:requestOwn',function()
    local src=source;if limited(src) then return end
    local inv=ensurePlayer(src);if inv then TriggerClientEvent('tss-inventory:ownSnapshot',src,snapshot(inv)) end
end)
RegisterNetEvent('tss-inventory:openShop',function(id)
    local src=source;if limited(src) then return end
    if type(id)~='string' or #id>100 then return end
    local ok,err=shopService.Open(src,id);if not ok then reply(src,err) end
end)

RegisterNetEvent('tss-inventory:requestWorldDrops', function()
    local playerSource = source
    if limited(playerSource) then return end
    dropService.SyncPlayer(playerSource)
end)

RegisterNetEvent('tss-inventory:openWorldDrop', function(inventoryId)
    local playerSource = source
    if limited(playerSource) or not validId(inventoryId) then return end
    local opened, openError = dropService.Open(playerSource, inventoryId)
    if not opened then reply(playerSource, openError) end
end)
RegisterNetEvent('tss-inventory:closeSession',function(id)
    local src=source
    if type(id)=='string' and sessions[src] then sessions[src][id]=nil else sessions[src]=nil end
end)
RegisterNetEvent('tss-inventory:action',function(requestId,data)
    local src=source
    if not C.integer(requestId,1,1e12) then return end
    local function done(ok,err) TriggerClientEvent('tss-inventory:result',src,requestId,ok,err) end
    if limited(src) then return done(false,'Too many requests') end
    if type(data)~='table' or not validId(data.from) or not sessions[src] or not sessions[src][data.from] then return done(false,'Inventory access denied') end
    local a=loadInventory(data.from)
    if a and a.type == 'drop' and not dropService.IsNearby(src, a.id) then
        sessions[src][a.id] = nil
        send(src)
        return done(false, 'Move closer to the world drop')
    end
    if not a or data.revision~=a.revision then send(src); return done(false,'Inventory changed; try again') end
    if locks[a.id] then return done(false,'Inventory is busy') end
    if data.kind=='buy' then
        if a.type~='shop' or not validId(data.to) or not sessions[src][data.to] then return done(false,'Shop access denied') end
        local ok,err=shopService.Buy(src,data);return done(ok,err)
    end
    if a.type=='shop' then return done(false,'Shop items must be purchased') end
    if data.kind == 'drop' then
        local dropped, dropError = dropService.Drop(src, a, data.itemId, data.amount, data.rotated)
        return done(dropped, dropError)
    end
    if data.kind=='use' then
        local item=C.find(a,data.itemId)
        local def=item and C.definition(item.name)
        if not def or not def.useable then return done(false,'Item cannot be used') end
        local usable=useHandlers[item.name]
        if not usable then return done(false,'No standalone use handler registered for this item') end
        local ok,err=pcall(usable.handler,src,C.copy(item),a.id)
        if not ok then print('[tss-inventory] Use handler failed: '..tostring(err)); return done(false,'Item use failed') end
        return done(true)
    end
    if data.kind~='move' or not validId(data.to) or not sessions[src][data.to] then return done(false,'Inventory access denied') end
    local b=loadInventory(data.to)
    if b and b.type == 'drop' and not dropService.IsNearby(src, b.id) then
        sessions[src][b.id] = nil
        send(src)
        return done(false, 'Move closer to the world drop')
    end
    if not b or data.targetRevision~=b.revision then send(src); return done(false,'Target inventory changed; try again') end
    if b.type=='shop' or locks[b.id] then return done(false,'Inventory is read-only or busy') end
    local ok,err=C.move(a,b,data.itemId,data.amount,data.x,data.y,data.rotated)
    if ok then if a==b then commit(a) else commit(a,b) end end
    done(ok,err)
end)
AddEventHandler('playerDropped',function() sessions[source]=nil; rate[source]=nil;ownIds[source]=nil;if dropService then dropService.PlayerDisconnected(source) end end)

local function resolve(value)
    local src=tonumber(value)
    if src then local inv,err=ensurePlayer(src); return inv and inv.id,err end
    if validId(value) and loadInventory(value) then return value end
    return nil,'Player/inventory not found'
end
local function admin(name,help,handler)
    RegisterCommand(name,function(src,args,raw)
        local ok,result,err=pcall(handler,src,args,raw)
        if not ok then print('[tss-inventory] '..name..': '..tostring(result)); return reply(src,'Command failed; check server console') end
        reply(src,result and (type(err)=='string' and err or 'Done') or (err or ('Usage: /'..name..' '..help)))
        if result then print(('[tss-inventory audit] %s by %s'):format(name,src==0 and 'console' or (GetPlayerIdentifierByType(src,'license') or tostring(src)))) end
    end,true) -- command.inv... ACE checked by FiveM on the server
end
admin('invhelp','',function() return true,'invadditem <playerId|inventoryId> <item> <amount> | invremoveitem <target> <itemInstanceId> <amount> | invcreate <id> <type> | invopen <id> [playerId] | invresize <target> <width> <height> [repack] | invmeta <target> <JSON object> | invitemmeta <target> <itemId> <JSON object> | invinspect <target>' end)
admin('invadditem','<target> <item> <amount>',function(_,a)
    local id,err=resolve(a[1]); if not id then return false,err end
    local def=C.definition(a[2]); if not def then return false,'Unknown item' end
    return mutate(id,C.add,a[2],tonumber(a[3]) or 1,def.metadata)
end)
admin('invremoveitem','<target> <itemInstanceId> <amount>',function(_,a)
    local id,err=resolve(a[1]); if not id then return false,err end
    return mutate(id,C.remove,tonumber(a[2]),tonumber(a[3]) or 1)
end)
admin('invcreate','<id> <type>',function(_,a) return create(a[1],a[2] or 'stash') end)
admin('invopen','<inventoryId> [playerId]',function(src,a)
    local target=tonumber(a[2]) or src
    if target==0 then return false,'Specify a connected player ID from console' end
    return open(target,a[1])
end)
admin('invresize','<target> <width> <height> [repack]',function(_,a)
    local id,err=resolve(a[1]); if not id then return false,err end
    return mutate(id,C.resize,{x=tonumber(a[2]),y=tonumber(a[3])},a[4]=='repack')
end)
local function decodeArgs(a,start,raw)
    local text=raw
    -- Preserve quotes/spaces inside JSON instead of depending on command argument tokenisation.
    if type(text)=='string' then
        for _=1,start do text=text:match('^%S+%s+(.+)$'); if not text then break end end
    else text=table.concat(a,' ',start) end
    local ok,value=pcall(json.decode,text or '')
    if not ok then return nil,'Invalid JSON object' end
    return metadata(value)
end
admin('invmeta','<target> <JSON object>',function(_,a,raw)
    local id,err=resolve(a[1]); if not id then return false,err end
    local value,e=decodeArgs(a,2,raw); if not value then return false,e end
    return mutate(id,function(inv) inv.metadata=value; return true end)
end)
admin('invitemmeta','<target> <itemId> <JSON object>',function(_,a,raw)
    local id,err=resolve(a[1]); if not id then return false,err end
    local value,e=decodeArgs(a,3,raw); if not value then return false,e end
    return mutate(id,function(inv) local item=C.find(inv,tonumber(a[2])); if not item then return false,'Item not found' end item.metadata=value; return true end)
end)
admin('invinspect','<target>',function(_,a)
    local id,err=resolve(a[1]); if not id then return false,err end
    print('[tss-inventory inspect] '..json.encode(get(id)))
    return true,'Inventory printed to server console'
end)
dropService = TSSCreateWorldDropService({
    identity = playerId,
    open = open,
    send = send,
    commit = commit,
    locks = locks,
    sessions = sessions,
    put = function(inventory) inventories[inventory.id] = inventory end,
    forget = function(inventoryId) inventories[inventoryId] = nil end,
})

shopService=TSSCreateShopService({load=loadInventory,player=ensurePlayer,identity=playerId,open=open,send=send,commit=commit,metadata=metadata,locks=locks,sessions=sessions,put=function(inv) inventories[inv.id]=inv end})
for id,data in pairs(TSSShops or {}) do
    local ok,err=shopService.Register(id,data)
    if not ok then print(('[tss-inventory] Shop %s disabled: %s'):format(id,err)) end
end
CreateThread(function() while true do Wait(1000);shopService.RevokeDistant();dropService.Tick() end end)
print('[tss-inventory] Loaded with TSS Bridge shop integration.')
