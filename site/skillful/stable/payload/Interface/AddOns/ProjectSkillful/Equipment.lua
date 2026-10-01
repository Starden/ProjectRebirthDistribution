local PS = ProjectSkillful
if not PS then return end
local catalog, pending = {}, nil
local balanceCatalog, balancePending, balanceLoadout = {}, nil, nil
local affixCatalog, affixPending = {}, nil
local skillNames = { "Attack", "Strength", "Defence", "Vitality", "Ranged", "Magic", "Devotion" }
local steps = { "Entry", "Standard", "Advanced", "Pinnacle" }

PS.ClearEquipmentCatalog = function()
    catalog, pending = {}, nil
    balanceCatalog, balancePending, balanceLoadout = {}, nil, nil
    affixCatalog, affixPending = {}, nil
    if PS.RefreshEquipmentTooltips then PS.RefreshEquipmentTooltips() end
end
PS.EquipmentRequirements = function(entry) return catalog[entry] end
PS.ItemBalanceBonuses = function(entry, property)
    if property and property ~= 0 then return affixCatalog[entry .. ":" .. property] end
    return balanceCatalog[entry]
end
PS.ItemBalanceLoadout = function() return balanceLoadout end
local function clearBalance()
    balanceCatalog, balancePending, balanceLoadout = {}, nil, nil
    affixCatalog, affixPending = {}, nil
    if PS.RefreshEquipmentTooltips then PS.RefreshEquipmentTooltips() end
end
local function affixMessage(message)
    if string.sub(message,1,2) ~= "A|" then return false end
    local function reject()
        affixCatalog, affixPending = {}, nil
        balanceLoadout = nil
        if PS.RefreshEquipmentTooltips then PS.RefreshEquipmentTooltips() end
        return true
    end
    if tonumber(string.match(message,"^A|(%d+)|")) ~= 1 then return reject() end
    if message == "A|1|BEGIN" then affixPending = {}; return true end
    local count=tonumber(string.match(message,"^A|1|END|(%d+)$"))
    if count then
        local actual=0
        if affixPending then for _ in pairs(affixPending) do actual=actual+1 end end
        if not affixPending or actual~=count then return reject() end
        affixCatalog, affixPending = affixPending, nil
        if PS.RefreshEquipmentTooltips then PS.RefreshEquipmentTooltips() end
        return true
    end
    local id,property,family,accuracy,power,stab,slash,crush,ranged,magic =
        string.match(message,"^A|1|(%d+)|(%d+)|(%d+)|(%d+%.%d+)|(%d+%.%d+)|(%d+%.%d+)|(%d+%.%d+)|(%d+%.%d+)|(%d+%.%d+)|(%d+%.%d+)$")
    id,property,family=tonumber(id),tonumber(property),tonumber(family)
    local values={tonumber(accuracy),tonumber(power),tonumber(stab),tonumber(slash),tonumber(crush),tonumber(ranged),tonumber(magic)}
    local valid=affixPending and id and id>0 and property and property>0 and property<2147483648 and family and family<=2 and #values==7
    if valid then for _,value in ipairs(values) do if value>1000 then valid=false end end end
    local key=valid and (id .. ":" .. property)
    if not valid or affixPending[key] then return reject() end
    affixPending[key]={family=family,accuracy=values[1],power=values[2],defence={values[3],values[4],values[5],values[6],values[7]}}
    return true
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
    if affixMessage(message) then return true end
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

-- The accepted item layout uses authenticated static definitions. Preserve the
-- hovered instance's identity/binding and native owner/anchors during refresh.
-- These two starter fixtures have approved Tier 1 / Entry budgets but no skill gate.
local starterDefinitions = {
    [39]={tier=1,step=0,requirements={}}, [40]={tier=1,step=0,requirements={}}
}
local shortTypes = {
    ["One-Handed Swords"]="Sword", ["Two-Handed Swords"]="Sword",
    ["One-Handed Axes"]="Axe", ["Two-Handed Axes"]="Axe",
    ["One-Handed Maces"]="Mace", ["Two-Handed Maces"]="Mace",
    ["Daggers"]="Dagger", ["Staves"]="Staff", ["Polearms"]="Polearm",
    ["Bows"]="Bow", ["Guns"]="Gun", ["Crossbows"]="Crossbow",
    ["Fist Weapons"]="Fist Weapon", ["Shields"]="Shield"
}
local function itemModifiers(link)
    local fields = link and string.match(link,"item:([%d:%-]+)")
    local index, property, unsupported = 0, 0, false
    for value in string.gmatch((fields or "") .. ":", "([^:]*):") do
        index = index + 1
        -- Native link: entry, enchant, four gems, random property, unique id, ...
        if index >= 2 and index <= 6 and (tonumber(value) or 0) ~= 0 then unsupported=true end
        if index==7 then property=tonumber(value) or 0; if property<0 then unsupported=true end end
    end
    return property, unsupported
end
local function linkBalance(id,link)
    local property, unsupported=itemModifiers(link)
    if unsupported then return nil,true end
    local balance=PS.ItemBalanceBonuses(id,property)
    return balance, property~=0 and not balance
end
local function clearItemPresentation(tooltip)
    if tooltip.skillfulItemRendering then return end
    if tooltip.skillfulItemBackdrop then tooltip:SetBackdropColor(unpack(tooltip.skillfulItemBackdrop)) end
    if tooltip.skillfulItemBorder then tooltip:SetBackdropBorderColor(unpack(tooltip.skillfulItemBorder)) end
    if tooltip.skillfulItemIcon then tooltip.skillfulItemIcon:Hide() end
    if tooltip.skillfulItemFill then tooltip.skillfulItemFill:Hide() end
    tooltip.skillfulItemData, tooltip.skillfulItemBackdrop, tooltip.skillfulItemBorder = nil, nil, nil
end

local function itemSnapshot(tooltip, link)
    local name, _, quality, _, _, _, subtype, _, location, icon = GetItemInfo(link)
    if not name or not quality or not icon or not location or not _G[location] then return nil end
    name=string.match(link,"|h%[(.-)%]|h") or name -- Keep the actual rolled affix name.
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
    return {link=link, name=name, binding=binding, slot=_G[location],
        subtype=shortTypes[subtype] or subtype or "", icon=icon, r=r, g=g, b=b}
end

local function showItemFill(tooltip)
    local fill = tooltip.skillfulItemFill
    if not fill then
        -- Wrath's backdrop artwork contains transparency even at color alpha 1.
        -- Use the legacy solid-color texture API, below the text and inside the border.
        fill = tooltip:CreateTexture(nil,"BACKGROUND")
        fill:SetPoint("TOPLEFT",tooltip,"TOPLEFT",4,-4)
        fill:SetPoint("BOTTOMRIGHT",tooltip,"BOTTOMRIGHT",-4,4)
        fill:SetTexture(0.025,0.03,0.09,1)
        tooltip.skillfulItemFill = fill
    end
    fill:Show()
end

local function showItemIcon(tooltip, texture)
    local frame = tooltip.skillfulItemIcon
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
        tooltip.skillfulItemIcon = frame
    end
    frame.texture:SetTexture(texture)
    frame:Show()
end

local function renderItem(tooltip, link, definition, balance)
    if not definition or not balance or balance.family == 3 then return false end
    local cached = tooltip.skillfulItemData
    local data = cached and cached.link == link and cached or itemSnapshot(tooltip, link)
    if not data then return false end -- Leave the native tooltip usable while item data loads.
    if not tooltip.skillfulItemBackdrop then
        tooltip.skillfulItemBackdrop = {tooltip:GetBackdropColor()}
        tooltip.skillfulItemBorder = {tooltip:GetBackdropBorderColor()}
    end
    tooltip.skillfulItemRendering = true
    tooltip:ClearLines()
    tooltip.skillfulItemData = data
    tooltip.skillfulEquipmentAdded = true
    tooltip:AddLine(data.name,data.r,data.g,data.b)
    if data.binding then tooltip:AddLine(data.binding,1,1,1) end
    tooltip:AddDoubleLine(data.slot,data.subtype,1,1,1,1,1,1)
    tooltip:AddLine("Tier " .. definition.tier .. " - " .. steps[definition.step + 1],1,0.82,0)
    tooltip:AddLine(" ")
    local offense = ({[0]="Melee / ranged offense",[1]="Melee offense",[2]="Ranged offense"})[balance.family]
    tooltip:AddLine(offense,1,0.82,0)
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
    if balance.family == 0 then
        tooltip:AddLine("Offense follows your active physical style",0.6,0.6,0.6,true)
    end
    if balanceLoadout and not balanceLoadout.active then
        tooltip:AddLine("Inactive: unsupported equipment",1,0.65,0.2,true)
    end
    if tonumber(string.match(link,"item:(%d+):")) == 5191 then
        tooltip:AddLine("Dropped by: Edwin VanCleef",1,1,1)
    end
    tooltip:SetBackdropColor(0.025,0.03,0.09,1)
    tooltip:SetBackdropBorderColor(0.6,0.6,0.66,1)
    showItemFill(tooltip)
    showItemIcon(tooltip,data.icon)
    tooltip:Show()
    tooltip.skillfulItemRendering = nil
    return true
end

PS.RenderEquipmentTooltip = function(tooltip)
    if tooltip.skillfulItemRendering then return end
    local _, link = tooltip:GetItem()
    link = link or (tooltip.skillfulItemData and tooltip.skillfulItemData.link)
    local id = link and tonumber(string.match(link, "item:(%d+):"))
    local definition = id and catalog[id]
    local balance, unsupported = linkBalance(id,link)
    if (not definition and not balance) or tooltip.skillfulEquipmentAdded then return end
    if renderItem(tooltip,link,definition or starterDefinitions[id],balance) then return end
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
    elseif definition and next(balanceCatalog) then
        tooltip:AddLine(unsupported and "Northshire bonuses: unsupported item modifiers" or
            "Northshire bonuses: mapping pending",1,0.65,0.2,true)
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
            local data = tooltip.skillfulItemData
            link = link or (data and data.link)
            if link then
                tooltip.skillfulEquipmentAdded = nil
                local id = tonumber(string.match(link,"item:(%d+):"))
                local balance=linkBalance(id,link)
                if not (data and renderItem(tooltip,link,catalog[id] or starterDefinitions[id],balance)) then
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
            if self.skillfulItemRendering then return end
            self.skillfulEquipmentAdded = nil
            clearItemPresentation(self)
        end)
        tooltip:HookScript("OnHide", clearItemPresentation)
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
