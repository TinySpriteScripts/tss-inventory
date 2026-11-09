if not Config.EnableWeaponSystem then return end

local equippedWeapon
local equippedPed
local reloadPending = false
local lastReport = 0
local wasShooting = false

local lastHudSignature = nil

local function updateWeaponHud()
    if not equippedWeapon then
        if lastHudSignature ~= 'none' then SendNUIMessage({ type = 'equippedWeapon', weapon = false }) end
        lastHudSignature = 'none'
        return
    end
    local weaponName = equippedWeapon.name or equippedWeapon.weapon
    local definition = TSSItems and TSSItems[weaponName] or {}
    local image = equippedWeapon.image or definition.image
    local label = equippedWeapon.label or definition.label or weaponName
    local showAmmo = equippedWeapon.clipSize > 0 and equippedWeapon.ammoMode ~= 'melee' and equippedWeapon.ammoMode ~= 'rechargeable'
    local signature = table.concat({ weaponName, image or '', label, tostring(equippedWeapon.ammo), tostring(equippedWeapon.clipSize), tostring(showAmmo) }, '|')
    if signature == lastHudSignature then return end
    lastHudSignature = signature
    SendNUIMessage({ type = 'equippedWeapon', weapon = { name = weaponName, label = label,
        image = image, ammo = equippedWeapon.ammo, clipSize = equippedWeapon.clipSize, showAmmo = showAmmo } })
end

local function setWeaponAmmo(playerPed, state)
    SetPedAmmo(playerPed, state.hash, state.ammo)
    if state.clipSize > 0 then SetAmmoInClip(playerPed, state.hash, state.ammo) end
end

local function reportAmmo()
    if not equippedWeapon or reloadPending or equippedWeapon.clipSize == 0 then return end
    local playerPed = PlayerPedId()
    local ammo = GetAmmoInPedWeapon(playerPed, equippedWeapon.hash)
    if ammo > equippedWeapon.ammo then
        setWeaponAmmo(playerPed, equippedWeapon)
    elseif ammo < equippedWeapon.ammo then
        equippedWeapon.ammo = ammo
        updateWeaponHud()
        TriggerServerEvent('tss-inventory:weaponAmmo', equippedWeapon.token, ammo)
    end
end

TSSInventoryClient = TSSInventoryClient or {}
TSSInventoryClient.FlushWeaponAmmo = reportAmmo

local function clearWeapon()
    if equippedWeapon and equippedPed and DoesEntityExist(equippedPed) then
        if equippedWeapon.ammoMode == 'rechargeable' then SetPedInfiniteAmmo(equippedPed, false, equippedWeapon.hash) end
        RemoveWeaponFromPed(equippedPed, equippedWeapon.hash)
        SetCurrentPedWeapon(equippedPed, joaat('weapon_unarmed'), true)
        SetPedCanSwitchWeapon(equippedPed, true)
    end
    equippedWeapon = nil
    equippedPed = nil
    reloadPending = false
    wasShooting = false
    SetWeaponsNoAutoreload(false)
    SetWeaponsNoAutoswap(false)
    updateWeaponHud()
end

local function syncExpandedClipAmmo(playerPed, state)
    reloadPending = true
    local weaponHash = state.hash
    local magazineName = state.magazineComponent
    local magazineHash = magazineName and joaat(magazineName)
    local stockName = magazineName and magazineName:match('^(.*_CLIP_)0[23]$')
    local stockHash = stockName and joaat(stockName .. '01')
    CreateThread(function()
        local deadline = GetGameTimer() + 250
        local repairedMagazine = false
        Wait(0)
        while equippedWeapon == state and PlayerPedId() == playerPed do
            -- GTA can keep the default clip active even after an upgrade was given.
            local capacity = GetMaxAmmoInClip(playerPed, weaponHash, true)
            if magazineHash and capacity < state.ammo and not repairedMagazine
                and DoesWeaponTakeWeaponComponent(weaponHash, magazineHash) then
                if HasPedGotWeaponComponent(playerPed, weaponHash, magazineHash) then
                    RemoveWeaponComponentFromPed(playerPed, weaponHash, magazineHash)
                end
                if stockHash and HasPedGotWeaponComponent(playerPed, weaponHash, stockHash) then
                    RemoveWeaponComponentFromPed(playerPed, weaponHash, stockHash)
                end
                GiveWeaponComponentToPed(playerPed, weaponHash, magazineHash)
                repairedMagazine = true
                Wait(0)
                if equippedWeapon ~= state or PlayerPedId() ~= playerPed then return end
            end

            SetPedAmmo(playerPed, weaponHash, state.ammo)
            RefillAmmoInstantly(playerPed)
            local _, refilledAmmo = GetAmmoInClip(playerPed, weaponHash)
            if refilledAmmo ~= state.ammo then SetAmmoInClip(playerPed, weaponHash, state.ammo) end

            Wait(0)
            if equippedWeapon ~= state or PlayerPedId() ~= playerPed then return end
            local foundClip, clipAmmo = GetAmmoInClip(playerPed, weaponHash)
            local totalAmmo = GetAmmoInPedWeapon(playerPed, weaponHash)
            if foundClip and clipAmmo == state.ammo and totalAmmo == state.ammo then
                reloadPending = false
                return
            end
            if GetGameTimer() >= deadline then
                -- A native clip limit is not a shot. Keep the saved ammo and holster.
                local magazineInstalled = magazineHash and HasPedGotWeaponComponent(playerPed, weaponHash, magazineHash)
                print(('[tss-inventory] Could not load %d rounds into %s (component: %s, installed: %s, capacity: %d, clip: %s, total: %d)')
                    :format(state.ammo, state.weapon, magazineName or 'none', tostring(magazineInstalled == true),
                        GetMaxAmmoInClip(playerPed, weaponHash, true), tostring(clipAmmo), totalAmmo))
                TriggerServerEvent('tss-inventory:weaponInvalid', state.token, true)
                clearWeapon()
                return
            end
        end
    end)
end

RegisterNetEvent('tss-inventory:weapon', function(state)
    if source ~= 65535 then return end
    if not state then clearWeapon(); return end
    local hash = joaat(state.weapon)
    if not IsWeaponValid(hash) then
        TriggerServerEvent('tss-inventory:weaponInvalid', state.token)
        return
    end
    local playerPed = PlayerPedId()
    local definition = TSSItems and TSSItems[state.name]
    local baseClipSize = definition and definition.clipSize
    local needsExpandedClip = state.ammoMode == 'firearm' and baseClipSize and state.ammo > baseClipSize
    local sameWeapon = equippedWeapon and equippedWeapon.token == state.token and equippedPed == playerPed
    local previousComponents = sameWeapon and equippedWeapon.components or {}
    if not sameWeapon then clearWeapon() end
    state.hash = hash
    equippedWeapon = state
    equippedPed = playerPed
    reloadPending = false
    SetWeaponsNoAutoreload(true)
    SetWeaponsNoAutoswap(true)
    SetPedCanSwitchWeapon(playerPed, false)
    if not sameWeapon then
        local isFirearm = state.ammoMode == 'firearm'
        local initialAmmo = isFirearm and 0 or state.ammo
        if state.ammoMode == 'rechargeable' then initialAmmo = 1 end
        GiveWeaponToPed(playerPed, hash, initialAmmo, false, not isFirearm)
    end
    local previousSet, currentSet = {}, {}
    for _, component in ipairs(previousComponents or {}) do previousSet[component] = true end
    for _, component in ipairs(state.components or {}) do currentSet[component] = true end
    for component in pairs(previousSet) do
        if not currentSet[component] then RemoveWeaponComponentFromPed(playerPed, hash, joaat(component)) end
    end
    for component in pairs(currentSet) do
        local componentHash = joaat(component)
        if not previousSet[component] and DoesWeaponTakeWeaponComponent(hash, componentHash) then
            GiveWeaponComponentToPed(playerPed, hash, componentHash)
        end
    end
    if not sameWeapon then SetCurrentPedWeapon(playerPed, hash, true) end
    local tint = state.tint or 0
    if tint >= 0 and tint < GetWeaponTintCount(hash) then SetPedWeaponTintIndex(playerPed, hash, tint) end
    if state.ammoMode == 'rechargeable' then
        SetPedInfiniteAmmo(playerPed, true, hash)
    elseif state.reloading then
        reloadPending = true
        if state.magazineSwap then SetAmmoInClip(playerPed, hash, 0) end
        SetPedAmmo(playerPed, hash, state.ammo)
        TaskReloadWeapon(playerPed, true)
        SetTimeout(state.reloadDuration, function()
            if equippedWeapon ~= state or PlayerPedId() ~= playerPed then return end
            if needsExpandedClip then
                syncExpandedClipAmmo(playerPed, state)
            else
                setWeaponAmmo(playerPed, state)
                reloadPending = false
            end
        end)
    elseif needsExpandedClip then
        syncExpandedClipAmmo(playerPed, state)
    else
        setWeaponAmmo(playerPed, state)
    end
    updateWeaponHud()
end)

CreateThread(function()
    while true do
        Wait(equippedWeapon and 0 or 250)
        -- Equipment can be cleared by a server event while this thread is waiting.
        if equippedWeapon then
            local playerPed = PlayerPedId()
            local isShooting = IsPedShooting(playerPed)
            if equippedWeapon.ammoMode == 'rechargeable' and isShooting and not wasShooting
                and not reloadPending and not IsNuiFocused() then
                TriggerServerEvent('tss-inventory:weaponShot', equippedWeapon.token)
            end
            wasShooting = isShooting
            DisableControlAction(0, 37, true)
            DisableControlAction(0, 45, true)
            if reloadPending or IsNuiFocused() then DisablePlayerFiring(PlayerId(), true) end
            if IsEntityDead(playerPed) or equippedPed ~= playerPed then
                reportAmmo()
                TriggerServerEvent('tss-inventory:weaponHolster', equippedWeapon.token)
                clearWeapon()
            elseif not IsNuiFocused() and IsDisabledControlJustPressed(0, 45) and not reloadPending
                and not (TSSInventoryClient.Throwing and TSSInventoryClient.Throwing.IsHolding()) then
                reportAmmo()
                TriggerServerEvent('tss-inventory:weaponReload', equippedWeapon.token, GetAmmoInPedWeapon(playerPed, equippedWeapon.hash))
            elseif GetGameTimer() - lastReport >= 200 then
                lastReport = GetGameTimer()
                reportAmmo()
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then clearWeapon() end
end)
