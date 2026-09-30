local PS = ProjectSkillful
if not PS then return end
local catalog, pending = {}, nil
local skillNames = { "Attack", "Strength", "Defence", "Vitality", "Ranged", "Magic", "Devotion" }
local steps = { "Entry", "Standard", "Advanced", "Pinnacle" }

PS.ClearEquipmentCatalog = function()
    catalog, pending = {}, nil
    if PS.RefreshEquipmentTooltips then PS.RefreshEquipmentTooltips() end
end
PS.EquipmentRequirements = function(entry) return catalog[entry] end
PS.HandleEquipmentMessage = function(message)
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
    if not definition or tooltip.skillfulEquipmentAdded then return end
    tooltip.skillfulEquipmentAdded = true
    tooltip:AddLine("Tier " .. definition.tier .. " • " .. steps[definition.step + 1], 1, 0.82, 0)
    for _, requirement in ipairs(definition.requirements) do
        local trained = PS.state.skills[requirement[1]]
        local met = trained and trained.level >= requirement[2]
        local r, g, b = 1, 1, 1
        if not trained then r, g, b = 0.6, 0.6, 0.6
        elseif not met then r, g, b = 1, 0.125, 0.125 end
        tooltip:AddLine("Requires " .. skillNames[requirement[1]] .. " (" .. requirement[2] .. ")", r, g, b)
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
    -- Requests a full v3 snapshot and catalog, including after /reload.
    SendAddonMessage("PSKILL", "E|1|GET", "WHISPER", UnitName("player"))
end)
