function TSSGivingDistance()
    local distance = Config.GiveDistance
    if type(distance) ~= 'number' or distance ~= distance or distance <= 0 or distance == math.huge then return 3.0 end
    return distance
end
