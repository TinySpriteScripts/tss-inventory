-- Reload items are separate from the weapon components that set clip capacity.
local fixedMagazineWeapons = {
    weapon_flaregun = true, weapon_marksmanpistol = true,
    weapon_revolver = true, weapon_revolver_mk2 = true, weapon_doubleaction = true, weapon_navyrevolver = true,
    weapon_pumpshotgun = true, weapon_pumpshotgun_mk2 = true, weapon_sawnoffshotgun = true,
    weapon_bullpupshotgun = true, weapon_dbshotgun = true, weapon_combatshotgun = true, weapon_musket = true,
    weapon_rpg = true, weapon_hominglauncher = true, weapon_grenadelauncher = true,
    weapon_grenadelauncher_smoke = true, weapon_compactlauncher = true, weapon_firework = true,
    weapon_railgun = true, weapon_railgunxm3 = true, weapon_minigun = true, weapon_rayminigun = true,
}

local function registerMagazine(weaponName, weapon, variant, suffix, label, capacity, image)
    local magazineName = weaponName:gsub('^weapon_', '') .. suffix .. '_magazine'
    weapon.magazineItems[variant] = magazineName
    TSSItems[magazineName] = {
        label = weapon.label .. ' ' .. label,
        category = 'ammunition',
        description = 'Drag matching ammunition onto this magazine to fill it.',
        size = { x = variant == 'drum_attachment' and 2 or 1, y = 2 },
        weight = 100,
        image = image,
        stack = false,
        useable = false,
        shouldClose = false,
        metadata = { rounds = 0 },
        magazine = { ammoItem = weapon.ammoItem, capacity = capacity },
    }
end

-- Collect weapon names first because magazine definitions are added to the same table.
local detachableMagazineWeapons = {}
for weaponName, definition in pairs(TSSItems) do
    if definition.weapon and definition.ammoMode == 'firearm' and definition.ammoItem
        and definition.clipSize > 0 and definition.magazineReload ~= false and not fixedMagazineWeapons[weaponName] then
        detachableMagazineWeapons[#detachableMagazineWeapons + 1] = weaponName
    end
end

for _, weaponName in ipairs(detachableMagazineWeapons) do
    local weapon = TSSItems[weaponName]
    weapon.magazineItems = {}
    registerMagazine(weaponName, weapon, 'standard', '', 'Magazine', weapon.clipSize, 'clip_attachment.png')
    for attachmentName, capacity in pairs(weapon.magazineSizes or {}) do
        local attachment = TSSAttachmentDefinitions[attachmentName]
        if attachment and attachment.slot == 'magazine' and attachment.weapons[weaponName] then
            local isDrum = attachmentName == 'drum_attachment'
            registerMagazine(weaponName, weapon, attachmentName, isDrum and '_drum' or '_extended',
                isDrum and 'Drum Magazine' or 'Extended Magazine', capacity, attachment.image)
        end
    end
end
