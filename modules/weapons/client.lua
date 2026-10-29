if not Config.EnableWeaponSystem then return end

local equippedWeapon
local equippedPed
local reloadPending = false
local lastReport = 0
local wasShooting = false

local function reportAmmo()
    if not equippedWeapon or reloadPending or equippedWeapon.clipSize == 0 then return end
    local ammo = GetAmmoInPedWeapon(PlayerPedId(), equippedWeapon.hash)
    if ammo > equippedWeapon.ammo then
        SetPedAmmo(PlayerPedId(), equippedWeapon.hash, equippedWeapon.ammo)
        SetAmmoInClip(PlayerPedId(), equippedWeapon.hash, equippedWeapon.ammo)
    elseif ammo < equippedWeapon.ammo then
        equippedWeapon.ammo = ammo
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
    local sameWeapon = equippedWeapon and equippedWeapon.token == state.token
    local previousComponents = sameWeapon and equippedWeapon.components or {}
    if not sameWeapon then clearWeapon() end
    state.hash = hash
    equippedWeapon = state
    equippedPed = playerPed
    SetWeaponsNoAutoreload(true)
    SetWeaponsNoAutoswap(true)
    SetPedCanSwitchWeapon(playerPed, false)
    if not sameWeapon then
        GiveWeaponToPed(playerPed, hash, state.ammoMode == 'rechargeable' and 1 or state.ammo, false, true)
        SetCurrentPedWeapon(playerPed, hash, true)
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
    local tint = state.tint or 0
    if tint >= 0 and tint < GetWeaponTintCount(hash) then SetPedWeaponTintIndex(playerPed, hash, tint) end
    if state.ammoMode == 'rechargeable' then SetPedInfiniteAmmo(playerPed, true, hash)
    elseif not state.reloading then
        SetPedAmmo(playerPed, hash, state.ammo)
        if state.clipSize > 0 then SetAmmoInClip(playerPed, hash, state.ammo) end
    end
    if state.reloading then
        reloadPending = true
        SetPedAmmo(playerPed, hash, state.ammo)
        TaskReloadWeapon(playerPed, true)
        local token = state.token
        SetTimeout(state.reloadDuration, function()
            if equippedWeapon and equippedWeapon.token == token then
                SetPedAmmo(playerPed, hash, state.ammo)
                SetAmmoInClip(playerPed, hash, state.ammo)
                reloadPending = false
            end
        end)
    end
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
            elseif not IsNuiFocused() and IsDisabledControlJustPressed(0, 45) and not reloadPending then
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
