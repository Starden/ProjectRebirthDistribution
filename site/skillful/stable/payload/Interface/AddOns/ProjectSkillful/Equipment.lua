local PS = ProjectSkillful
if not PS then return end
local catalog, pending = {}, nil
local balanceCatalog, balancePending, balanceLoadout = {}, nil, nil
local skillNames = { "Attack", "Strength", "Defence", "Vitality", "Ranged", "Magic", "Devotion" }
local steps = { "Entry", "Standard", "Advanced", "Pinnacle" }

PS.ClearEquipmentCatalog = function()
    catalog, pending = {}, nil
    balanceCatalog, balancePending, balanceLoadout = {}, nil, nil
    if PS.RefreshEquipmentTooltips then PS.RefreshEquipmentTooltips() end
end
PS.EquipmentRequirements = function(entry) return catalog[entry] end
PS.ItemBalanceBonuses = function(entry) return balanceCatalog[entry] end
PS.ItemBalanceLoadout = function() return balanceLoadout end
local function clearBalance()
    balanceCatalog, balancePending, balanceLoadout = {}, nil, nil
    if PS.RefreshEquipmentTooltips then PS.RefreshEquipmentTooltips() end
end
local function balanceMessage(message)
    local kind = string.sub(message,1,2)
    if kind ~= "B|" and kind ~= "L|" then return false end
    if tonumber(string.match(message,"^[BL]|(%d+)|")) ~= 1 then clearBalance(); return true end
    if message == "B|1|BEGIN" then balancePending = {}; return true end
    local count = tonumber(string.match(message,"^B|1|END|(%d+)$"))
    if count then
        local actual = 0
        if balancePending then for _ in pairs(balancePending) do actual = actual + 1 end end
        if balancePending and actual == count then balanceCatalog = balancePending else balanceCatalog = {} end
        balancePending = nil
        if PS.RefreshEquipmentTooltips then PS.RefreshEquipmentTooltips() end
        return true
    end
    if kind == "L|" then
        local updated = nil
        if message == "L|1|0" then updated = { active=false, packet=message }
        else
            local accuracy,power,stab,slash,crush,ranged,magic =
                string.match(message,"^L|1|1|(%d+)|(%d+)|(%d+)|(%d+)|(%d+)|(%d+)|(%d+)$")
            local values = {tonumber(accuracy),tonumber(power),tonumber(stab),tonumber(slash),tonumber(crush),tonumber(ranged),tonumber(magic)}
            if #values == 7 then
                local valid = true
                for _,value in ipairs(values) do if value > 1000 then valid = false end end
                if valid then updated = {active=true,packet=message,accuracy=values[1],power=values[2],defence={values[3],values[4],values[5],values[6],values[7]}} end
            end
        end
        if not updated then clearBalance(); return true end
        local changed = not updated or not balanceLoadout or balanceLoadout.packet ~= updated.packet
        balanceLoadout = updated
        if changed and PS.RefreshEquipmentTooltips then PS.RefreshEquipmentTooltips() end
        return true
    end
    local id,family,accuracy,power,stab,slash,crush,ranged,magic =
        string.match(message,"^B|1|(%d+)|(%d+)|(%d+%.%d+)|(%d+%.%d+)|(%d+%.%d+)|(%d+%.%d+)|(%d+%.%d+)|(%d+%.%d+)|(%d+%.%d+)$")
    id,family = tonumber(id),tonumber(family)
    local values = {tonumber(accuracy),tonumber(power),tonumber(stab),tonumber(slash),tonumber(crush),tonumber(ranged),tonumber(magic)}
    local valid = balancePending and id and id > 0 and family and family <= 3 and #values == 7
    if valid then for _,value in ipairs(values) do if value > 1000 then valid = false end end end
    if not valid or balancePending[id] then clearBalance(); return true end
    balancePending[id] = {family=family,accuracy=values[1],power=values[2],defence={values[3],values[4],values[5],values[6],values[7]}}
    return true
end
PS.HandleEquipmentMessage = function(message)
    if balanceMessage(message) then return true end
    if string.sub(message, 1, 2) ~= "E|" then return false end
    -- AzerothCore delivers the catalog before echoing our self-whisper request.
    -- This is a client request, not a definition row; retain committed/pending data.
    if message == "E|1|GET" then return true end
    local version = tonumber(string.match(message, "^E|(%d+)|"))
    if version ~= 1 then PS.ClearEquipmentCatalog(); return true end
    if message == "E|1|BEGIN" then pending = {}; return true end
    local count = tonumber(string.match(message, "^E|1|END|(%d+)$"))
    if count then
        if pending then
            local actual = 0
            for _ in pairs(pending) do actual = actual + 1 end
            if actual == count then catalog = pending else catalog = {} end
        end
        pending = nil
        if PS.RefreshEquipmentTooltips then PS.RefreshEquipmentTooltips() end
        return true
    end
    local id, tier, step, skill, level, secondSkill, secondLevel =
        string.match(message, "^E|1|(%d+)|(%d+)|(%d+)|(%d+)|(%d+)|(%d+)|(%d+)$")
    id, tier, step, skill, level, secondSkill, secondLevel = tonumber(id), tonumber(tier),
        tonumber(step), tonumber(skill), tonumber(level), tonumber(secondSkill), tonumber(secondLevel)
    local valid = pending and id and id > 0 and tier >= 1 and tier <= 10 and step <= 3 and
        skill >= 1 and skill <= 7 and level >= 1 and level <= 100 and
        ((secondSkill == 0 and secondLevel == 0) or
         (secondSkill >= 1 and secondSkill <= 7 and secondSkill ~= skill and secondLevel >= 1 and secondLevel <= 100))
    if not valid or pending[id] then PS.ClearEquipmentCatalog(); return true end
    pending[id] = { tier=tier, step=step, requirements={{skill,level}} }
    if secondSkill > 0 then table.insert(pending[id].requirements, {secondSkill,secondLevel}) end
    return true
end

PS.RenderEquipmentTooltip = function(tooltip)
    local _, link = tooltip:GetItem()
    local id = link and tonumber(string.match(link, "item:(%d+):"))
    local definition = id and catalog[id]
    local balance = id and balanceCatalog[id]
    if (not definition and not balance) or tooltip.skillfulEquipmentAdded then return end
    tooltip.skillfulEquipmentAdded = true
    if definition then
    tooltip:AddLine("Tier " .. definition.tier .. " • " .. steps[definition.step + 1], 1, 0.82, 0)
    for _, requirement in ipairs(definition.requirements) do
        local trained = PS.state.skills[requirement[1]]
        local met = trained and trained.level >= requirement[2]
        local r, g, b = 1, 1, 1
        if not trained then r, g, b = 0.6, 0.6, 0.6
        elseif not met then r, g, b = 1, 0.125, 0.125 end
        tooltip:AddLine("Requires " .. skillNames[requirement[1]] .. " (" .. requirement[2] .. ")", r, g, b)
    end
    end
    if balance then
        tooltip:AddLine("Northshire bonus preview",0.3,0.85,1)
        local family = ({[0]="Active style",[1]="Melee",[2]="Ranged",[3]="Magic"})[balance.family]
        tooltip:AddLine(string.format("%s: +%.2f accuracy, +%.2f power",family,balance.accuracy,balance.power),1,1,1)
        tooltip:AddLine(string.format("Defence: %.2f stab / %.2f slash / %.2f crush",balance.defence[1],balance.defence[2],balance.defence[3]),1,1,1)
        tooltip:AddLine(string.format("Defence: %.2f ranged / %.2f magic",balance.defence[4],balance.defence[5]),1,1,1)
        if balanceLoadout and not balanceLoadout.active then tooltip:AddLine("Rebalance inactive for your current equipment",1,0.65,0.2) end
    end
    tooltip:Show()
end

local refreshing = false
PS.RefreshEquipmentTooltips = function()
    if refreshing then return end
    refreshing = true
    for _, tooltip in ipairs({GameTooltip, ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2}) do
        if tooltip and tooltip:IsShown() then
            local _, link = tooltip:GetItem()
            if link then
                tooltip.skillfulEquipmentAdded = nil
                tooltip:SetHyperlink(link)
            end
        end
    end
    refreshing = false
end
for _, tooltip in ipairs({GameTooltip, ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2}) do
    if tooltip then
        tooltip:HookScript("OnTooltipCleared", function(self) self.skillfulEquipmentAdded = nil end)
        tooltip:HookScript("OnTooltipSetItem", PS.RenderEquipmentTooltip)
    end
end
local requests = CreateFrame("Frame", "ProjectSkillfulEquipmentRequests")
requests:RegisterEvent("PLAYER_ENTERING_WORLD")
requests:SetScript("OnEvent", function()
    PS.ClearEquipmentCatalog()
    -- Requests a full v3 snapshot and catalog, including after /reload.
    SendAddonMessage("PSKILL", "E|1|GET", "WHISPER", UnitName("player"))
end)
