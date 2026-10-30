TSSThrowing = {}

local function configuredNumber(value, fallback, minimum, maximum)
    if type(value) ~= 'number' or value ~= value or math.abs(value) == math.huge then return fallback end
    return math.max(minimum, math.min(maximum, value))
end

function TSSThrowing.Settings()
    local settings = Config.Throwing or {}
    local maximumPower = configuredNumber(settings.maxPower, 2.0, 0.1, 4.0)
    return {
        fillTime = configuredNumber(settings.fillTime, 1650, 100, 10000),
        drainTime = configuredNumber(settings.drainTime, 1650, 100, 10000),
        idleTimeout = configuredNumber(settings.idleTimeout, 5000, 0, 600000),
        chargeTimeout = configuredNumber(settings.chargeTimeout, 6800, 0, 600000),
        tapTime = configuredNumber(settings.tapTime, 150, 0, 1000),
        minPower = configuredNumber(settings.minPower, 0.0, 0, maximumPower),
        maxPower = maximumPower,
        speed = configuredNumber(settings.speed, 13.0, 0, 30),
        lift = configuredNumber(settings.lift, 3.5, 0, 10),
        maxDistance = configuredNumber(settings.maxDistance, 70.0, 3, 100),
    }
end

function TSSThrowing.Power(heldMilliseconds)
    local settings = TSSThrowing.Settings()
    local cycleTime = settings.fillTime + settings.drainTime
    local phase = math.max(0, heldMilliseconds - settings.tapTime) % cycleTime
    local charge = phase <= settings.fillTime and phase / settings.fillTime
        or 1 - (phase - settings.fillTime) / settings.drainTime
    return settings.minPower + (settings.maxPower - settings.minPower) * charge
end

function TSSThrowing.Velocity(direction, power)
    local settings = TSSThrowing.Settings()
    -- Range grows with velocity squared. Scaling all velocity components this way
    -- makes power 1 the original throw and power 2 approximately twice its range.
    local velocityScale = math.sqrt(math.max(0, math.min(settings.maxPower, power)))
    return {
        x = direction.x * settings.speed * velocityScale,
        y = direction.y * settings.speed * velocityScale,
        z = (direction.z * settings.speed + settings.lift) * velocityScale,
    }
end
