-- Keep stored themes limited to known areas, RGB colours and numeric controls.
local fills = {
    accent = true, panel = true, titleBar = true, grid = true, item = true,
    selected = true, menu = true, tooltip = true, dialog = true, settings = true,
    control = true, hud = true, notification = true, ghost = true, track = true,
}
local solids = {
    text = true, muted = true, border = true, gridLine = true,
    success = true, warning = true, price = true, salePrice = true, accentText = true,
}
local layoutLimits = { windowRadius = 18, slotRadius = 12, padding = 16 }

local function isColour(value)
    return type(value) == 'string' and value:match('^#%x%x%x%x%x%x$') ~= nil
end

local function sanitizePaint(area, paint)
    if not (fills[area] or solids[area]) or type(paint) ~= 'table'
        or not isColour(paint.first) then return nil end
    local firstOpacity = paint.firstOpacity == nil and 100 or paint.firstOpacity
    if not TSSCore.integer(firstOpacity, 0, 100) then return nil end
    local entry = { mode = paint.mode, first = paint.first:lower(), firstOpacity = firstOpacity }
    if paint.mode == 'gradient' and fills[area] then
        local secondOpacity = paint.secondOpacity == nil and 100 or paint.secondOpacity
        local angle = paint.angle == nil and 90 or paint.angle
        local balance = paint.balance == nil and 50 or paint.balance
        if not isColour(paint.second) or not TSSCore.integer(secondOpacity, 0, 100)
            or not TSSCore.integer(angle, 0, 360) or not TSSCore.integer(balance, 1, 99) then return nil end
        entry.second, entry.secondOpacity = paint.second:lower(), secondOpacity
        entry.angle, entry.balance = angle, balance
    elseif paint.mode ~= 'solid' then
        return nil
    end
    return entry
end

local function sanitize(theme)
    if type(theme) ~= 'table' then return nil end
    local clean = {}
    for area, value in pairs(theme) do
        if area == 'layout' then
            if type(value) ~= 'table' then return nil end
            local layout = {}
            for field, amount in pairs(value) do
                local limit = layoutLimits[field]
                if not limit or not TSSCore.integer(amount, 0, limit) then return nil end
                layout[field] = amount
            end
            clean.layout = layout
        else
            local paint = sanitizePaint(area, value)
            if not paint then return nil end
            clean[area] = paint
        end
    end
    return clean
end

local config = Config.Appearance or {}
local defaults = sanitize(config.defaultTheme)
if config.defaultTheme ~= nil and not defaults then
    print('[tss-inventory] Invalid Config.Appearance.defaultTheme. Using the original colours.')
end

TSSInventoryAppearance = {
    Sanitize = sanitize,
    defaults = defaults or {},
    editable = config.allowCustomThemes == true,
}
