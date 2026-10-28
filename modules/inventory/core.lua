-- Pure inventory model. No network entry points: only server.lua calls mutations.
TSSCore = {}
local C = TSSCore
function C.copy(value, seen)
    if type(value) ~= 'table' then return value end
    seen = seen or {}
    if seen[value] then error('cyclic table') end
    seen[value] = true
    local out = {}
    for k,v in pairs(value) do out[k] = C.copy(v, seen) end
    seen[value] = nil
    return out
end
function C.equal(a,b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= 'table' then return a == b end
    for k,v in pairs(a) do if not C.equal(v,b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
function C.integer(n, min, max)
    return type(n) == 'number' and n == n and n % 1 == 0 and n >= min and n <= max
end
function C.size(s)
    return type(s)=='table' and C.integer(s.x,1,Config.MaxDimension) and C.integer(s.y,1,Config.MaxDimension) and s.x*s.y <= Config.MaxCells
end
function C.definition(name)
    if type(name) ~= 'string' or not TSSItems[name] then return nil end
    local out = C.copy(Config.ItemDefaults)
    for k,v in pairs(TSSItems[name]) do out[k] = C.copy(v) end
    out.name = name
    out.stackSize = out.stack and out.stackSize or 1
    return out
end
function C.allowed(inv,name)
    local function has(list)
        for _,v in ipairs(list or {}) do if v==name then return true end end
        return false
    end
    if inv.whitelist and #inv.whitelist>0 and not has(inv.whitelist) then return false end
    return not has(inv.blacklist)
end
function C.footprint(item)
    local def=C.definition(item.name)
    if not def then return nil end
    if item.rotated==true then return def.size.y,def.size.x end
    return def.size.x,def.size.y
end
function C.fits(inv,item,x,y,ignore)
    local def = C.definition(item.name)
    if not def or not C.integer(x,1,inv.size.x) or not C.integer(y,1,inv.size.y) then return false end
    local w,h = C.footprint(item)
    if x+w-1>inv.size.x or y+h-1>inv.size.y then return false end
    for _,other in ipairs(inv.items) do
        if other.id ~= ignore then
            local od = C.definition(other.name)
            if not od then return false end
            local ow,oh=C.footprint(other)
            if x < other.x+ow and x+w>other.x and y<other.y+oh then return false end
        end
    end
    return true
end
function C.space(inv,item)
    for y=1,inv.size.y do for x=1,inv.size.x do
        if C.fits(inv,item,x,y) then return x,y end
    end end
end
function C.find(inv,id)
    for i,item in ipairs(inv.items) do if item.id==id then return item,i end end
end
function C.weight(inv)
    local weight=0
    for _,item in ipairs(inv.items) do weight=weight+C.definition(item.name).weight*item.amount end
    return weight
end
-- Plan on a clone. Failure never partially adds items.
function C.add(inv,name,amount,metadata)
    local def=C.definition(name)
    if not def then return false,'Unknown item' end
    if not C.integer(amount,1,100000) then return false,'Invalid amount' end
    if not C.allowed(inv,name) then return false,'Item is not allowed in this inventory' end
    if inv.maxWeight and C.weight(inv)+def.weight*amount>inv.maxWeight then return false,'Weight limit exceeded' end
    local work=C.copy(inv)
    metadata=C.copy(metadata or def.metadata)
    for _,item in ipairs(work.items) do
        if def.stack and item.name==name and C.equal(item.metadata,metadata) then
            local take=math.min(amount,math.max(0,def.stackSize-item.amount))
            item.amount=item.amount+take; amount=amount-take
            if amount==0 then break end
        end
    end
    while amount>0 do
        local item={ name=name, amount=math.min(amount,def.stackSize), metadata=C.copy(metadata) }
        local x,y=C.space(work,item)
        if not x then return false,'Not enough grid space' end
        item.id=work.nextItemId; work.nextItemId=work.nextItemId+1
        item.x=x; item.y=y; work.items[#work.items+1]=item
        amount=amount-item.amount
    end
    inv.items=work.items; inv.nextItemId=work.nextItemId
    return true
end
function C.remove(inv,id,amount)
    local item,index=C.find(inv,id)
    if not item or not C.integer(amount,1,item.amount) then return false,'Invalid item or amount' end
    if amount==item.amount then table.remove(inv.items,index) else item.amount=item.amount-amount end
    return true
end
-- Explicit-position transfer: merge only compatible stacks, never swap or delete on failure.
function C.move(from,to,id,amount,x,y,rotated)
    local src=C.find(from,id)
    if not src or not C.integer(amount,1,src.amount) then return false,'Invalid item or amount' end
    if rotated~=nil and type(rotated)~='boolean' then return false,'Invalid rotation' end
    if rotated==nil then rotated=src.rotated==true end
    if not C.integer(x,1,to.size.x) or not C.integer(y,1,to.size.y) then return false,'Invalid position' end
    if not C.allowed(to,src.name) then return false,'Item is not allowed here' end
    local def=C.definition(src.name)
    if from~=to and to.maxWeight and C.weight(to)+def.weight*amount>to.maxWeight then return false,'Weight limit exceeded' end
    local a=C.copy(from); local b=from==to and a or C.copy(to)
    local item=C.find(a,id)
    local target
    for _,v in ipairs(b.items) do
        local w,h=C.footprint(v)
        if x>=v.x and x<v.x+w and y>=v.y and y<v.y+h and not (from==to and v.id==id) then target=v; break end
    end
    if target then
        if not def.stack or target.name~=item.name or not C.equal(target.metadata,item.metadata) or target.amount+amount>def.stackSize then return false,'Items cannot stack here' end
        target.amount=target.amount+amount
        C.remove(a,id,amount)
    else
        local moved=C.copy(item)
        C.remove(a,id,amount)
        moved.amount=amount; moved.x=x; moved.y=y; moved.rotated=rotated
        if not C.fits(b,moved,x,y) then return false,'Space is occupied or outside grid' end
        if from~=to or amount<src.amount then moved.id=b.nextItemId; b.nextItemId=b.nextItemId+1 end
        b.items[#b.items+1]=moved
    end
    from.items=a.items; from.nextItemId=a.nextItemId
    if from~=to then to.items=b.items; to.nextItemId=b.nextItemId end
    return true
end
function C.resize(inv,size,repack)
    if not C.size(size) then return false,'Invalid dimensions' end
    local work=C.copy(inv); work.size=C.copy(size)
    if repack then
        local items=work.items; work.items={}
        table.sort(items,function(a,b) local ad,bd=C.definition(a.name),C.definition(b.name); return ad.size.x*ad.size.y>bd.size.x*bd.size.y end)
        for _,item in ipairs(items) do
            local x,y=C.space(work,item)
            if not x then return false,'Items do not fit; inventory unchanged' end
            item.x=x; item.y=y; work.items[#work.items+1]=item
        end
    else
        for _,item in ipairs(work.items) do if not C.fits(work,item,item.x,item.y,item.id) then return false,'Items outside new bounds; try repack' end end
    end
    inv.size=work.size; inv.items=work.items
    return true
end
