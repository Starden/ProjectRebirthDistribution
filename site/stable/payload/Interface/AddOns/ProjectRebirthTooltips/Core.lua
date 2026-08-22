local numericData = ProjectRebirthTooltipData
local rankData = ProjectRebirthClassRankData
if not numericData or numericData.schemaVersion ~= 1 or numericData.dataVersion ~= 3 or
    numericData.expectedRowCount ~= 52 or not rankData or rankData.schemaVersion ~= 1 or
    rankData.catalogVersion ~= 1 or rankData.expectedTrackedSpellCount ~= 2164 or
    rankData.expectedVirtualRankCount ~= 116 then
    return
end

local active = false
local playerClassId
local debugEnabled = false
local rewriteInProgress = {}
local numericAbilityByTitle = {}
local registeredNumericRows = 0

for _, ability in pairs(numericData.abilities) do
    numericAbilityByTitle[ability.title] = ability
    registeredNumericRows = registeredNumericRows + #ability.rows
end

if registeredNumericRows ~= numericData.expectedRowCount or
    rankData.registeredTrackedSpellCount ~= rankData.expectedTrackedSpellCount or
    rankData.registeredVirtualRankCount ~= rankData.expectedVirtualRankCount then
    return
end

local function StripMarkup(text)
    if not text then
        return ""
    end
    text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    text = string.gsub(text, "|r", "")
    return text
end

local function UpdateActivation()
    local realm = GetRealmName and GetRealmName() or ""
    local _, classToken = UnitClass("player")
    playerClassId = classToken and rankData.classIds[classToken]
    active = realm == numericData.realm and playerClassId ~= nil
end

local function CurrentNumericRow(ability)
    local level = UnitLevel("player") or 0
    if level <= 0 or level > ability.maxCustomLevel then
        return nil
    end

    local current
    for _, row in ipairs(ability.rows) do
        if row.level <= level then
            current = row
        else
            break
        end
    end
    return current
end

local function CurrentVirtualRow(ability)
    local level = UnitLevel("player") or 0
    if level <= 0 then
        return nil
    end

    local current
    for _, row in ipairs(ability.rows) do
        if row.level <= level then
            current = row
        else
            break
        end
    end
    return current
end

local function BuildNumericDescription(ability, row)
    local code = ability.code
    local minValue = row.valueMin
    local maxValue = row.valueMax

    if code == "blood_strike" then
        return string.format("Instantly strikes for %d%% weapon damage plus %d. The normal bonus per disease is preserved.", row.weaponDamagePct, minValue)
    elseif code == "death_coil" then
        local heal = math.floor(minValue * 1.5 + 0.5)
        return string.format("Fires unholy energy for %d base Shadow damage to an enemy, or %d base healing to a friendly Undead target. Normal attack-power scaling is preserved.", minValue, heal)
    elseif code == "icy_touch" then
        return string.format("Chills the target for %d to %d base Frost damage and applies Frost Fever. Normal attack-power, threat, and disease behavior are preserved.", minValue, maxValue)
    elseif code == "plague_strike" then
        return string.format("A vicious strike for %d%% weapon damage plus %d that applies Blood Plague. Normal disease behavior is preserved.", row.weaponDamagePct, minValue)
    elseif code == "death_strike" then
        return string.format("A deadly attack for %d%% weapon damage plus %d. Healing remains 5%% of maximum health for each of your diseases on the target.", row.weaponDamagePct, minValue)
    elseif code == "corpse_explosion" then
        return string.format("Explodes a valid corpse or ghoul for %d base Shadow damage to nearby enemies. Native targeting, area, cost, and cooldown are preserved.", minValue)
    elseif code == "blood_boil" then
        return string.format("Deals %d to %d base Shadow damage to enemies within 10 yards. Normal disease bonus and attack-power scaling are preserved.", minValue, maxValue)
    elseif code == "death_and_decay" then
        return string.format("Corrupts the targeted ground for %d base Shadow damage each second for 10 seconds. Native radius, rune cost, cadence, and threat are preserved.", minValue)
    elseif code == "horn_of_winter" then
        return string.format("Increases Strength and Agility of nearby party or raid members by %d for 2 minutes and generates 10 Runic Power.", minValue)
    elseif code == "scourge_strike" then
        return string.format("Strikes for the normal weapon component plus %d fixed Physical damage. The native Shadow disease component, cost, school, and flags are preserved.", minValue)
    end
end

local function IsNumericDescriptionLine(code, text)
    local value = string.lower(StripMarkup(text))
    if value == "" then
        return false
    elseif code == "blood_strike" then
        return string.find(value, "weapon damage", 1, true) and string.find(value, "disease", 1, true)
    elseif code == "death_coil" then
        return string.find(value, "shadow damage", 1, true) and (string.find(value, "undead", 1, true) or string.find(value, "unholy energy", 1, true))
    elseif code == "icy_touch" then
        return string.find(value, "frost damage", 1, true) and string.find(value, "frost fever", 1, true)
    elseif code == "plague_strike" then
        return string.find(value, "weapon damage", 1, true) and string.find(value, "blood plague", 1, true)
    elseif code == "death_strike" then
        return string.find(value, "weapon damage", 1, true) and string.find(value, "maximum health", 1, true)
    elseif code == "corpse_explosion" then
        return string.find(value, "corpse", 1, true) and string.find(value, "shadow damage", 1, true)
    elseif code == "blood_boil" then
        return string.find(value, "shadow damage", 1, true) and string.find(value, "within 10", 1, true)
    elseif code == "death_and_decay" then
        return string.find(value, "corrupts the ground", 1, true) or (string.find(value, "shadow damage", 1, true) and string.find(value, "threat", 1, true))
    elseif code == "horn_of_winter" then
        return string.find(value, "strength", 1, true) and string.find(value, "agility", 1, true)
    elseif code == "scourge_strike" then
        return string.find(value, "weapon damage", 1, true) and (string.find(value, "unholy strike", 1, true) or string.find(value, "physical", 1, true))
    end
    return false
end

local function IsGenericDescriptionLine(text)
    local value = string.lower(StripMarkup(text))
    return string.len(value) > 20 and (
        string.find(value, "damage", 1, true) or
        string.find(value, "strength", 1, true) or
        string.find(value, "agility", 1, true)
    )
end

local function TooltipFontString(tooltip, side, line)
    local name = tooltip and tooltip.GetName and tooltip:GetName()
    if not name then
        return nil
    end
    return _G[name .. "Text" .. side .. line]
end

local function ResolveSpellId(tooltip)
    if not tooltip.GetSpell then
        return nil
    end
    local _, _, spellId = tooltip:GetSpell()
    return spellId
end

local function ResolveNumericAbility(tooltip, spellId)
    if spellId and numericData.spellIds[spellId] then
        return numericData.spellIds[spellId]
    end

    local title = TooltipFontString(tooltip, "Left", 1)
    if title then
        return numericAbilityByTitle[StripMarkup(title:GetText())]
    end
end

local function ResolveRankRow(spellId)
    if not spellId or not playerClassId then
        return nil
    end

    if playerClassId == 6 then
        local virtualAbility = rankData.virtualAbilitiesBySpell[spellId]
        if virtualAbility then
            return CurrentVirtualRow(virtualAbility)
        end
    end

    local classRows = rankData.spellsByClass[playerClassId]
    return classRows and classRows[spellId]
end

local function RewriteRankLabel(tooltip, row)
    local count = tooltip:NumLines() or 0
    for line = 1, count do
        for _, side in ipairs({ "Left", "Right" }) do
            local fontString = TooltipFontString(tooltip, side, line)
            local text = fontString and StripMarkup(fontString:GetText()) or ""
            if string.match(text, "^Rank %d+$") or string.match(text, "^Rebirth Rank %d+$") then
                fontString:SetText("Rebirth Rank " .. row.rank)
            end
        end
    end
end

local function IsTrackerLine(text)
    return string.match(StripMarkup(text), "^Rebirth Rank %d+ %(Level %d+%)") ~= nil
end

local function IsDescriptionColor(fontString)
    if not fontString or not fontString.GetTextColor then
        return false
    end
    local red, green, blue = fontString:GetTextColor()
    return red and red >= 0.85 and green >= 0.55 and green <= 0.95 and blue <= 0.35
end

local function IsMetadataLine(text)
    local value = string.lower(StripMarkup(text))
    if value == "" or IsTrackerLine(value) then
        return true
    end
    return string.match(value, "^rank %d+$") or
        string.match(value, "^rebirth rank %d+$") or
        string.match(value, "^next rank") or
        string.match(value, "^%d+ mana$") or
        string.match(value, "^%d+ rage$") or
        string.match(value, "^%d+ energy$") or
        string.match(value, "^%d+ focus$") or
        string.match(value, "^%d+ runic power$") or
        string.match(value, "^%d+ blood$") or
        string.match(value, "^%d+ frost$") or
        string.match(value, "^%d+ unholy$") or
        string.match(value, "^%d+ runes?$") or
        string.match(value, "^%d+%.?%d* sec cast$") or
        value == "instant" or value == "instant cast" or value == "channeled" or
        string.match(value, "^melee range$") or
        string.match(value, "^%d+ yd range$") or
        string.match(value, "^requires ") or
        string.match(value, "^tools: ") or
        string.match(value, "^reagents: ") or
        string.match(value, "^cooldown") or
        string.match(value, "^%d+%.?%d* sec cooldown$")
end

local function FindDescriptionTarget(tooltip)
    local count = tooltip:NumLines() or 0
    for line = 2, count do
        local fontString = TooltipFontString(tooltip, "Left", line)
        local text = fontString and fontString:GetText() or ""
        if text ~= "" and not IsMetadataLine(text) and IsDescriptionColor(fontString) then
            return fontString
        end
    end

    for line = count, 2, -1 do
        local fontString = TooltipFontString(tooltip, "Left", line)
        local text = fontString and fontString:GetText() or ""
        if string.len(StripMarkup(text)) > 10 and not IsMetadataLine(text) then
            return fontString
        end
    end
end

local function AddOrUpdateTracker(tooltip, row)
    local tracker = string.format("|cff73e6ffRebirth Rank %d (Level %d)|r", row.rank, row.level)
    local count = tooltip:NumLines() or 0
    for line = 2, count do
        local fontString = TooltipFontString(tooltip, "Left", line)
        local text = fontString and fontString:GetText() or ""
        local firstLine, remainingText = string.match(text, "^([^\n]*)\n?(.*)$")
        if firstLine and IsTrackerLine(firstLine) then
            fontString:SetText(tracker .. (remainingText ~= "" and "\n" .. remainingText or ""))
            return
        end
    end

    local target = FindDescriptionTarget(tooltip)
    if target then
        target:SetText(tracker .. "\n" .. target:GetText())
    else
        tooltip:AddLine(tracker, 0.45, 0.90, 1.00, true)
    end
end

local function RewriteNumericTooltip(tooltip, ability, row)
    local description = BuildNumericDescription(ability, row)
    if not description then
        return false
    end

    local replacement = string.format(
        "|cff73e6ffRebirth Rank %d (Level %d)|r\n%s\n|cff9d9d9dAuthoritative base values, data v%d.|r",
        row.rank, row.level, description, numericData.dataVersion)
    local count = tooltip:NumLines() or 0
    local target

    for line = 2, count do
        local fontString = TooltipFontString(tooltip, "Left", line)
        if fontString and IsNumericDescriptionLine(ability.code, fontString:GetText()) then
            target = fontString
            break
        end
    end

    if not target then
        for line = count, 2, -1 do
            local fontString = TooltipFontString(tooltip, "Left", line)
            if fontString and IsGenericDescriptionLine(fontString:GetText()) then
                target = fontString
                break
            end
        end
    end

    if target then
        target:SetText(replacement)
    else
        tooltip:AddLine(replacement, 1, 1, 1, true)
    end
    return true
end

local function RewriteTooltip(tooltip)
    if not active or not tooltip or rewriteInProgress[tooltip] then
        return
    end

    local spellId = ResolveSpellId(tooltip)
    local numericAbility = playerClassId == 6 and ResolveNumericAbility(tooltip, spellId)
    local numericRow = numericAbility and CurrentNumericRow(numericAbility)
    local rankRow = numericRow or ResolveRankRow(spellId)
    if not rankRow then
        return
    end

    rewriteInProgress[tooltip] = true
    RewriteRankLabel(tooltip, rankRow)
    local numericRewritten = numericAbility and numericRow and RewriteNumericTooltip(tooltip, numericAbility, numericRow)
    if not numericRewritten then
        AddOrUpdateTracker(tooltip, rankRow)
    end

    if tooltip:IsShown() then
        tooltip:Show()
    end
    rewriteInProgress[tooltip] = nil

    if debugEnabled and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "|cff73e6ffRebirth Tooltips:|r spell %d -> rank %d, level %d",
            spellId or 0, rankRow.rank, rankRow.level))
    end
end

local function HookTooltip(tooltip)
    if not tooltip then
        return
    end

    tooltip:HookScript("OnTooltipSetSpell", RewriteTooltip)
    for _, method in ipairs({ "SetAction", "SetSpell", "SetTrainerService", "SetHyperlink" }) do
        if tooltip[method] then
            hooksecurefunc(tooltip, method, function(self)
                RewriteTooltip(self)
            end)
        end
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function()
    UpdateActivation()
end)

HookTooltip(GameTooltip)
HookTooltip(ItemRefTooltip)

SLASH_PROJECTREBIRTHTOOLTIPS1 = "/rebirthtooltips"
SlashCmdList.PROJECTREBIRTHTOOLTIPS = function(message)
    UpdateActivation()
    local command = string.lower(message or "")
    if command == "debug" then
        debugEnabled = not debugEnabled
    end
    local state = active and "active" or "inactive"
    local debugState = debugEnabled and "on" or "off"
    DEFAULT_CHAT_FRAME:AddMessage(string.format(
        "|cff73e6ffProject Rebirth Tooltips|r %s; realm=%s; addon=%s; numeric=%d; tracked=%d; virtual=%d; debug=%s",
        state, GetRealmName() or "unknown", rankData.addonVersion, registeredNumericRows,
        rankData.registeredTrackedSpellCount, rankData.registeredVirtualRankCount, debugState))
end
