-- Shared draft rules. This module never sends a gameplay request.
ProjectRebirthFourthSpecPolicy = {}
local P = ProjectRebirthFourthSpecPolicy
local function Integer(value, low, high)
    return type(value) == "number" and value == math.floor(value) and value >= low and value <= high
end

function P.Budget(level)
    if not Integer(level, 1, 255) then return 0 end
    return math.max(0, math.min(80, level) - 9)
end

function P.Primary(totals)
    local highest, winner, tied = 0, nil, false
    for index, points in ipairs(totals) do
        if not Integer(points, 0, 71) then return nil end
        if points > highest then
            highest, winner, tied = points, index, false
        elseif points == highest then
            tied = true
        end
    end
    if highest == 0 or tied then return nil end
    return winner
end

function P.Validate(tree, ranks, level, nativeTotals)
    if type(tree) ~= "table" or type(tree.nodes) ~= "table" or type(ranks) ~= "table" then
        return false, "Invalid draft data."
    end
    local byKey, totals, total, fourth = {}, {}, 0, 0
    for index, points in ipairs(nativeTotals or {}) do
        if not Integer(points, 0, 71) then return false, "Invalid native point total." end
        totals[index] = points
        total = total + points
    end
    for _, node in ipairs(tree.nodes) do byKey[node.key] = node end
    for key, rank in pairs(ranks) do
        local node = byKey[key]
        if not node then return false, "Unknown talent in saved draft." end
        if not Integer(rank, 1, node.maxRank) then return false, "Invalid talent rank." end
        fourth = fourth + rank
    end
    if total + fourth > P.Budget(level) then return false, "The shared talent-point budget is full." end
    local spent = 0
    for row = 1, 11 do
        for _, node in ipairs(tree.nodes) do
            local rank = ranks[node.key]
            if node.row == row and rank then
                if spent < node.requiredPoints then
                    return false, string.format("%s requires %d points in earlier rows.", node.name, node.requiredPoints)
                end
                if node.prerequisite ~= "" and (ranks[node.prerequisite] or 0) < node.prerequisiteRank then
                    return false, "A prerequisite is missing for " .. node.name .. "."
                end
                spent = spent + rank
            end
        end
    end
    totals[#totals + 1] = fourth
    return true, "Draft only: no spells, effects, or live points are changed.", fourth, P.Primary(totals)
end

function P.Change(tree, ranks, key, delta, level, nativeTotals)
    if delta ~= 1 and delta ~= -1 then return nil, "Invalid rank change." end
    local found = false
    for _, node in ipairs(tree.nodes) do if node.key == key then found = true end end
    if not found then return nil, "Unknown talent." end
    if delta == -1 and not ranks[key] then return nil, "No draft rank to remove." end
    local copy = {}
    for id, rank in pairs(ranks) do copy[id] = rank end
    local rank = (copy[key] or 0) + delta
    if rank <= 0 then copy[key] = nil else copy[key] = rank end
    local ok, reason = P.Validate(tree, copy, level, nativeTotals)
    if not ok then return nil, reason end
    return copy
end
