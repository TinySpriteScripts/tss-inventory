-- Local inspection object only. Equipment and attachment ownership remain server-owned.
if not Config.EnableWeaponSystem then return end

TSSInventoryClient = TSSInventoryClient or {}
local preview = {}
TSSInventoryClient.WeaponPreview = preview

local currentPreview
local positionObject
local modelReferences = {}

local function retainModel(model)
    modelReferences[model] = (modelReferences[model] or 0) + 1
    RequestModel(model)
end

local function releaseModel(model)
    local references = (modelReferences[model] or 1) - 1
    if references > 0 then modelReferences[model] = references
    else modelReferences[model] = nil; SetModelAsNoLongerNeeded(model) end
end

local function scaledDirection(direction, scale)
    local length = math.sqrt(direction.x * direction.x + direction.y * direction.y + direction.z * direction.z)
    return direction * (scale / math.max(length, 0.0001))
end

local function deleteDragModel(state)
    local drag = state.drag
    state.drag = nil
    if drag and drag.object and DoesEntityExist(drag.object) then DeleteEntity(drag.object) end
end

local slotAnchors = {
    magazine = { bones = { 'WAPClip', 'gun_magazine', 'gun_ammo' }, offset = { 0.46, 0.5, 0.18 } },
    muzzle = { bones = { 'WAPSupp', 'gun_muzzle', 'Gun_Nuzzle' }, offset = { 0.98, 0.5, 0.65 } },
    scope = { bones = { 'WAPScop', 'gun_scope' }, offset = { 0.48, 0.5, 0.95 } },
    light = { bones = { 'WAPFlsh', 'gun_torch' }, offset = { 0.74, 0.5, 0.42 } },
    grip = { bones = { 'WAPGrip', 'gun_grip' }, offset = { 0.62, 0.5, 0.18 } },
    barrel = { bones = { 'WAPBarrel', 'gun_barrels' }, offset = { 0.82, 0.5, 0.65 } },
    finish = { bones = {}, offset = { 0.24, 0.5, 0.58 } },
    tint = { bones = {}, offset = { 0.15, 0.5, 0.72 } },
}

local function sendStatus(state, status, message)
    if currentPreview ~= state then return end
    SendNUIMessage({ type = 'weaponPreview', inventoryId = state.panel.inventoryId,
        itemId = state.panel.itemId, status = status, message = message })
end

function preview.Close()
    local previous = currentPreview
    currentPreview = nil
    if not previous then return end
    if previous.paint then previous.paint.Destroy() end
    deleteDragModel(previous)
    if previous.camera then
        if GetRenderingCam() == previous.camera then
            if previous.previousCamera and previous.previousCamera ~= -1 and DoesCamExist(previous.previousCamera) then
                SetCamActive(previous.previousCamera, true)
            else RenderScriptCams(false, false, 0, true, true) end
        end
        SetCamActive(previous.camera, false)
        DestroyCam(previous.camera, false)
    end
    if previous.object and DoesEntityExist(previous.object) then DeleteEntity(previous.object) end
    if previous.hash then RemoveWeaponAsset(previous.hash) end
end

local function updateComponents(state)
    local components, tint = TSSWeaponData.Components(state.panel.weapon)
    local signature = table.concat(components, '|') .. ':' .. tostring(tint or 0)
    if state.appearanceSignature == signature then return end
    state.appearanceSignature = signature
    state.appearanceVersion = (state.appearanceVersion or 0) + 1
    local version = state.appearanceVersion
    CreateThread(function()
        local models, wanted, customModel = {}, {}, 0
        local function releaseModels()
            for model in pairs(models) do releaseModel(model) end
        end
        for _, component in ipairs(components) do
            local model = GetWeaponComponentTypeModel(joaat(component))
            if model and model ~= 0 and IsModelValid(model) and not models[model] then
                models[model] = true
                retainModel(model)
            end
            -- VARMOD finishes replace the weapon model rather than adding a mesh.
            if component:find('_VARMOD_', 1, true) then customModel = model or 0
            else wanted[component] = true end
        end
        local deadline = GetGameTimer() + 5000
        for model in pairs(models) do
            while currentPreview == state and state.appearanceVersion == version
                and not HasModelLoaded(model) and GetGameTimer() < deadline do Wait(0) end
            if currentPreview ~= state or state.appearanceVersion ~= version then releaseModels(); return end
            if not HasModelLoaded(model) then
                state.appearanceSignature = nil
                releaseModels()
                return
            end
        end
        if currentPreview ~= state or state.appearanceVersion ~= version then releaseModels(); return end
        if customModel ~= (state.customModel or 0) then
            local replacement = CreateWeaponObject(state.hash, 0, state.position.x, state.position.y, state.position.z,
                true, state.scale, customModel, false, false)
            if replacement == 0 then state.appearanceSignature = nil; releaseModels(); return end
            local previousObject = state.object
            state.object = replacement
            state.customModel = customModel
            state.components = {}
            state.anchorBindings = {}
            SetEntityAsMissionEntity(replacement, true, true)
            SetEntityCollision(replacement, false, false)
            FreezeEntityPosition(replacement, true)
            SetEntityInvincible(replacement, true)
            SetEntityLodDist(replacement, 1000)
            RequestWeaponHighDetailModel(replacement)
            positionObject(state)
            if previousObject and DoesEntityExist(previousObject) then DeleteEntity(previousObject) end
        end
        for component in pairs(state.components or {}) do
            if not wanted[component] then RemoveWeaponComponentFromWeaponObject(state.object, joaat(component)) end
        end
        for component in pairs(wanted) do
            if not (state.components or {})[component] then
                GiveWeaponComponentToWeaponObject(state.object, joaat(component))
            end
        end
        state.components = wanted
        SetWeaponObjectTintIndex(state.object, tint or 0)
        state.anchorBindings = {}
        state.projectionDirty = true
        if state.paint then state.paint.Refresh() end
        releaseModels()
    end)
end

positionObject = function(state)
    SetEntityRotation(state.object, state.pitch, state.roll, state.yaw, 2, true)
    -- Keep the model's centre fixed even when its origin is at the grip.
    local forward, right, up = GetEntityMatrix(state.object)
    local position = state.position - right * (state.centre.x * state.scale)
        - forward * (state.centre.y * state.scale) - up * (state.centre.z * state.scale)
    SetEntityCoordsNoOffset(state.object, position.x, position.y, position.z, false, false, false)
    state.projectionDirty = true
    state.orientationVersion = (state.orientationVersion or 0) + 1
end

local function moveRotationCursor(state, cursorX, cursorY)
    local rotation = state.rotation
    if not rotation then return end
    local deltaX, deltaY = cursorX - rotation.lastX, cursorY - rotation.lastY
    rotation.lastX, rotation.lastY = cursorX, cursorY
    if deltaX == 0 and deltaY == 0 then return end
    state.yaw = (state.yaw + deltaX * 0.45) % 360
    state.roll = math.max(-85, math.min(85, state.roll + deltaY * 0.4))
    positionObject(state)
end

local function anchorPosition(state, slotId)
    local cached = state.anchorBindings[slotId]
    if cached then
        if cached.boneIndex then return GetWorldPositionOfEntityBone(state.object, cached.boneIndex) end
        return GetOffsetFromEntityInWorldCoords(state.object, cached.x, cached.y, cached.z)
    end
    local anchor = slotAnchors[slotId]
    if not anchor then return state.position end
    -- Optional per-model offsets can override the generic fallback for addon weapons.
    local definition = TSSItems[state.panel.weapon.name]
    local customOffset = definition and definition.attachmentAnchors and definition.attachmentAnchors[slotId]
    if type(customOffset) == 'table' and type(customOffset.x) == 'number'
        and type(customOffset.y) == 'number' and type(customOffset.z) == 'number' then
        cached = { x = customOffset.x * state.scale, y = customOffset.y * state.scale, z = customOffset.z * state.scale }
        state.anchorBindings[slotId] = cached
        return GetOffsetFromEntityInWorldCoords(state.object, cached.x, cached.y, cached.z)
    end
    for _, boneName in ipairs(anchor.bones) do
        local boneIndex = GetEntityBoneIndexByName(state.object, boneName)
        if boneIndex ~= -1 then
            state.anchorBindings[slotId] = { boneIndex = boneIndex }
            return GetWorldPositionOfEntityBone(state.object, boneIndex)
        end
    end
    local minimum, maximum = state.minimum, state.maximum
    local offset = anchor.offset
    cached = { x = (minimum.x + (maximum.x - minimum.x) * offset[1]) * state.scale,
        y = (minimum.y + (maximum.y - minimum.y) * offset[2]) * state.scale,
        z = (minimum.z + (maximum.z - minimum.z) * offset[3]) * state.scale }
    state.anchorBindings[slotId] = cached
    return GetOffsetFromEntityInWorldCoords(state.object, cached.x, cached.y, cached.z)
end

function preview.PaintApplied(inventoryId, itemId, slotId)
    local state = currentPreview
    if not state or not state.object or inventoryId ~= state.panel.inventoryId or itemId ~= state.panel.itemId
        or (slotId ~= 'finish' and slotId ~= 'tint') then return end
    local installed = TSSWeaponData.Installed(state.panel.weapon)[slotId]
    if not installed or not TSSWeaponPaint then return end
    state.paint = state.paint or TSSWeaponPaint.Create()
    state.paint.Play(function()
        return state.object, state.centre * state.scale, math.max(0.04, state.previewSpan * 0.3)
    end)
end

function preview.Open(panel)
    if type(panel) ~= 'table' then preview.Close(); return end
    local definition = panel.weapon and TSSItems[panel.weapon.name]
    if not definition or not definition.weapon then preview.Close(); return end
    if currentPreview and currentPreview.panel.inventoryId == panel.inventoryId
        and currentPreview.panel.itemId == panel.itemId and currentPreview.panel.weapon.name == panel.weapon.name then
        currentPreview.panel = panel
        if currentPreview.object then updateComponents(currentPreview) end
        return
    end
    preview.Close()
    local state = { panel = panel, hash = joaat(definition.weapon),
        pitch = 0, roll = 0, yaw = 0, components = {}, anchorBindings = {}, lastProjection = 0 }
    currentPreview = state
    sendStatus(state, 'loading')
    CreateThread(function()
        if not IsWeaponValid(state.hash) then sendStatus(state, 'error', 'Weapon model unavailable'); return end
        RequestWeaponAsset(state.hash, 31, 0)
        local deadline = GetGameTimer() + 5000
        while currentPreview == state and not HasWeaponAssetLoaded(state.hash) and GetGameTimer() < deadline do Wait(0) end
        if currentPreview ~= state then return end
        if not HasWeaponAssetLoaded(state.hash) then sendStatus(state, 'error', 'Weapon model could not load'); return end

        local cameraPosition = GetGameplayCamCoord()
        local cameraRotation = GetGameplayCamRot(2)
        local cameraFov = GetGameplayCamFov()
        state.aspectRatio = GetAspectRatio(false)
        local yawRadians, pitchRadians = math.rad(cameraRotation.z), math.rad(cameraRotation.x)
        local forward = vector3(-math.sin(yawRadians) * math.cos(pitchRadians),
            math.cos(yawRadians) * math.cos(pitchRadians), math.sin(pitchRadians))
        local right = vector3(math.cos(yawRadians), math.sin(yawRadians), 0)
        -- A close camera-space prop keeps the original scene behind the UI.
        local modelHash = GetWeapontypeModel(state.hash)
        state.minimum, state.maximum = GetModelDimensions(modelHash)
        state.centre = (state.minimum + state.maximum) * 0.5
        local longestEdge = math.max(state.maximum.x - state.minimum.x, state.maximum.y - state.minimum.y,
            state.maximum.z - state.minimum.z, 0.1)
        local scale = math.min(4.0, 0.65 / longestEdge) * 0.8
        state.scale = scale
        state.previewSpan = longestEdge * scale
        local depth = 0.85
        local horizontalOffset = 0.30 * depth * math.tan(math.rad(cameraFov * 0.5)) * state.aspectRatio
        state.position = cameraPosition + forward * depth + right * horizontalOffset
        state.cameraPosition = cameraPosition
        state.forward = forward
        state.right = right
        state.up = vector3(math.sin(yawRadians) * math.sin(pitchRadians),
            -math.cos(yawRadians) * math.sin(pitchRadians), math.cos(pitchRadians))
        state.cameraFov = cameraFov
        state.yaw = cameraRotation.z
        state.pitch = cameraRotation.x
        state.object = CreateWeaponObject(state.hash, 0, state.position.x, state.position.y, state.position.z,
            true, scale, 0, false, false)
        if not state.object or state.object == 0 then
            state.object = nil
            sendStatus(state, 'error', 'Weapon model could not be created')
            return
        end
        SetEntityAsMissionEntity(state.object, true, true)
        SetEntityCollision(state.object, false, false)
        FreezeEntityPosition(state.object, true)
        SetEntityInvincible(state.object, true)
        SetEntityLodDist(state.object, 1000)
        RequestWeaponHighDetailModel(state.object)
        updateComponents(state)
        positionObject(state)
        state.previousCamera = GetRenderingCam()
        state.camera = CreateCam('DEFAULT_SCRIPTED_CAMERA', false)
        SetCamCoord(state.camera, cameraPosition.x, cameraPosition.y, cameraPosition.z)
        SetCamRot(state.camera, cameraRotation.x, cameraRotation.y, cameraRotation.z, 2)
        SetCamFov(state.camera, cameraFov)
        SetCamNearClip(state.camera, 0.01)
        SetCamActive(state.camera, true)
        RenderScriptCams(true, false, 0, true, true)
        state.lightPosition = cameraPosition + right * 0.3 + vector3(0, 0, 0.4)
        sendStatus(state, 'ready')
    end)
end

RegisterNUICallback('rotateWeaponPreview', function(request, callback)
    local state = currentPreview
    if not state or not state.object or request.inventoryId ~= state.panel.inventoryId
        or request.itemId ~= state.panel.itemId then callback({ ok = false }); return end
    if request.active ~= nil then
        if type(request.pointerX) ~= 'number' or type(request.pointerY) ~= 'number'
            or request.pointerX ~= request.pointerX or request.pointerY ~= request.pointerY then
            callback({ ok = false }); return
        end
        if request.active == true then
            local screenWidth, screenHeight = GetActiveScreenResolution()
            local viewportWidth = tonumber(request.viewportWidth) or screenWidth
            local viewportHeight = tonumber(request.viewportHeight) or screenHeight
            state.rotation = { lastX = request.pointerX, lastY = request.pointerY,
                scaleX = viewportWidth / math.max(1, screenWidth), scaleY = viewportHeight / math.max(1, screenHeight) }
        else
            moveRotationCursor(state, request.pointerX, request.pointerY)
            state.rotation = nil
            state.projectionDirty = true
            state.lastProjection = 0
        end
        callback({ ok = true }); return
    end
    local deltaX, deltaY = request.deltaX, request.deltaY
    if not state or not state.object or request.inventoryId ~= state.panel.inventoryId
        or request.itemId ~= state.panel.itemId or type(deltaX) ~= 'number' or type(deltaY) ~= 'number'
        or deltaX ~= deltaX or deltaY ~= deltaY then callback({ ok = false }); return end
    state.yaw = (state.yaw + math.max(-100, math.min(100, deltaX)) * 0.45) % 360
    state.roll = math.max(-85, math.min(85, state.roll + math.max(-100, math.min(100, deltaY)) * 0.4))
    positionObject(state)
    callback({ ok = true })
end)

RegisterNUICallback('weaponPreviewViewport', function(request, callback)
    local state = currentPreview
    if not state or not state.camera or request.inventoryId ~= state.panel.inventoryId
        or request.itemId ~= state.panel.itemId then callback({ ok = false }); return end
    state.aspectRatio = GetAspectRatio(false)
    local depth = 0.85
    local horizontalOffset = 0.30 * depth * math.tan(math.rad(state.cameraFov * 0.5)) * state.aspectRatio
    state.position = state.cameraPosition + state.forward * depth + state.right * horizontalOffset
    positionObject(state)
    callback({ ok = true })
end)

RegisterNUICallback('closeWeaponPreview', function(_, callback)
    preview.Close()
    callback({ ok = true })
end)

RegisterNUICallback('weaponPreviewDrag', function(request, callback)
    local state = currentPreview
    if not state or not state.object then callback({ ok = false }); return end
    if request.active ~= true then deleteDragModel(state); callback({ ok = true }); return end
    if request.inventoryId ~= state.panel.inventoryId or request.itemId ~= state.panel.itemId
        or type(request.pointerX) ~= 'number' or type(request.pointerY) ~= 'number'
        or request.pointerX ~= request.pointerX or request.pointerY ~= request.pointerY then
        callback({ ok = false }); return
    end
    local attachment = TSSWeaponData.Attachment(state.panel.weapon.name, request.attachmentName)
    if not attachment then deleteDragModel(state); callback({ ok = false }); return end
    local pointerX = math.max(0, math.min(1, request.pointerX))
    local pointerY = math.max(0, math.min(1, request.pointerY))
    if state.drag and state.drag.name == request.attachmentName then
        if state.drag.pointerX ~= pointerX or state.drag.pointerY ~= pointerY then state.drag.transformDirty = true end
        state.drag.pointerX, state.drag.pointerY = pointerX, pointerY
        callback({ ok = true }); return
    end
    deleteDragModel(state)
    local isSprayCan = attachment.slot == 'finish' or attachment.slot == 'tint'
    local component = attachment.weapons and attachment.weapons[state.panel.weapon.name]
    local model = isSprayCan and joaat('prop_cs_spray_can') or (component and GetWeaponComponentTypeModel(joaat(component)))
    if not model or model == 0 or not IsModelValid(model) then callback({ ok = true, model = false }); return end
    local drag = { name = request.attachmentName, pointerX = pointerX, pointerY = pointerY,
        isSprayCan = isSprayCan, scale = isSprayCan and 0.5 or state.scale, transformDirty = true,
        spread = 0.74 * math.tan(math.rad(state.cameraFov * 0.5)) }
    state.drag = drag
    CreateThread(function()
        retainModel(model)
        local deadline = GetGameTimer() + 5000
        while currentPreview == state and state.drag == drag and not HasModelLoaded(model)
            and GetGameTimer() < deadline do Wait(0) end
        if currentPreview ~= state or state.drag ~= drag or not HasModelLoaded(model) then
            releaseModel(model)
            return
        end
        drag.object = CreateObjectNoOffset(model, state.position.x, state.position.y, state.position.z, false, false, false)
        if drag.object ~= 0 then
            SetEntityAsMissionEntity(drag.object, true, true)
            SetEntityCollision(drag.object, false, false)
            FreezeEntityPosition(drag.object, true)
            SetEntityInvincible(drag.object, true)
            SetEntityAlpha(drag.object, 210, false)
            SetEntityLodDist(drag.object, 1000)
            SendNUIMessage({ type = 'weaponDragModel', inventoryId = state.panel.inventoryId,
                itemId = state.panel.itemId, attachmentName = drag.name, ready = true })
        else drag.object = nil end
        releaseModel(model)
    end)
    callback({ ok = true })
end)

CreateThread(function()
    while true do
        Wait(currentPreview and currentPreview.object and 0 or 200)
        local state = currentPreview
        if state and state.object and DoesEntityExist(state.object) then
            if state.rotation then
                local cursorX, cursorY = GetNuiCursorPosition()
                moveRotationCursor(state, cursorX * state.rotation.scaleX, cursorY * state.rotation.scaleY)
            end
            local light = state.lightPosition
            DrawLightWithRange(light.x, light.y, light.z, 245, 240, 230, 3.0, 4.0)
            -- The inventory's input loop already blocks firing while this view is open.
            local drag = state.drag
            if drag and drag.object and (drag.transformDirty or drag.orientationVersion ~= state.orientationVersion) then
                local depth = 0.74
                local spread = drag.spread
                local position = state.cameraPosition + state.forward * depth
                    + state.right * ((drag.pointerX - 0.5) * 2 * spread * state.aspectRatio)
                    + state.up * ((0.5 - drag.pointerY) * 2 * spread)
                if drag.orientationVersion ~= state.orientationVersion then
                    SetEntityRotation(drag.object, drag.isSprayCan and 0 or state.pitch,
                        drag.isSprayCan and 0 or state.roll, state.yaw, 2, true)
                    local forward, right, up = GetEntityMatrix(drag.object)
                    drag.forward, drag.right, drag.up = scaledDirection(forward, drag.scale), scaledDirection(right, drag.scale), scaledDirection(up, drag.scale)
                    drag.orientationVersion = state.orientationVersion
                end
                SetEntityMatrix(drag.object, drag.forward.x, drag.forward.y, drag.forward.z,
                    drag.right.x, drag.right.y, drag.right.z, drag.up.x, drag.up.y, drag.up.z, position.x, position.y, position.z)
                drag.transformDirty = false
            end
            if state.projectionDirty and not state.rotation and GetGameTimer() - state.lastProjection >= 33 then
                local currentTime = GetGameTimer()
                state.lastProjection = currentTime
                local anchors = {}
                local hasInvisibleAnchor = false
                for _, slot in ipairs(state.panel.slots or {}) do
                    local position = anchorPosition(state, slot.id)
                    local visible, screenX, screenY = GetScreenCoordFromWorldCoord(position.x, position.y, position.z)
                    if visible then anchors[slot.id] = { x = screenX, y = screenY }
                    else hasInvisibleAnchor = true end
                end
                local changed = state.projectedAnchors == nil
                local previousAnchors = state.projectedAnchors or {}
                for slotId, anchor in pairs(anchors) do
                    local previousAnchor = previousAnchors[slotId]
                    if not previousAnchor or math.abs(anchor.x - previousAnchor.x) > 0.00001
                        or math.abs(anchor.y - previousAnchor.y) > 0.00001 then changed = true; break end
                end
                for slotId in pairs(previousAnchors) do if not anchors[slotId] then changed = true; break end end
                if changed then
                    state.projectedAnchors = anchors
                    SendNUIMessage({ type = 'weaponPreview', inventoryId = state.panel.inventoryId,
                        itemId = state.panel.itemId, status = 'ready', anchors = anchors })
                end
                -- Allow streamed bones to settle without continually projecting idle models.
                state.projectionDirty = hasInvisibleAnchor and (state.projectionRetries or 0) < 5
                state.projectionRetries = state.projectionDirty and (state.projectionRetries or 0) + 1 or 0
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then preview.Close() end
end)
