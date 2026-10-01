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

-- One-item presentation trial. Values remain authenticated server definitions;
-- native combat data is not changed. Preserve the hovered instance's binding and
-- tooltip owner/anchors while refreshing the custom body in place.
local function clearCruelPresentation(tooltip)
    if tooltip.skillfulCruelRendering then return end
    if tooltip.skillfulCruelBackdrop then tooltip:SetBackdropColor(unpack(tooltip.skillfulCruelBackdrop)) end
    if tooltip.skillfulCruelBorder then tooltip:SetBackdropBorderColor(unpack(tooltip.skillfulCruelBorder)) end
    if tooltip.skillfulCruelIcon then tooltip.skillfulCruelIcon:Hide() end
    if tooltip.skillfulCruelFill then tooltip.skillfulCruelFill:Hide() end
    tooltip.skillfulCruelData, tooltip.skillfulCruelBackdrop, tooltip.skillfulCruelBorder = nil, nil, nil
end

local function cruelSnapshot(tooltip, link)
    local name, _, quality, _, _, _, _, _, location, icon = GetItemInfo(link)
    if not name or not quality or not icon then return nil end
    local r,g,b = GetItemQualityColor(quality)
    local binding
    local frameName = tooltip:GetName()
    for index=2, tooltip:NumLines() do
        local font = frameName and _G[frameName .. "TextLeft" .. index]
        local text = font and font:GetText()
        if text and (text == ITEM_SOULBOUND or text == ITEM_BIND_ON_PICKUP or
            text == ITEM_BIND_ON_EQUIP or text == ITEM_BIND_ON_USE or text == ITEM_BIND_QUEST) then
            binding = text; break
        end
    end
    return {link=link, name=name, binding=binding, slot=_G[location] or "One-Hand",
        subtype="Sword", icon=icon, r=r, g=g, b=b}
end

local function showCruelFill(tooltip)
    local fill = tooltip.skillfulCruelFill
    if not fill then
        -- Wrath's backdrop artwork contains transparency even at color alpha 1.
        -- Use the legacy solid-color texture API, below the text and inside the border.
        fill = tooltip:CreateTexture(nil,"BACKGROUND")
        fill:SetPoint("TOPLEFT",tooltip,"TOPLEFT",4,-4)
        fill:SetPoint("BOTTOMRIGHT",tooltip,"BOTTOMRIGHT",-4,4)
        fill:SetTexture(0.025,0.03,0.09,1)
        tooltip.skillfulCruelFill = fill
    end
    fill:Show()
end

local function showCruelIcon(tooltip, texture)
    local frame = tooltip.skillfulCruelIcon
    if not frame then
        frame = CreateFrame("Frame", nil, tooltip)
        frame:SetWidth(64); frame:SetHeight(64)
        frame:SetPoint("TOPRIGHT", tooltip, "TOPLEFT", -5, 0)
        frame:SetFrameLevel(tooltip:GetFrameLevel() + 1)
        frame:EnableMouse(false)
        frame:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", tile=true, tileSize=16,
            edgeSize=16, insets={left=4,right=4,top=4,bottom=4}})
        frame:SetBackdropColor(0.025,0.03,0.09,1)
        frame:SetBackdropBorderColor(0.6,0.6,0.66,1)
        frame.texture = frame:CreateTexture(nil,"ARTWORK")
        frame.texture:SetPoint("TOPLEFT",frame,"TOPLEFT",8,-8)
        frame.texture:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-8,8)
        tooltip.skillfulCruelIcon = frame
    end
    frame.texture:SetTexture(texture)
    frame:Show()
end

local function renderCruel(tooltip, link, definition, balance)
    if not definition or not balance or balance.family ~= 1 then return false end
    local data = tooltip.skillfulCruelData or cruelSnapshot(tooltip, link)
    if not data then return false end -- Leave the native tooltip usable while item data loads.
    if not tooltip.skillfulCruelBackdrop then
        tooltip.skillfulCruelBackdrop = {tooltip:GetBackdropColor()}
        tooltip.skillfulCruelBorder = {tooltip:GetBackdropBorderColor()}
    end
    tooltip.skillfulCruelRendering = true
    tooltip:ClearLines()
    tooltip.skillfulCruelData = data
    tooltip.skillfulEquipmentAdded = true
    tooltip:AddLine(data.name,data.r,data.g,data.b)
    if data.binding then tooltip:AddLine(data.binding,1,1,1) end
    tooltip:AddDoubleLine(data.slot,data.subtype,1,1,1,1,1,1)
    tooltip:AddLine("Tier " .. definition.tier .. " - " .. steps[definition.step + 1],1,0.82,0)
    tooltip:AddLine(" ")
    tooltip:AddLine("Melee offense",1,0.82,0)
    tooltip:AddLine(string.format("+%.2f Accuracy (hit chance)",balance.accuracy),1,1,1)
    tooltip:AddLine(string.format("+%.2f Power (maximum hit)",balance.power),1,1,1)
    tooltip:AddLine(" ")
    tooltip:AddLine("Defense bonuses",1,0.82,0)
    -- B|1 contract order is Stab / Slash / Crush / Ranged / Magic.
    for _, style in ipairs({{1,"Pierce"},{2,"Slash"},{3,"Crush"},{4,"Ranged"},{5,"Magic"}}) do
        tooltip:AddLine(string.format("+%.2f %s Defense",balance.defence[style[1]],style[2]),1,1,1)
    end
    tooltip:AddLine(" ")
    for _, requirement in ipairs(definition.requirements) do
        local trained = PS.state.skills[requirement[1]]
        local r,g,b = 1,1,1
        if not trained then r,g,b = 0.6,0.6,0.6
        elseif trained.level < requirement[2] then r,g,b = 1,0.125,0.125 end
        local current = trained and tostring(trained.level) or "unknown"
        tooltip:AddLine("Requires " .. skillNames[requirement[1]] .. " " .. requirement[2] ..
            " (yours: " .. current .. ")",r,g,b)
    end
    tooltip:AddLine(" ")
    tooltip:AddLine("Bonuses: Northshire test creatures only",0.6,0.6,0.6,true)
    if balanceLoadout and not balanceLoadout.active then
        tooltip:AddLine("Inactive: unsupported equipment",1,0.65,0.2,true)
    end
    tooltip:AddLine("Dropped by: Edwin VanCleef",1,1,1)
    tooltip:SetBackdropColor(0.025,0.03,0.09,1)
    tooltip:SetBackdropBorderColor(0.6,0.6,0.66,1)
    showCruelFill(tooltip)
    showCruelIcon(tooltip,data.icon)
    tooltip:Show()
    tooltip.skillfulCruelRendering = nil
    return true
end

PS.RenderEquipmentTooltip = function(tooltip)
    if tooltip.skillfulCruelRendering then return end
    local _, link = tooltip:GetItem()
    link = link or (tooltip.skillfulCruelData and tooltip.skillfulCruelData.link)
    local id = link and tonumber(string.match(link, "item:(%d+):"))
    local definition = id and catalog[id]
    local balance = id and balanceCatalog[id]
    if (not definition and not balance) or tooltip.skillfulEquipmentAdded then return end
    if id == 5191 and renderCruel(tooltip,link,definition,balance) then return end
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
    if PS.RefreshEquipmentBonuses then PS.RefreshEquipmentBonuses() end
    refreshing = true
    for _, tooltip in ipairs({GameTooltip, ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2}) do
        if tooltip and tooltip:IsShown() then
            local _, link = tooltip:GetItem()
            local data = tooltip.skillfulCruelData
            link = link or (data and data.link)
            if link then
                tooltip.skillfulEquipmentAdded = nil
                local id = tonumber(string.match(link,"item:(%d+):"))
                if not (data and id == 5191 and renderCruel(tooltip,link,catalog[id],balanceCatalog[id])) then
                    tooltip:SetHyperlink(link)
                end
            end
        end
    end
    refreshing = false
end
for _, tooltip in ipairs({GameTooltip, ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2}) do
    if tooltip then
        tooltip:HookScript("OnTooltipCleared", function(self)
            if self.skillfulCruelRendering then return end
            self.skillfulEquipmentAdded = nil
            clearCruelPresentation(self)
        end)
        tooltip:HookScript("OnHide", clearCruelPresentation)
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
