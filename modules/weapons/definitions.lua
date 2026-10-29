-- Pure data helpers shared by equipment, attachment transactions and item views.
TSSWeaponData = {}

TSSWeaponData.Slots = {
    { id = 'magazine', label = 'Magazine' }, { id = 'muzzle', label = 'Muzzle' },
    { id = 'scope', label = 'Scope' }, { id = 'light', label = 'Light' },
    { id = 'grip', label = 'Grip' }, { id = 'barrel', label = 'Barrel' },
    { id = 'finish', label = 'Finish' }, { id = 'tint', label = 'Tint' },
}

function TSSWeaponData.Attachment(weaponName, attachmentName)
    local weapon = TSSItems[weaponName]
    local attachment = TSSAttachmentDefinitions[attachmentName]
    if not weapon or not weapon.weapon or not attachment then return nil end
    if attachment.tint ~= nil then
        local isMk2 = weaponName:find('_mk2', 1, true) ~= nil
        if weapon.ammoMode ~= 'firearm' and weapon.ammoMode ~= 'rechargeable' then return nil end
        return isMk2 == attachment.mk2 and attachment or nil
    end
    return attachment.weapons and attachment.weapons[weaponName] and attachment or nil
end

function TSSWeaponData.ClipSize(item)
    local weapon = TSSItems[item.name]
    if not weapon then return 0 end
    local magazine = TSSWeaponData.Installed(item).magazine
    return magazine and weapon.magazineSizes and weapon.magazineSizes[magazine.record.name] or weapon.clipSize or 0
end

function TSSWeaponData.Installed(item)
    local installed = {}
    local metadata = type(item.metadata) == 'table' and item.metadata or {}
    for slot, record in pairs(type(metadata.attachments) == 'table' and metadata.attachments or {}) do
        local attachment = type(record) == 'table' and TSSWeaponData.Attachment(item.name, record.name)
        if attachment and attachment.slot == slot and (record.metadata == nil or type(record.metadata) == 'table') then installed[slot] = { record = record, definition = attachment } end
    end
    return installed
end

function TSSWeaponData.Components(item)
    local components, tint = {}, nil
    for _, installed in pairs(TSSWeaponData.Installed(item)) do
        local attachment = installed.definition
        if attachment.tint ~= nil then tint = attachment.tint
        else components[#components + 1] = attachment.weapons[item.name] end
    end
    table.sort(components)
    return components, tint
end

function TSSWeaponData.AttachedWeight(item)
    local weight = 0
    for _, installed in pairs(TSSWeaponData.Installed(item)) do weight = weight + installed.definition.weight end
    return weight
end
