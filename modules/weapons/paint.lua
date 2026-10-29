-- Short local transformation effect; no extra object or permanent frame loop.
if not Config.EnableWeaponSystem then return end

TSSWeaponPaint = {}
local particleDictionary = 'scr_sr_adversary'
local particleName = 'scr_sr_lg_weapon_highlight'

function TSSWeaponPaint.Create()
    local controller = {}
    local generation = 0
    local particleHandle, targetObject, targetProvider
    local assetsRequested = false
    local isPlaying = false

    function controller.Stop()
        generation = generation + 1
        if particleHandle then StopParticleFxLooped(particleHandle, false) end
        particleHandle, targetObject, targetProvider = nil, nil, nil
        isPlaying = false
    end

    function controller.Refresh()
        if not isPlaying or not targetProvider then return end
        local object, centre, scale = targetProvider()
        if not object or not DoesEntityExist(object) then controller.Stop(); return end
        if object == targetObject and particleHandle then return end
        if particleHandle then StopParticleFxLooped(particleHandle, false); particleHandle = nil end
        targetObject = object
        UseParticleFxAssetNextCall(particleDictionary)
        particleHandle = StartParticleFxLoopedOnEntity(particleName, object,
            centre.x, centre.y, centre.z, 0.0, 0.0, 0.0, scale, false, false, false)
        if particleHandle and particleHandle ~= 0 then
            SetParticleFxLoopedAlpha(particleHandle, 0.85)
            SetParticleFxLoopedColour(particleHandle, 1.0, 0.0, 0.0, false)
        else particleHandle = nil end
    end

    function controller.Play(getTarget)
        controller.Stop()
        local effectGeneration = generation
        targetProvider = getTarget
        if not assetsRequested then
            assetsRequested = true
            RequestNamedPtfxAsset(particleDictionary)
        end
        CreateThread(function()
            local deadline = GetGameTimer() + 3000
            while generation == effectGeneration and GetGameTimer() < deadline
                and not HasNamedPtfxAssetLoaded(particleDictionary) do Wait(0) end
            if generation ~= effectGeneration or not HasNamedPtfxAssetLoaded(particleDictionary) then return end
            isPlaying = true
            controller.Refresh()
            SetTimeout(650, function()
                if generation == effectGeneration then controller.Stop() end
            end)
        end)
    end

    function controller.Destroy()
        controller.Stop()
        if assetsRequested then
            RemoveNamedPtfxAsset(particleDictionary)
            assetsRequested = false
        end
    end

    return controller
end
