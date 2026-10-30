local heldItem = nil
local projectiles = {}
local animationDictionary = 'weapons@projectile@'
local bridge = exports.tss_bridge:GetModules({ 'TextUI' }, Config.TSS)
local controlText = '[E] Use   Hold [R] to throw'
local controlsVisible = false
local controlsRunning = false
local throwingUntil = 0
local startControls
local combatControls = { 24, 25, 37, 45, 140, 141, 142, 143, 257, 263, 264 }
local powerVisible = false

local function hideThrowPower()
    if not powerVisible then return end
    powerVisible = false
    SendNUIMessage({ type = 'throwPower', visible = false })
end

local function stopChargePose(held)
    if held and held.poseStarted then
        StopAnimTask(held.playerPed, animationDictionary, 'aim_m', 4.0)
        held.poseStarted = false
    end
end

local function updateChargePose(held)
    if not held.poseStarted and HasAnimDictLoaded(animationDictionary) then
        TaskPlayAnim(held.playerPed, animationDictionary, 'aim_m', 8.0, -4.0, -1, 49, 0.0, false, false, false)
        held.poseStarted = true
    end
    local now = GetGameTimer()
    if now < (held.nextChargeUpdate or 0) then return end
    held.nextChargeUpdate = now + 50
    SetEntityHeading(held.playerPed, GetGameplayCamRot(2).z)
    if held.pending then return end
    local settings = TSSThrowing.Settings()
    local power = TSSThrowing.Power(now - held.chargeStarted) / settings.maxPower
    local percentage = math.floor(power * 100 + 0.5)
    if percentage ~= held.lastPowerPercentage then
        held.lastPowerPercentage = percentage
        powerVisible = true
        SendNUIMessage({ type = 'throwPower', visible = true, power = percentage / 100 })
    end
end

local function hideControls()
    if not controlsVisible then return end
    local isOpen, display = bridge.TextUI.IsOpen()
    if isOpen and display and display.text == controlText then bridge.TextUI.Hide() end
    controlsVisible = false
end

TSSInventoryClient = TSSInventoryClient or {}
TSSInventoryClient.Throwing = {
    IsHolding = function() return heldItem ~= nil or GetGameTimer() < throwingUntil end,
}

local function removeObject(object)
    if object and DoesEntityExist(object) then
        SetEntityAsMissionEntity(object, true, true)
        DeleteEntity(object)
    end
end

local function clearHand(notifyServer)
    local previous = heldItem
    heldItem = nil
    hideControls()
    hideThrowPower()
    stopChargePose(previous)
    if not previous then return end
    removeObject(previous.object)
    if notifyServer then TriggerServerEvent('tss-inventory:heldAction', previous.token, 'cancel') end
end

local function cameraDirection()
    local rotation = GetGameplayCamRot(2)
    local pitch, yaw = math.rad(rotation.x), math.rad(rotation.z)
    return { x = -math.sin(yaw) * math.cos(pitch), y = math.cos(yaw) * math.cos(pitch), z = math.sin(pitch) }
end

RegisterNetEvent('tss-inventory:heldItem', function(state)
    if source ~= 65535 then return end
    clearHand(false)
    if not state then return end
    local definition = state.item.definition
    local model = type(definition.weapon) == 'string' and GetWeapontypeModel(joaat(definition.weapon))
        or definition.throwModel or Config.WorldDrops.prop
    if type(model) == 'string' then model = joaat(model) end
    if not model or model == 0 or not IsModelInCdimage(model) or not IsModelValid(model) then
        TriggerServerEvent('tss-inventory:heldAction', state.token, 'cancel')
        return
    end
    local held = { token = state.token, playerPed = PlayerPedId(), loading = true }
    heldItem = held
    startControls()
    CreateThread(function()
        RequestModel(model)
        RequestAnimDict(animationDictionary)
        local deadline = GetGameTimer() + 2500
        while heldItem == held and not HasModelLoaded(model) and GetGameTimer() < deadline do Wait(0) end
        if heldItem ~= held then SetModelAsNoLongerNeeded(model); return end
        if not HasModelLoaded(model) then clearHand(true); SetModelAsNoLongerNeeded(model); return end
        local position = GetEntityCoords(held.playerPed)
        held.object = CreateObjectNoOffset(model, position.x, position.y, position.z, true, true, false)
        SetModelAsNoLongerNeeded(model)
        if not held.object or held.object == 0 then clearHand(true); return end
        SetEntityCollision(held.object, false, false)
        AttachEntityToEntity(held.object, held.playerPed, GetPedBoneIndex(held.playerPed, 57005),
            0.12, 0.02, -0.02, -90.0, 0.0, 0.0, true, true, false, true, 1, true)
        held.loading = false
        local idleTimeout = TSSThrowing.Settings().idleTimeout
        held.expiresAt = idleTimeout > 0 and GetGameTimer() + idleTimeout or nil
        TriggerServerEvent('tss-inventory:heldReady', held.token)
        bridge.TextUI.Show({ text = controlText, position = 'bottom-center' })
        controlsVisible = true
        SetTimeout(3000, function()
            if heldItem == held then hideControls() end
        end)
    end)
end)

RegisterNetEvent('tss-inventory:throwItem', function(state)
    if source ~= 65535 then return end
    local held = heldItem
    if not held or held.token ~= state.token or not held.object then return end
    throwingUntil = GetGameTimer() + 1600
    stopChargePose(held)
    heldItem = nil
    hideControls()
    hideThrowPower()
    startControls()
    projectiles[held.object] = true
    CreateThread(function()
        local direction = state.direction
        local playerPed = held.playerPed
        local animationDeadline = GetGameTimer() + 500
        while not HasAnimDictLoaded(animationDictionary) and GetGameTimer() < animationDeadline do Wait(0) end
        SetEntityHeading(playerPed, math.deg(math.atan(-direction.x, direction.y)))
        if HasAnimDictLoaded(animationDictionary) then
            ClearPedTasks(playerPed)
            TaskPlayAnim(playerPed, animationDictionary, 'throw_m_fb_stand', 8.0, -8.0, 900, 0, 0.0, false, false, false)
        end
        Wait(300)
        if not DoesEntityExist(held.object) then projectiles[held.object] = nil; return end
        DetachEntity(held.object, true, true)
        SetEntityCollision(held.object, true, true)
        SetEntityNoCollisionEntity(held.object, playerPed, false)
        SetEntityDynamic(held.object, true)
        SetEntityHasGravity(held.object, true)
        ActivatePhysics(held.object)
        local velocity = TSSThrowing.Velocity(direction, state.power)
        SetEntityVelocity(held.object, velocity.x, velocity.y, velocity.z)
        local launchedAt = GetGameTimer()
        local stableTicks = 0
        while DoesEntityExist(held.object) and GetGameTimer() - launchedAt < 6000 do
            Wait(100)
            if GetGameTimer() - launchedAt > 400 and HasEntityCollidedWithAnything(held.object)
                and GetEntitySpeed(held.object) < 0.8 then stableTicks = stableTicks + 1 else stableTicks = 0 end
            if stableTicks >= 2 then break end
        end
        if DoesEntityExist(held.object) then
            local position = GetEntityCoords(held.object)
            if stableTicks >= 2 then
                TriggerServerEvent('tss-inventory:throwLanded', held.token, { x = position.x, y = position.y, z = position.z })
            end
            Wait(150)
            removeObject(held.object)
        end
        projectiles[held.object] = nil
    end)
end)

startControls = function()
    if controlsRunning then return end
    controlsRunning = true
    CreateThread(function()
        while heldItem or GetGameTimer() < throwingUntil do
            DisablePlayerFiring(PlayerId(), true)
            for _, control in ipairs(combatControls) do DisableControlAction(0, control, true) end
            DisableControlAction(0, 38, true)
            DisableControlAction(0, 23, true)
            local held = heldItem
            if held then
                if held.chargeStarted then updateChargePose(held) end
                if held.playerPed ~= PlayerPedId() or IsEntityDead(held.playerPed) or IsPedInAnyVehicle(held.playerPed, false)
                    or IsNuiFocused() or (held.expiresAt and GetGameTimer() >= held.expiresAt) then
                    clearHand(true)
                elseif not held.loading and not held.pending then
                    if held.chargeStarted then
                        if IsDisabledControlJustReleased(0, 45) or not IsDisabledControlPressed(0, 45) then
                            held.pending = true
                            hideControls()
                            hideThrowPower()
                            TriggerServerEvent('tss-inventory:heldAction', held.token, 'throw', cameraDirection())
                        end
                    elseif IsDisabledControlJustPressed(0, 38) then
                        held.pending = true
                        hideControls()
                        TriggerServerEvent('tss-inventory:heldAction', held.token, 'use')
                    elseif IsDisabledControlJustPressed(0, 45) then
                        held.chargeStarted = GetGameTimer()
                        local chargeTimeout = TSSThrowing.Settings().chargeTimeout
                        held.expiresAt = chargeTimeout > 0 and GetGameTimer() + chargeTimeout or nil
                        hideControls()
                        updateChargePose(held)
                        TriggerServerEvent('tss-inventory:heldAction', held.token, 'charge')
                    end
                end
            end
            Wait(0)
        end
        controlsRunning = false
    end)
end

RegisterNetEvent('tss-inventory:ownSnapshot', function(inventory)
    if source == 65535 and not inventory then clearHand(true) end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    clearHand(false)
    for object in pairs(projectiles) do removeObject(object) end
    RemoveAnimDict(animationDictionary)
end)
