local PREFIX = "ProjectRebirth"
local PROTOCOL = "2"
local REALM = "Rebirth"
local BRAND_TEXTURE = "Interface\\AddOns\\ProjectRebirthTooltips\\Media\\ProjectReverie"

local active = false
local panel
local toggleButton
local tabFrames = {}
local tabButtons = {}
local tabOrder = { "skills", "heritages", "manifestations", "rebirth" }
local activeTab = "skills"
local capacityText
local statusText
local skillCountLabel
local skillGridFrame
local skillGridChild
local skillDetailFrame
local skillDetailIcon
local skillDetailName
local skillDetailMeta
local skillDetailSummary
local heritageCountLabel
local heritageGridFrame
local heritageGridChild
local heritageDetailFrame
local heritageDetailIcon
local heritageDetailName
local heritageDetailMeta
local heritageDetailSummary
local heritageWarning
local heritageButton
local offerFrame
local offerIcon
local offerName
local offerRarity
local offerSummary
local acceptButton
local declineButton
local choiceFrame
local choiceCards = {}
local choiceSubtitle
local claimButton
local declineAllButton
local laterButton
local pendingGlow
local pendingCount
local footnote
local searchBox
local inspectButton
local loadoutSlots = {}
local rebirthLifeText
local rebirthLevelText
local rebirthCapacityText
local rebirthHeritageText
local rebirthEligibilityText
local rebirthNextText
local skillButtons = {}
local heritageButtons = {}
local selectedSkillId
local selectedHeritageId = 1101
local selectedChoiceOrdinal
local selectedChoiceOpportunityId
local panelWanted = false
local actionPending = false
local offerAssembly
local reopenChoiceAfterSnapshot = false
local deferredOfferReveal = false
local revealedOpportunityId
local resolvedOpportunities = {}
local offerVersions = {}
local offerFingerprints = {}
local lastOfferResyncAt = -10
local Render
local RenderChoiceFrame
local ShowManifestationChoices

local SKILL_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local HERITAGE_ICON = "Interface\\Icons\\INV_Misc_Rune_01"
local OFFER_ICON = "Interface\\Icons\\Spell_Arcane_Arcane01"

local state = {
    status = "waiting",
    owned = 0,
    capacity = 0,
    lifeId = 0,
    ownershipAvailable = false,
    complete = true,
    total = 0,
    skills = {},
    inspectedName = nil,
    offer = nil,
    heritages = {},
    heritage = {
        status = "waiting",
        selected = false,
        id = 1101,
        rank = 0,
        xp = 0,
        canSelect = false,
        effects = false,
        maxRank = 100,
        nextThreshold = 0,
        bonusMilli = 0,
        eligible = true,
        eligibilityReason = "",
        progressionScope = "life",
        reputationBonusMilli = 0,
        cooldownSeconds = 0,
        hasteBonusMilli = 0,
        hasteSecondsRemaining = 0,
        hasteActive = false,
        name = "Paragon",
        summary = "Waiting for authoritative server state.",
    },
    notice = nil,
}

local rarities = {
    [0] = { name = "Unknown", color = { 0.62, 0.62, 0.62 } },
    [1] = { name = "Common", color = { 0.90, 0.90, 0.90 } },
    [2] = { name = "Uncommon", color = { 0.12, 1.00, 0.12 } },
    [3] = { name = "Rare", color = { 0.15, 0.48, 1.00 } },
    [4] = { name = "Epic", color = { 0.64, 0.21, 0.93 } },
    [5] = { name = "Legendary", color = { 1.00, 0.50, 0.08 } },
    [6] = { name = "Mythic", color = { 0.35, 0.90, 1.00 } },
}

local notices = {
    accepted = "Skill accepted. Ownership was recorded by the server.",
    declined = "Skill offer declined. The decision was recorded by the server.",
    selected = "Heritage selected and locked for this current Life.",
    already_selected = "This Heritage is already locked for the current Life.",
    locked_to_different_heritage = "A different Heritage is already locked for this Life.",
    denied_actor = "Only an authenticated human player can use this progression action.",
    disabled = "This Rebirth progression action is currently disabled.",
    no_open_offer = "There is no open Skill offer.",
    invalid_choice = "That Manifestation choice is not available.",
    stale_offer = "That Manifestation changed. Fresh choices are being requested.",
    expired_offer = "That Manifestation expired. Fresh state is being requested.",
    capacity_blocked = "No Skill slot is currently available.",
    conflict = "The Skill state changed. The panel has been refreshed.",
    persistence_failed = "The server could not persist that action.",
    schema_unavailable = "The Rebirth Skill service is temporarily unavailable.",
    unsupported_version = "This addon protocol does not match the server.",
    malformed = "The server rejected a malformed addon request.",
    unknown_request = "The server rejected an unknown addon request.",
    inspect_target_unavailable = "That player or PlayerBot is not currently available for build inspection.",
    ineligible_race = "This Heritage is not available to your current race.",
}

local function Rarity(id)
    return rarities[tonumber(id) or 0] or rarities[0]
end

local function SetButtonEnabled(button, enabled)
    if enabled then
        button:Enable()
    else
        button:Disable()
    end
end

local function SplitTabs(value)
    local fields = {}
    value = (value or "") .. "\t"
    for field in string.gmatch(value, "([^\t]*)\t") do
        table.insert(fields, field)
    end
    return fields
end

local function DecodeField(value)
    return string.gsub(value or "", "%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end)
end

local function HumanizeCode(value)
    local text = string.gsub(value or "", "_", " ")
    return text ~= "" and text or "unclassified"
end

local function FormatMilliValue(valueMilli, unitCode)
    local value = (tonumber(valueMilli) or 0) / 1000
    local numberText
    if value == math.floor(value) then
        numberText = string.format("%d", value)
    else
        numberText = string.format("%.2f", value)
        numberText = string.gsub(numberText, "0+$", "")
        numberText = string.gsub(numberText, "%.$", "")
    end
    if unitCode == "percent" or unitCode == "percentage_points" then
        return numberText .. "%"
    end
    return numberText .. " " .. HumanizeCode(unitCode)
end

local function IsLocalPlayerSender(sender)
    local playerName = UnitName and UnitName("player")
    if not playerName or playerName == "" or not sender or sender == "" then
        return false
    end

    return sender == playerName
end

local function UpdateActivation()
    active = (GetRealmName and GetRealmName() or "") == REALM
    if toggleButton then
        if active then
            toggleButton:Show()
        else
            toggleButton:Hide()
        end
    end
    if panel and not active then
        panel:Hide()
    end
    if choiceFrame and not active then
        choiceFrame:Hide()
    end
end

local function SendRequest(request)
    if not active or not SendAddonMessage or not UnitName("player") then
        return
    end
    SendAddonMessage(PREFIX, PROTOCOL .. "\t" .. request, "WHISPER", UnitName("player"))
end

local function ApplyCardBackdrop(frame, red, green, blue)
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 14,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(red or 0.035, green or 0.045, blue or 0.07, 0.98)
    frame:SetBackdropBorderColor(0.28, 0.34, 0.45, 1)
end

local function ParseInteger(value, minimum, maximum)
    if not value or not string.match(value, "^-?%d+$") then
        return nil
    end
    local number = tonumber(value)
    if not number or number ~= math.floor(number) or number < minimum or number > maximum then
        return nil
    end
    return number
end

local function IsEncodedField(value)
    if value == nil or string.len(value) > 220 then
        return false
    end
    local offset = 1
    while true do
        local marker = string.find(value, "%", offset, true)
        if not marker then
            return true
        end
        if marker + 2 > string.len(value) or not string.match(string.sub(value, marker + 1, marker + 2), "^%x%x$") then
            return false
        end
        offset = marker + 3
    end
end

local function UpdatePendingIndicator()
    local pending = state.offer ~= nil and not state.offer.expired
    if pendingGlow then
        if pending then
            pendingGlow:Show()
            toggleButton:SetScript("OnUpdate", function()
                pendingGlow:SetAlpha(0.42 + (0.20 * math.sin((GetTime() or 0) * 4)))
            end)
        else
            pendingGlow:Hide()
            toggleButton:SetScript("OnUpdate", nil)
        end
    end
    if pendingCount then
        pendingCount:SetText(pending and tostring(state.offer.count or 0) or "")
        if pending then pendingCount:Show() else pendingCount:Hide() end
    end
end

local function ClearOfferState()
    state.offer = nil
    selectedChoiceOrdinal = nil
    selectedChoiceOpportunityId = nil
    offerAssembly = nil
    deferredOfferReveal = false
    reopenChoiceAfterSnapshot = false
    if choiceFrame then
        choiceFrame:Hide()
    end
    UpdatePendingIndicator()
end

local function RejectOfferSnapshot(reason)
    offerAssembly = nil
    state.offer = nil
    selectedChoiceOrdinal = nil
    selectedChoiceOpportunityId = nil
    deferredOfferReveal = false
    if choiceFrame then choiceFrame:Hide() end
    state.notice = reason or "The server sent an incomplete Manifestation choice set; refreshing."
    UpdatePendingIndicator()
    local now = GetTime and GetTime() or 0
    if now == 0 or now - lastOfferResyncAt >= 1 then
        lastOfferResyncAt = now
        SendRequest("STATE")
    end
    if Render then Render() end
end

local function ConfigureGridButton(button, size)
    button:SetWidth(size)
    button:SetHeight(size)
    ApplyCardBackdrop(button, 0.02, 0.025, 0.04)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 4, -4)
    button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4, 4)
    button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    button.selection = button:CreateTexture(nil, "OVERLAY")
    button.selection:SetAllPoints(button.icon)
    button.selection:SetTexture("Interface\\Buttons\\CheckButtonHilight")
    button.selection:SetBlendMode("ADD")
    button.selection:Hide()

    button.rank = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    button.rank:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -5, 5)

    button:SetScript("OnEnter", function(self)
        if not self.tooltipName then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(self.tooltipName, 1, 1, 1)
        if self.tooltipMeta then
            GameTooltip:AddLine(self.tooltipMeta, 0.80, 0.82, 0.88, true)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

local function HideGridButtons(buttons)
    for _, button in ipairs(buttons) do
        button:Hide()
    end
end

local function FindSkill(skillId)
    for _, skill in ipairs(state.skills) do
        if skill.id == skillId then
            return skill
        end
    end
    return nil
end

local function FindHeritage(heritageId)
    for _, heritage in ipairs(state.heritages or {}) do
        if tonumber(heritage.id) == tonumber(heritageId) then
            return heritage
        end
    end
    return nil
end

local function AcquireSkillButton(index)
    if skillButtons[index] then
        return skillButtons[index]
    end
    local button = CreateFrame("Button", nil, skillGridChild)
    ConfigureGridButton(button, 42)
    button:SetScript("OnClick", function(self)
        selectedSkillId = self.entryId
        Render()
    end)
    skillButtons[index] = button
    return button
end

local function AcquireHeritageButton(index)
    if heritageButtons[index] then
        return heritageButtons[index]
    end
    local button = CreateFrame("Button", nil, heritageGridChild)
    ConfigureGridButton(button, 54)
    button:SetScript("OnClick", function(self)
        selectedHeritageId = self.entryId
        Render()
    end)
    heritageButtons[index] = button
    return button
end

local function GetFilteredSkills()
    local filtered = {}
    local query = searchBox and string.lower(searchBox:GetText() or "") or ""
    for _, skill in ipairs(state.skills) do
        local name = string.lower(skill.name or "")
        if query == "" or string.find(name, query, 1, true) then
            table.insert(filtered, skill)
        end
    end
    return filtered
end

local function RenderLoadoutSlots()
    for index, slot in ipairs(loadoutSlots) do
        local skill = state.skills[index]
        slot.entryId = skill and skill.id or nil
        slot.rank:SetText(skill and skill.rank > 0 and skill.rank or "")
        slot.icon:SetTexture(skill and (skill.icon or SKILL_ICON) or SKILL_ICON)
        slot.icon:SetDesaturated(not skill)
        slot.lock:Hide()
        slot:SetBackdropBorderColor(0.28, 0.34, 0.45, 1)
        if index > state.capacity then
            slot.lock:Show()
            slot:SetBackdropBorderColor(0.26, 0.26, 0.28, 1)
        elseif skill then
            local rarity = Rarity(skill.rarityId)
            slot:SetBackdropBorderColor(rarity.color[1], rarity.color[2], rarity.color[3], 1)
        end
        if skill and index > state.capacity then
            slot.lock:Hide()
            slot:SetBackdropBorderColor(1.00, 0.25, 0.25, 1)
        end
        slot.tooltipName = skill and skill.name or (index > state.capacity and "Locked Skill slot" or "Available Skill slot")
        slot.tooltipMeta = skill and string.format("Current Life slot %d • Rank %d", index, skill.rank) or
            (index > state.capacity and "Unlocks through Rebirth progression." or "No Skill occupies this slot.")
    end
end

local function RenderSkillTab()
    if inspectButton then
        inspectButton:SetText(state.inspectedName and "My Build" or "Inspect Target")
    end
    capacityText:SetText(string.format("Current Life Slots: |cff73e6ff%d / %d|r", state.owned, state.capacity))
    if state.inspectedName then
        capacityText:SetText(string.format("Inspecting |cff73e6ff%s|r: %d / %d Skills",
            state.inspectedName, state.owned, state.capacity))
    end
    if state.owned > state.capacity then
        capacityText:SetText(string.format("Current Life Slots: |cffff6666%d / %d — protected overflow|r", state.owned, state.capacity))
    end
    RenderLoadoutSlots()

    local filteredSkills = GetFilteredSkills()
    skillCountLabel:SetText(string.format("%sSkill Library (%d)%s",
        state.inspectedName and (state.inspectedName .. " — ") or "Owned ", state.total,
        state.complete and "" or " — partial display"))
    if #state.skills == 0 then
        skillCountLabel:SetText(state.ownershipAvailable and "Owned Skill Library (0)" or "Owned Skill Library — unavailable")
    elseif #filteredSkills ~= #state.skills then
        skillCountLabel:SetText(string.format("Owned Skill Library (%d shown / %d)", #filteredSkills, state.total))
    end

    local selectedVisible = false
    for _, skill in ipairs(filteredSkills) do
        if selectedSkillId == skill.id then
            selectedVisible = true
            break
        end
    end
    if not selectedSkillId or not FindSkill(selectedSkillId) or not selectedVisible then
        selectedSkillId = filteredSkills[1] and filteredSkills[1].id or nil
    end

    HideGridButtons(skillButtons)
    for index, skill in ipairs(filteredSkills) do
        local button = AcquireSkillButton(index)
        local rarity = Rarity(skill.rarityId)
        local column = (index - 1) % 9
        local row = math.floor((index - 1) / 9)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", skillGridChild, "TOPLEFT", column * 54, -(row * 54))
        button.icon:SetTexture(skill.icon or SKILL_ICON)
        button:SetBackdropBorderColor(rarity.color[1], rarity.color[2], rarity.color[3], 1)
        button.rank:SetText(skill.rank > 0 and skill.rank or "")
        button.tooltipName = skill.name
        button.tooltipMeta = string.format("%s • Rank %d • Skill XP inactive • %s", rarity.name,
            skill.rank, FormatMilliValue(skill.valueMilli, skill.unit))
        button.entryId = skill.id
        if selectedSkillId == skill.id then
            button.selection:Show()
        else
            button.selection:Hide()
        end
        button:Show()
    end
    skillGridChild:SetHeight(math.max(5, math.ceil(math.max(#filteredSkills, 1) / 9)) * 54)

    local skill = selectedSkillId and FindSkill(selectedSkillId) or nil
    if not skill then
        skillDetailIcon:SetTexture(SKILL_ICON)
        skillDetailName:SetText("No owned Skill selected")
        skillDetailName:SetTextColor(0.62, 0.62, 0.62)
        skillDetailMeta:SetText("Acquire a Skill to populate this detail pane.")
        skillDetailSummary:SetText("Skill rarity, experience, Rank, tier, and effect text will appear here.")
        skillDetailFrame:SetBackdropBorderColor(0.28, 0.34, 0.45, 1)
        return
    end

    local rarity = Rarity(skill.rarityId)
    local tierText = skill.tier and skill.tier > 0 and ("Tier " .. skill.tier) or "Tier WIP"
    skillDetailIcon:SetTexture(skill.icon or SKILL_ICON)
    skillDetailName:SetText(skill.name)
    skillDetailName:SetTextColor(rarity.color[1], rarity.color[2], rarity.color[3])
    skillDetailMeta:SetText(string.format("%s  •  Rank %d  •  Skill XP inactive  •  %s%s", rarity.name,
        skill.rank, tierText, skill.effects and "  •  test effect active" or "  •  test effect inactive"))
    local valueText = FormatMilliValue(skill.valueMilli, skill.unit)
    local bucketTotalText = FormatMilliValue(skill.bucketTotalMilli, skill.unit)
    skillDetailSummary:SetText((skill.summary or "") ..
        "\n\n|cff20ff20Skill bonus: " .. valueText .. "|r" ..
        "\n|cff73e6ffStacking bucket:|r " .. HumanizeCode(skill.bucket) ..
        "  |cff9aa6bf(combined " .. bucketTotalText .. ")|r" ..
        "\n|cff73e6ffRuntime adapter:|r " .. HumanizeCode(skill.adapter) ..
        ((skill.runtimeDetail and skill.runtimeDetail ~= "") and
            ("\n|cff20ff20Runtime state:|r " .. skill.runtimeDetail) or "") ..
        (skill.bucket == "attack_power_pct" and
            "\n|cff20ff20Character sheet:|r green AP is the current percentage-derived point equivalent." or ""))
    skillDetailFrame:SetBackdropBorderColor(rarity.color[1], rarity.color[2], rarity.color[3], 1)
end

local function RenderHeritageTab()
    local heritages = state.heritages or {}
    if #heritages == 0 and state.heritage then
        heritages = { state.heritage }
    end
    local heritage = FindHeritage(selectedHeritageId)
    if not heritage then
        for _, entry in ipairs(heritages) do
            if entry.selected then
                heritage = entry
                break
            end
        end
    end
    heritage = heritage or heritages[1] or state.heritage or {}
    heritage.id = tonumber(heritage.id) or 1101
    heritage.rank = tonumber(heritage.rank) or 0
    heritage.xp = tonumber(heritage.xp) or 0
    heritage.maxRank = tonumber(heritage.maxRank) or 100
    heritage.nextThreshold = tonumber(heritage.nextThreshold) or 0
    heritage.bonusMilli = tonumber(heritage.bonusMilli) or 0
    heritage.eligible = heritage.eligible ~= false
    heritage.eligibilityReason = heritage.eligibilityReason or ""
    heritage.progressionScope = heritage.progressionScope or "life"
    heritage.reputationBonusMilli = tonumber(heritage.reputationBonusMilli) or 0
    heritage.cooldownSeconds = tonumber(heritage.cooldownSeconds) or 0
    heritage.hasteBonusMilli = tonumber(heritage.hasteBonusMilli) or 0
    heritage.hasteSecondsRemaining = tonumber(heritage.hasteSecondsRemaining) or 0
    heritage.hasteActive = heritage.hasteActive == true
    heritage.name = heritage.name ~= "" and heritage.name or "Paragon"
    heritage.summary = heritage.summary ~= "" and heritage.summary or
        "Gain 10% of source experience as Heritage XP. Each Rank grants +0.1% to all primary stats."
    selectedHeritageId = heritage.id
    heritageCountLabel:SetText(string.format("Heritages (%d available)", #heritages))

    HideGridButtons(heritageButtons)
    for index, entry in ipairs(heritages) do
        local button = AcquireHeritageButton(index)
        local column = (index - 1) % 4
        local row = math.floor((index - 1) / 4)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", heritageGridChild, "TOPLEFT", column * 68, -(row * 62))
        button.icon:SetTexture(HERITAGE_ICON)
        button.entryId = entry.id or 1101
        button.rank:SetText((tonumber(entry.rank) or 0) > 0 and entry.rank or "")
        button.tooltipName = entry.name or "Paragon"
        local scopeLabel = entry.progressionScope == "character" and "Persists across Rebirth" or "Current Life"
        if entry.eligible == false then
            button.tooltipMeta = (entry.eligibilityReason ~= "" and entry.eligibilityReason or "Unavailable to your current race") ..
                " • " .. scopeLabel
        elseif entry.selected then
            button.tooltipMeta = string.format("Rank %d / %d • %d XP • %s all stats • %s • Locked",
                tonumber(entry.rank) or 0, tonumber(entry.maxRank) or 100,
                tonumber(entry.xp) or 0, FormatMilliValue(entry.bonusMilli, "percent"), scopeLabel)
        else
            button.tooltipMeta = string.format("Not selected • Rank 1–%d • %s",
                tonumber(entry.maxRank) or 0, scopeLabel)
        end
        button.icon:SetDesaturated(entry.eligible == false)
        if selectedHeritageId == button.entryId then
            button.selection:Show()
        else
            button.selection:Hide()
        end
        if entry.eligible == false then
            button:SetBackdropBorderColor(0.35, 0.35, 0.38, 1)
        else
            button:SetBackdropBorderColor(0.45, 0.90, 1.00, 1)
        end
        button:Show()
    end
    heritageGridChild:SetHeight(math.max(3, math.ceil(#heritages / 4)) * 62)

    heritageDetailIcon:SetTexture(HERITAGE_ICON)
    heritageDetailName:SetText(heritage.name or "Paragon")
    heritageDetailName:SetTextColor(0.45, 0.90, 1.00)
    local progressText
    if heritage.selected and heritage.rank >= heritage.maxRank then
        progressText = "Maximum Rank reached"
    elseif heritage.selected and heritage.nextThreshold > 0 then
        progressText = string.format("Next Rank at %d total Heritage XP (%d remaining)",
            heritage.nextThreshold, math.max(0, heritage.nextThreshold - heritage.xp))
    else
        progressText = "Progress begins after selection"
    end
    local scopeText = heritage.progressionScope == "character" and
        "Rank and XP persist across Rebirth and become dormant while race-ineligible." or
        "Rank and XP belong to the current Life."
    local eligibilityText = heritage.eligible and "Eligible for your current race" or
        (heritage.eligibilityReason ~= "" and heritage.eligibilityReason or "Unavailable to your current race")
    local effectColor = heritage.selected and heritage.eligible and "|cff20ff20" or "|cff9aa6bf"
    local racialDetails = ""
    if heritage.cooldownSeconds > 0 then
        racialDetails = racialDetails .. "\n|cff73e6ffEvery Man for Himself cooldown:|r " ..
            heritage.cooldownSeconds .. " seconds"
    end
    if heritage.hasteBonusMilli > 0 then
        local hasteState = heritage.hasteActive and "active" or
            (heritage.hasteSecondsRemaining > 0 and "suppressed by a stronger haste effect" or "ready on next successful racial use")
        racialDetails = racialDetails .. "\n|cff73e6ffRacial haste:|r " ..
            FormatMilliValue(heritage.hasteBonusMilli, "percent") .. " for 40 seconds — " .. hasteState
    end
    heritageDetailSummary:SetText((heritage.summary or "") ..
        "\n\n|cff73e6ffEligibility:|r " .. eligibilityText ..
        "\n|cff73e6ffProgression:|r " .. scopeText ..
        "\n" .. effectColor .. "Current all-stat bonus: " .. FormatMilliValue(heritage.bonusMilli, "percent") .. "|r" ..
        (heritage.reputationBonusMilli > 0 and
            ("\n" .. effectColor .. "Positive reputation bonus: " ..
                FormatMilliValue(heritage.reputationBonusMilli, "percent") .. "|r") or "") ..
        racialDetails ..
        "\n|cff73e6ffProgress:|r " .. progressText ..
        "\n|cff9aa6bfHeritage receives exactly 10% of eligible source XP; fractional credit is retained.|r")
    if heritage.selected then
        heritageDetailMeta:SetText(string.format("Rank %d / %d  •  %d XP  •  %s all stats  •  Locked",
            heritage.rank, heritage.maxRank, heritage.xp,
            FormatMilliValue(heritage.bonusMilli, "percent")))
        if heritage.eligible then
            heritageWarning:SetText(heritage.progressionScope == "character" and
                "Selected permanently; its progression persists across Rebirth." or
                "This Heritage is permanently selected for the current Life.")
        else
            heritageWarning:SetText("Selected but dormant: " .. eligibilityText)
        end
        heritageButton:SetText("Selected")
        SetButtonEnabled(heritageButton, false)
    else
        heritageDetailMeta:SetText(string.format("Not selected  •  Ranks 1–%d",
            heritage.maxRank))
        if not heritage.eligible then
            heritageWarning:SetText(eligibilityText)
        elseif heritage.progressionScope == "character" then
            heritageWarning:SetText("Selection is permanent; Rank and XP persist across Rebirth.")
        else
            heritageWarning:SetText("Selection is permanent for this current Life.")
        end
        heritageButton:SetText("Select Heritage")
        SetButtonEnabled(heritageButton, heritage.canSelect and not actionPending)
    end
end

local function ChoiceDetailText(choice)
    local rankCurve = choice.rankCurve
    if tonumber(rankCurve) then
        rankCurve = "Curve " .. rankCurve .. " (server-authoritative Tier " .. tostring(choice.tier) .. " schedule)"
    else
        rankCurve = HumanizeCode(rankCurve)
    end
    return (choice.detail ~= "" and choice.detail or choice.shortEffect or "") ..
        "\n\n|cff73e6ffRank I value:|r |cff20ff20" .. FormatMilliValue(choice.valueMilli, choice.unit) .. "|r" ..
        "\n|cff73e6ffXP / Rank curve:|r " .. rankCurve ..
        "\n|cff73e6ffStacking:|r " .. HumanizeCode(choice.stacking) ..
        "\n|cff73e6ffStacking bucket:|r " .. HumanizeCode(choice.bucket) ..
        "\n|cff73e6ffRuntime adapter:|r " .. HumanizeCode(choice.adapter) ..
        "\n|cff73e6ffSource:|r " .. (choice.sourceContext ~= "" and choice.sourceContext or "Manifestation")
end

local function OfferFingerprint(offer)
    local parts = { tostring(offer.count), offer.expired and "1" or "0" }
    for ordinal = 1, offer.count do
        local choice = offer.choices[ordinal]
        table.insert(parts, table.concat({ tostring(choice.skillId), tostring(choice.rarityId),
            tostring(choice.tier), choice.name, choice.shortEffect, choice.detail, choice.sourceContext,
            tostring(choice.valueMilli), choice.unit, choice.bucket, choice.adapter, choice.rankCurve,
            choice.stacking }, "|"))
    end
    return table.concat(parts, "#")
end

local function AcquireChoiceCard(index)
    if choiceCards[index] then
        return choiceCards[index]
    end

    local card = CreateFrame("Button", nil, choiceFrame)
    card:SetWidth(596)
    card:RegisterForClicks("LeftButtonUp")
    ApplyCardBackdrop(card, 0.025, 0.035, 0.075)
    card.highlight = card:CreateTexture(nil, "BACKGROUND")
    card.highlight:SetPoint("TOPLEFT", card, "TOPLEFT", 5, -5)
    card.highlight:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -5, 5)
    card.highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    card.highlight:SetBlendMode("ADD")
    card.highlight:SetAlpha(0.22)
    card.highlight:Hide()
    card.icon = card:CreateTexture(nil, "ARTWORK")
    card.icon:SetWidth(54)
    card.icon:SetHeight(54)
    card.icon:SetPoint("TOPLEFT", card, "TOPLEFT", 16, -16)
    card.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    card.name = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    card.name:SetPoint("TOPLEFT", card, "TOPLEFT", 84, -15)
    card.name:SetPoint("RIGHT", card, "RIGHT", -18, 0)
    card.name:SetJustifyH("LEFT")
    card.meta = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.meta:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -4)
    card.meta:SetPoint("RIGHT", card, "RIGHT", -18, 0)
    card.meta:SetJustifyH("LEFT")
    card.short = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    card.short:SetPoint("TOPLEFT", card.meta, "BOTTOMLEFT", 0, -5)
    card.short:SetPoint("RIGHT", card, "RIGHT", -18, 0)
    card.short:SetJustifyH("LEFT")
    card.details = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.details:SetPoint("TOPLEFT", card, "TOPLEFT", 18, -88)
    card.details:SetPoint("RIGHT", card, "RIGHT", -18, 0)
    card.details:SetJustifyH("LEFT")
    card.details:SetJustifyV("TOP")
    card.details:Hide()
    card:SetScript("OnClick", function(self)
        if actionPending or not self.choiceOrdinal then return end
        selectedChoiceOrdinal = self.choiceOrdinal
        selectedChoiceOpportunityId = state.offer and state.offer.opportunityId or nil
        RenderChoiceFrame()
    end)
    card:SetScript("OnEnter", function(self)
        if not self.choice then return end
        local rarity = Rarity(self.choice.rarityId)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(self.choice.name, rarity.color[1], rarity.color[2], rarity.color[3])
        GameTooltip:AddLine(self.choice.shortEffect or "", 1, 1, 1, true)
        GameTooltip:AddLine(ChoiceDetailText(self.choice), 0.72, 0.82, 1.00, true)
        GameTooltip:Show()
    end)
    card:SetScript("OnLeave", function() GameTooltip:Hide() end)
    choiceCards[index] = card
    return card
end

RenderChoiceFrame = function()
    if not choiceFrame then return end
    local offer = state.offer
    if not offer then
        choiceFrame:Hide()
        return
    end

    choiceSubtitle:SetText(string.format("Choose one permanent Skill  •  Life %d  •  %d choice%s",
        state.lifeId > 0 and state.lifeId or 1, offer.count, offer.count == 1 and "" or "s"))
    local top = -88
    local totalCardHeight = 0
    for index = 1, 3 do
        local card = AcquireChoiceCard(index)
        local choice = offer.choices[index]
        if choice then
            local selected = selectedChoiceOrdinal == choice.ordinal
            local height = selected and 190 or 90
            local rarity = Rarity(choice.rarityId)
            local tierText = choice.tier > 0 and ("Tier " .. choice.tier) or "Tier WIP"
            card:ClearAllPoints()
            card:SetPoint("TOP", choiceFrame, "TOP", 0, top)
            card:SetHeight(height)
            card.choiceOrdinal = choice.ordinal
            card.choice = choice
            card.icon:SetTexture(choice.icon ~= "" and choice.icon or OFFER_ICON)
            card.name:SetText(choice.name)
            card.name:SetTextColor(rarity.color[1], rarity.color[2], rarity.color[3])
            card.meta:SetText(string.format("%s  •  %s  •  Choice %d", rarity.name, tierText, choice.ordinal))
            card.short:SetText(choice.shortEffect)
            card.details:SetText(ChoiceDetailText(choice))
            card.highlight:SetVertexColor(rarity.color[1], rarity.color[2], rarity.color[3])
            card:SetBackdropBorderColor(rarity.color[1], rarity.color[2], rarity.color[3], selected and 1 or 0.82)
            if selected then
                card.highlight:Show()
                card.details:Show()
            else
                card.highlight:Hide()
                card.details:Hide()
            end
            card:Show()
            top = top - height - 10
            totalCardHeight = totalCardHeight + height + 10
        else
            card.choiceOrdinal = nil
            card.choice = nil
            card:Hide()
        end
    end

    choiceFrame:SetHeight(146 + totalCardHeight)
    SetButtonEnabled(claimButton, selectedChoiceOrdinal ~= nil and not offer.expired and not actionPending)
    SetButtonEnabled(declineAllButton, not actionPending)
    SetButtonEnabled(laterButton, not actionPending)
end

ShowManifestationChoices = function(firstReveal)
    if not state.offer or state.offer.expired then return end
    if (UnitAffectingCombat and UnitAffectingCombat("player")) or
        (InCombatLockdown and InCombatLockdown()) then
        deferredOfferReveal = true
        UpdatePendingIndicator()
        return
    end

    deferredOfferReveal = false
    if selectedChoiceOpportunityId ~= state.offer.opportunityId or not selectedChoiceOrdinal or
        not state.offer.choices[selectedChoiceOrdinal] then
        selectedChoiceOrdinal = nil
        selectedChoiceOpportunityId = nil
    end
    RenderChoiceFrame()
    choiceFrame:Show()
    if firstReveal and revealedOpportunityId ~= state.offer.opportunityId then
        revealedOpportunityId = state.offer.opportunityId
        if UIFrameFadeIn then UIFrameFadeIn(choiceFrame, 0.22, 0, 1) end
        if PlaySound then PlaySound("igQuestListOpen") end
        choiceFrame.revealGlow:SetAlpha(0.58)
        choiceFrame.revealGlow:Show()
        choiceFrame.revealElapsed = 0
        choiceFrame:SetScript("OnUpdate", function(self, elapsed)
            self.revealElapsed = self.revealElapsed + elapsed
            self.revealGlow:SetAlpha(math.max(0, 0.58 * (1 - self.revealElapsed)))
            if self.revealElapsed >= 1 then
                self.revealGlow:Hide()
                self:SetScript("OnUpdate", nil)
            end
        end)
    end
end

local function CommitOfferSnapshot(offer)
    if resolvedOpportunities[offer.opportunityId] then
        RejectOfferSnapshot("A resolved Manifestation snapshot was discarded; refreshing.")
        return
    end
    if offerVersions[offer.opportunityId] and offer.rowVersion < offerVersions[offer.opportunityId] then
        RejectOfferSnapshot("A stale Manifestation snapshot was discarded; refreshing.")
        return
    end
    if offer.expired then
        RejectOfferSnapshot("That Manifestation has expired; refreshing authoritative state.")
        return
    end
    local fingerprint = OfferFingerprint(offer)
    if offerFingerprints[offer.opportunityId] and offerFingerprints[offer.opportunityId] ~= fingerprint then
        RejectOfferSnapshot("A conflicting Manifestation snapshot was discarded; refreshing.")
        return
    end
    local wasOpen = reopenChoiceAfterSnapshot
    if selectedChoiceOpportunityId ~= offer.opportunityId then
        selectedChoiceOrdinal = nil
        selectedChoiceOpportunityId = nil
    end
    state.offer = offer
    offerVersions[offer.opportunityId] = offer.rowVersion
    offerFingerprints[offer.opportunityId] = fingerprint
    offerAssembly = nil
    reopenChoiceAfterSnapshot = false
    UpdatePendingIndicator()
    if wasOpen then
        ShowManifestationChoices(false)
    elseif revealedOpportunityId ~= offer.opportunityId then
        ShowManifestationChoices(true)
    elseif choiceFrame and choiceFrame:IsShown() then
        RenderChoiceFrame()
    end
    if Render then Render() end
end

local function RenderManifestationTab()
    if not state.offer then
        offerFrame:SetBackdropBorderColor(0.28, 0.34, 0.45, 1)
        offerIcon:SetTexture(OFFER_ICON)
        offerName:SetText("No active Manifestation")
        offerName:SetTextColor(0.62, 0.62, 0.62)
        offerRarity:SetText("The server has no open Skill choice for this Life.")
        offerSummary:SetText("New Manifestations appear here after the server freezes every eligible choice. " ..
            "Closing a choice window safely postpones it without changing server state.")
        acceptButton:Hide()
        declineButton:Hide()
        return
    end

    offerFrame:SetBackdropBorderColor(0.42, 0.34, 0.78, 1)
    offerIcon:SetTexture(BRAND_TEXTURE)
    offerName:SetText("Manifestation awaiting your choice")
    offerName:SetTextColor(0.55, 0.82, 1.00)
    offerRarity:SetText(string.format("%d frozen Skill choice%s  •  Opportunity %d",
        state.offer.count, state.offer.count == 1 and "" or "s", state.offer.opportunityId))
    offerSummary:SetText("Select one permanent, capacity-consuming Rebirth Skill from the server-authored choices. " ..
        "Later, Close, and Escape postpone without mutation. Decline All permanently resolves the entire offer.")
    acceptButton:SetText("View Choices")
    acceptButton:SetWidth(112)
    acceptButton:Show()
    declineButton:Hide()
    SetButtonEnabled(acceptButton, not actionPending)
end

local function RenderRebirthTab()
    local level = UnitLevel("player") or 0
    local life = state.lifeId > 0 and state.lifeId or 1
    local heritage = state.heritage
    rebirthLifeText:SetText(string.format("Life %d", life))
    rebirthLevelText:SetText(string.format("Current Level\n|cffffffff%d / 80|r", level))
    rebirthCapacityText:SetText(string.format("Skill Capacity\n|cffffffff%d owned / %d slots|r", state.owned, state.capacity))
    rebirthHeritageText:SetText(string.format("Current Heritage\n|cffffffff%s|r",
        heritage.selected and (heritage.name or "Selected") or "Not selected"))

    local levelState = level >= 80 and "|cff66ff66Ready|r" or "|cffffcc55Reach level 80|r"
    rebirthEligibilityText:SetText(
        "Rebirth Eligibility\n\n" ..
        "1. Level requirement: " .. levelState .. "\n" ..
        "2. Safe-zone or city check: |cff999999server verification pending|r\n" ..
        "3. Heirloom Skill retention review: |cff999999transaction preview pending|r\n" ..
        "4. Final confirmation: |cff999999locked until the Rebirth writer is enabled|r")
    rebirthNextText:SetText(
        "Next Life Preview\n\n" ..
        "This page intentionally exposes no Rebirth button yet. The server must first provide the exact " ..
        "RXP award, retained Heirloom Skills, resulting slot overflow, Heritage transition, and safe-zone " ..
        "eligibility in one authoritative preview. Until then, this is a read-only progression record.")
end

local function RenderTabs()
    for _, name in ipairs(tabOrder) do
        local frame = tabFrames[name]
        local button = tabButtons[name]
        if name == activeTab then
            frame:Show()
            SetButtonEnabled(button, false)
        else
            frame:Hide()
            SetButtonEnabled(button, true)
        end
    end
    if activeTab == "skills" then
        footnote:SetText("Tier-1 values and stacking totals are server authoritative test data; Skill XP awards are not active yet.")
    elseif activeTab == "heritages" then
        footnote:SetText("Heritage selection is permanent for the current Life; Paragon XP and stat effects are server authoritative.")
    elseif activeTab == "manifestations" then
        footnote:SetText("Manifestation decisions are persisted by the server; PlayerBots remain excluded.")
    elseif activeTab == "rebirth" then
        footnote:SetText("Rebirth remains read-only until the server can preview and commit the complete safe-zone transaction.")
    end
end

Render = function()
    if not panel then
        return
    end

    local status = state.notice or ("Server state: " .. string.gsub(state.status or "unknown", "_", " "))
    statusText:SetText(status)
    statusText:SetTextColor(state.notice and 1.0 or 0.68, state.notice and 0.82 or 0.72,
        state.notice and 0.28 or 0.82)

    RenderTabs()
    if activeTab == "skills" then
        RenderSkillTab()
    elseif activeTab == "heritages" then
        RenderHeritageTab()
    elseif activeTab == "manifestations" then
        RenderManifestationTab()
    elseif activeTab == "rebirth" then
        RenderRebirthTab()
    else
        RenderRebirthTab()
    end
end

local function SelectTab(name)
    if tabFrames[name] then
        activeTab = name
        Render()
    end
end

local function ConfirmHeritageSelection()
    local heritage = FindHeritage(selectedHeritageId)
    heritage = heritage or state.heritage or {}
    if actionPending or heritage.selected or not heritage.canSelect then
        return
    end

    actionPending = true
    state.notice = "Waiting for server Heritage selection…"
    Render()
    SendRequest("HERITAGE_SELECT\t" .. tostring(heritage.id or 0))
end

StaticPopupDialogs.PROJECT_REBIRTH_CONFIRM_HERITAGE = {
    text = "Select %s as your Heritage?\n\n%s",
    button1 = "Select Heritage",
    button2 = CANCEL,
    OnAccept = ConfirmHeritageSelection,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function ConfirmManifestationDecline()
    if actionPending or not state.offer then return end
    local opportunityId = state.offer.opportunityId
    actionPending = true
    state.notice = "Waiting for the server to decline every choice…"
    SendRequest("DECLINE\t" .. tostring(opportunityId))
    RenderChoiceFrame()
    if Render then Render() end
end

StaticPopupDialogs.PROJECT_REBIRTH_CONFIRM_MANIFESTATION_DECLINE = {
    text = "Decline all %d Manifestation choices?\n\nThis permanently resolves the offer without granting a Skill.",
    button1 = "Decline All",
    button2 = CANCEL,
    OnAccept = ConfirmManifestationDecline,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function CreateManifestationChoiceInterface()
    choiceFrame = CreateFrame("Frame", "ProjectRebirthManifestationChoiceFrame", UIParent)
    choiceFrame:SetWidth(640)
    choiceFrame:SetHeight(446)
    choiceFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 28)
    choiceFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    choiceFrame:SetFrameLevel(120)
    choiceFrame:SetClampedToScreen(true)
    choiceFrame:EnableMouse(true)
    choiceFrame:SetMovable(true)
    choiceFrame:RegisterForDrag("LeftButton")
    choiceFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    choiceFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    choiceFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 28,
        insets = { left = 9, right = 9, top = 9, bottom = 9 },
    })
    choiceFrame:SetBackdropColor(0.018, 0.025, 0.07, 0.98)
    choiceFrame:SetBackdropBorderColor(0.40, 0.32, 0.74, 1)
    choiceFrame:Hide()

    choiceFrame.revealGlow = choiceFrame:CreateTexture(nil, "OVERLAY")
    choiceFrame.revealGlow:SetPoint("TOPLEFT", choiceFrame, "TOPLEFT", 4, -4)
    choiceFrame.revealGlow:SetPoint("BOTTOMRIGHT", choiceFrame, "BOTTOMRIGHT", -4, 4)
    choiceFrame.revealGlow:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    choiceFrame.revealGlow:SetBlendMode("ADD")
    choiceFrame.revealGlow:Hide()

    local crest = choiceFrame:CreateTexture(nil, "ARTWORK")
    crest:SetWidth(58)
    crest:SetHeight(58)
    crest:SetPoint("TOPLEFT", choiceFrame, "TOPLEFT", 18, -14)
    crest:SetTexture(BRAND_TEXTURE)
    crest:SetTexCoord(0.04, 0.96, 0.04, 0.96)

    local title = choiceFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", choiceFrame, "TOP", 0, -20)
    title:SetText("A Manifestation Takes Shape")
    title:SetTextColor(0.55, 0.82, 1.00)
    choiceSubtitle = choiceFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    choiceSubtitle:SetPoint("TOP", title, "BOTTOM", 0, -7)
    choiceSubtitle:SetText("Choose one permanent Rebirth Skill")

    local close = CreateFrame("Button", nil, choiceFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", choiceFrame, "TOPRIGHT", -7, -7)
    close:SetScript("OnClick", function()
        deferredOfferReveal = false
        choiceFrame:Hide()
        UpdatePendingIndicator()
    end)

    claimButton = CreateFrame("Button", nil, choiceFrame, "UIPanelButtonTemplate")
    claimButton:SetWidth(120)
    claimButton:SetHeight(24)
    claimButton:SetPoint("BOTTOM", choiceFrame, "BOTTOM", 0, 20)
    claimButton:SetText("Claim Skill")
    claimButton:SetScript("OnClick", function()
        local offer = state.offer
        local choice = offer and selectedChoiceOrdinal and offer.choices[selectedChoiceOrdinal]
        if actionPending or not offer or not choice then return end
        actionPending = true
        state.notice = "Waiting for server acceptance…"
        SendRequest("ACCEPT\t" .. tostring(offer.opportunityId) .. "\t" .. tostring(choice.ordinal))
        RenderChoiceFrame()
        if Render then Render() end
    end)

    declineAllButton = CreateFrame("Button", nil, choiceFrame, "UIPanelButtonTemplate")
    declineAllButton:SetWidth(104)
    declineAllButton:SetHeight(24)
    declineAllButton:SetPoint("RIGHT", claimButton, "LEFT", -16, 0)
    declineAllButton:SetText("Decline All")
    declineAllButton:SetScript("OnClick", function()
        if not state.offer or actionPending then return end
        StaticPopup_Show("PROJECT_REBIRTH_CONFIRM_MANIFESTATION_DECLINE", state.offer.count)
    end)

    laterButton = CreateFrame("Button", nil, choiceFrame, "UIPanelButtonTemplate")
    laterButton:SetWidth(84)
    laterButton:SetHeight(24)
    laterButton:SetPoint("LEFT", claimButton, "RIGHT", 16, 0)
    laterButton:SetText("Later")
    laterButton:SetScript("OnClick", function()
        deferredOfferReveal = false
        choiceFrame:Hide()
        UpdatePendingIndicator()
    end)

    if UISpecialFrames then
        table.insert(UISpecialFrames, "ProjectRebirthManifestationChoiceFrame")
    end
end

local function CreateInterface()
    if panel then
        return
    end

    panel = CreateFrame("Frame", "ProjectRebirthSkillsPanel", UIParent)
    panel:SetWidth(980)
    panel:SetHeight(650)
    panel:SetPoint("CENTER", UIParent, "CENTER", 50, 10)
    panel:SetFrameStrata("DIALOG")
    panel:SetFrameLevel(90)
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(self) self:StartMoving() end)
    panel:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    panel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 24,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    panel:Hide()

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -6)
    close:SetScript("OnClick", function()
        panelWanted = false
        panel:Hide()
    end)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", panel, "TOP", 0, -17)
    title:SetText("Project Reverie")
    title:SetTextColor(0.45, 0.90, 1.00)

    local brand = panel:CreateTexture(nil, "ARTWORK")
    brand:SetWidth(42)
    brand:SetHeight(42)
    brand:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -10)
    brand:SetTexture(BRAND_TEXTURE)
    brand:SetTexCoord(0.04, 0.96, 0.04, 0.96)

    local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 70, -44)
    subtitle:SetText("Rebirth Realm  •  Skills, Heritage, Manifestations, and Life progression")

    local refresh = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    refresh:SetWidth(66)
    refresh:SetHeight(20)
    refresh:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -52, -18)
    refresh:SetText("Refresh")
    refresh:SetScript("OnClick", function()
        state.notice = nil
        SendRequest("STATE")
        Render()
    end)

    local function CreateTabButton(name, label, index)
        local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        button:SetWidth(178)
        button:SetHeight(24)
        button:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 125 + ((index - 1) * 184), 18)
        button:SetText(label)
        button:SetScript("OnClick", function()
            SelectTab(name)
        end)
        tabButtons[name] = button
    end

    CreateTabButton("skills", "Skills", 1)
    CreateTabButton("heritages", "Heritages", 2)
    CreateTabButton("manifestations", "Manifestations", 3)
    CreateTabButton("rebirth", "Rebirth", 4)

    statusText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -66)
    statusText:SetPoint("RIGHT", panel, "RIGHT", -18, 0)
    statusText:SetJustifyH("LEFT")

    tabFrames.skills = CreateFrame("Frame", nil, panel)
    tabFrames.skills:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -88)
    tabFrames.skills:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, 58)

    capacityText = tabFrames.skills:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    capacityText:SetPoint("TOPLEFT", tabFrames.skills, "TOPLEFT", 10, -4)

    inspectButton = CreateFrame("Button", nil, tabFrames.skills, "UIPanelButtonTemplate")
    inspectButton:SetWidth(112)
    inspectButton:SetHeight(22)
    inspectButton:SetPoint("TOPLEFT", tabFrames.skills, "TOPLEFT", 192, 3)
    inspectButton:SetText("Inspect Target")
    inspectButton:SetScript("OnClick", function()
        if state.inspectedName then
            state.notice = "Returning to your Rebirth build…"
            SendRequest("STATE")
            return
        end
        if not UnitExists("target") or not UnitIsPlayer("target") then
            state.notice = "Select a player or PlayerBot first."
            Render()
            return
        end
        local name = UnitName("target")
        if not name or name == "" then
            return
        end
        state.notice = "Requesting " .. name .. "'s public Rebirth build…"
        SendRequest("INSPECT\t" .. name)
        Render()
    end)

    for index = 1, 6 do
        local slot = CreateFrame("Button", nil, tabFrames.skills)
        ConfigureGridButton(slot, 40)
        slot:SetPoint("TOPLEFT", tabFrames.skills, "TOPLEFT", 10 + ((index - 1) * 48), -30)
        slot.lock = slot:CreateTexture(nil, "OVERLAY")
        slot.lock:SetWidth(18)
        slot.lock:SetHeight(18)
        slot.lock:SetPoint("CENTER", slot, "CENTER", 0, 0)
        slot.lock:SetTexture("Interface\\Buttons\\LockButton-Locked-Up")
        slot:SetScript("OnClick", function(self)
            if self.entryId then
                selectedSkillId = self.entryId
                Render()
            end
        end)
        table.insert(loadoutSlots, slot)
    end

    skillCountLabel = tabFrames.skills:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    skillCountLabel:SetPoint("TOPLEFT", tabFrames.skills, "TOPLEFT", 330, -5)

    local searchLabel = tabFrames.skills:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    searchLabel:SetPoint("RIGHT", tabFrames.skills, "TOPRIGHT", -246, -13)
    searchLabel:SetText("Search")
    searchBox = CreateFrame("EditBox", "ProjectRebirthSkillSearchBox", tabFrames.skills, "InputBoxTemplate")
    searchBox:SetWidth(210)
    searchBox:SetHeight(20)
    searchBox:SetPoint("TOPRIGHT", tabFrames.skills, "TOPRIGHT", -26, -3)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(48)
    searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    searchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    searchBox:SetScript("OnTextChanged", function()
        if activeTab == "skills" then Render() end
    end)

    skillGridFrame = CreateFrame("ScrollFrame", "ProjectRebirthSkillIconScrollFrame",
        tabFrames.skills, "UIPanelScrollFrameTemplate")
    skillGridFrame:SetPoint("TOPLEFT", tabFrames.skills, "TOPLEFT", 330, -34)
    skillGridFrame:SetPoint("BOTTOMRIGHT", tabFrames.skills, "BOTTOMRIGHT", -24, 4)
    skillGridChild = CreateFrame("Frame", nil, skillGridFrame)
    skillGridChild:SetWidth(510)
    skillGridChild:SetHeight(430)
    skillGridFrame:SetScrollChild(skillGridChild)

    skillDetailFrame = CreateFrame("Frame", nil, tabFrames.skills)
    skillDetailFrame:SetPoint("TOPLEFT", tabFrames.skills, "TOPLEFT", 0, -82)
    skillDetailFrame:SetPoint("BOTTOMRIGHT", tabFrames.skills, "BOTTOMLEFT", 310, 4)
    ApplyCardBackdrop(skillDetailFrame, 0.035, 0.045, 0.07)
    skillDetailIcon = skillDetailFrame:CreateTexture(nil, "ARTWORK")
    skillDetailIcon:SetWidth(54)
    skillDetailIcon:SetHeight(54)
    skillDetailIcon:SetPoint("TOPLEFT", skillDetailFrame, "TOPLEFT", 14, -14)
    skillDetailIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    skillDetailName = skillDetailFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    skillDetailName:SetPoint("TOPLEFT", skillDetailFrame, "TOPLEFT", 80, -16)
    skillDetailName:SetPoint("RIGHT", skillDetailFrame, "RIGHT", -14, 0)
    skillDetailName:SetJustifyH("LEFT")
    skillDetailMeta = skillDetailFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    skillDetailMeta:SetPoint("TOPLEFT", skillDetailName, "BOTTOMLEFT", 0, -5)
    skillDetailMeta:SetPoint("RIGHT", skillDetailFrame, "RIGHT", -14, 0)
    skillDetailMeta:SetJustifyH("LEFT")
    skillDetailSummary = skillDetailFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    skillDetailSummary:SetPoint("TOPLEFT", skillDetailFrame, "TOPLEFT", 14, -88)
    skillDetailSummary:SetPoint("BOTTOMRIGHT", skillDetailFrame, "BOTTOMRIGHT", -14, 14)
    skillDetailSummary:SetJustifyH("LEFT")
    skillDetailSummary:SetJustifyV("TOP")

    tabFrames.heritages = CreateFrame("Frame", nil, panel)
    tabFrames.heritages:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -88)
    tabFrames.heritages:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, 58)
    heritageCountLabel = tabFrames.heritages:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    heritageCountLabel:SetPoint("TOPLEFT", tabFrames.heritages, "TOPLEFT", 410, -5)
    heritageGridFrame = CreateFrame("ScrollFrame", "ProjectRebirthHeritageIconScrollFrame",
        tabFrames.heritages, "UIPanelScrollFrameTemplate")
    heritageGridFrame:SetPoint("TOPLEFT", tabFrames.heritages, "TOPLEFT", 410, -32)
    heritageGridFrame:SetPoint("TOPRIGHT", tabFrames.heritages, "TOPRIGHT", -24, -28)
    heritageGridFrame:SetPoint("BOTTOM", tabFrames.heritages, "BOTTOM", 0, 4)
    heritageGridChild = CreateFrame("Frame", nil, heritageGridFrame)
    heritageGridChild:SetWidth(450)
    heritageGridChild:SetHeight(430)
    heritageGridFrame:SetScrollChild(heritageGridChild)

    heritageDetailFrame = CreateFrame("Frame", nil, tabFrames.heritages)
    heritageDetailFrame:SetPoint("TOPLEFT", tabFrames.heritages, "TOPLEFT", 0, -2)
    heritageDetailFrame:SetPoint("BOTTOMRIGHT", tabFrames.heritages, "BOTTOMLEFT", 380, 4)
    ApplyCardBackdrop(heritageDetailFrame, 0.035, 0.055, 0.075)
    heritageDetailIcon = heritageDetailFrame:CreateTexture(nil, "ARTWORK")
    heritageDetailIcon:SetWidth(54)
    heritageDetailIcon:SetHeight(54)
    heritageDetailIcon:SetPoint("TOPLEFT", heritageDetailFrame, "TOPLEFT", 14, -14)
    heritageDetailIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    heritageDetailName = heritageDetailFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    heritageDetailName:SetPoint("TOPLEFT", heritageDetailFrame, "TOPLEFT", 80, -16)
    heritageDetailName:SetPoint("RIGHT", heritageDetailFrame, "RIGHT", -14, 0)
    heritageDetailName:SetJustifyH("LEFT")
    heritageDetailMeta = heritageDetailFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    heritageDetailMeta:SetPoint("TOPLEFT", heritageDetailName, "BOTTOMLEFT", 0, -5)
    heritageDetailMeta:SetPoint("RIGHT", heritageDetailFrame, "RIGHT", -14, 0)
    heritageDetailMeta:SetJustifyH("LEFT")
    heritageDetailSummary = heritageDetailFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    heritageDetailSummary:SetPoint("TOPLEFT", heritageDetailFrame, "TOPLEFT", 14, -84)
    heritageDetailSummary:SetPoint("RIGHT", heritageDetailFrame, "RIGHT", -14, 0)
    heritageDetailSummary:SetJustifyH("LEFT")
    heritageWarning = heritageDetailFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    heritageWarning:SetPoint("BOTTOMLEFT", heritageDetailFrame, "BOTTOMLEFT", 14, 42)
    heritageWarning:SetPoint("RIGHT", heritageDetailFrame, "RIGHT", -14, 0)
    heritageWarning:SetJustifyH("LEFT")
    heritageWarning:SetTextColor(1.0, 0.82, 0.28)
    heritageButton = CreateFrame("Button", nil, heritageDetailFrame, "UIPanelButtonTemplate")
    heritageButton:SetWidth(136)
    heritageButton:SetHeight(22)
    heritageButton:SetPoint("BOTTOM", heritageDetailFrame, "BOTTOM", 0, 12)
    heritageButton:SetText("Select Heritage")
    heritageButton:SetScript("OnClick", function()
        local heritage = FindHeritage(selectedHeritageId) or state.heritage or {}
        if actionPending or heritage.selected or not heritage.canSelect or heritage.eligible == false then
            return
        end
        local scopeWarning = heritage.progressionScope == "character" and
            "This choice is permanent. Rank and XP persist across Rebirth." or
            "This choice is permanent for the current Life."
        StaticPopup_Show("PROJECT_REBIRTH_CONFIRM_HERITAGE", heritage.name or "this Heritage", scopeWarning)
    end)

    tabFrames.manifestations = CreateFrame("Frame", nil, panel)
    tabFrames.manifestations:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -88)
    tabFrames.manifestations:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, 58)
    offerFrame = CreateFrame("Frame", nil, tabFrames.manifestations)
    offerFrame:SetAllPoints(tabFrames.manifestations)
    ApplyCardBackdrop(offerFrame, 0.06, 0.045, 0.08)
    offerIcon = offerFrame:CreateTexture(nil, "ARTWORK")
    offerIcon:SetWidth(54)
    offerIcon:SetHeight(54)
    offerIcon:SetPoint("TOPLEFT", offerFrame, "TOPLEFT", 14, -14)
    offerIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    offerName = offerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    offerName:SetPoint("TOPLEFT", offerFrame, "TOPLEFT", 80, -16)
    offerName:SetPoint("RIGHT", offerFrame, "RIGHT", -14, 0)
    offerName:SetJustifyH("LEFT")
    offerRarity = offerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    offerRarity:SetPoint("TOPLEFT", offerName, "BOTTOMLEFT", 0, -5)
    offerRarity:SetPoint("RIGHT", offerFrame, "RIGHT", -14, 0)
    offerRarity:SetJustifyH("LEFT")
    offerSummary = offerFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    offerSummary:SetPoint("TOPLEFT", offerFrame, "TOPLEFT", 14, -92)
    offerSummary:SetPoint("BOTTOMRIGHT", offerFrame, "BOTTOMRIGHT", -14, 52)
    offerSummary:SetJustifyH("LEFT")
    offerSummary:SetJustifyV("TOP")
    acceptButton = CreateFrame("Button", nil, offerFrame, "UIPanelButtonTemplate")
    acceptButton:SetWidth(84)
    acceptButton:SetHeight(22)
    acceptButton:SetPoint("BOTTOM", offerFrame, "BOTTOM", 0, 14)
    acceptButton:SetText("View Choices")
    acceptButton:SetScript("OnClick", function()
        ShowManifestationChoices(false)
    end)
    declineButton = CreateFrame("Button", nil, offerFrame, "UIPanelButtonTemplate")
    declineButton:SetWidth(84)
    declineButton:SetHeight(22)
    declineButton:SetPoint("BOTTOMRIGHT", offerFrame, "BOTTOMRIGHT", -14, 14)
    declineButton:SetText("Decline All")
    declineButton:Hide()

    CreateManifestationChoiceInterface()

    tabFrames.rebirth = CreateFrame("Frame", nil, panel)
    tabFrames.rebirth:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -88)
    tabFrames.rebirth:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, 58)

    local lifeCard = CreateFrame("Frame", nil, tabFrames.rebirth)
    lifeCard:SetPoint("TOPLEFT", tabFrames.rebirth, "TOPLEFT", 0, -2)
    lifeCard:SetPoint("BOTTOMRIGHT", tabFrames.rebirth, "BOTTOMLEFT", 350, 4)
    ApplyCardBackdrop(lifeCard, 0.035, 0.05, 0.075)
    rebirthLifeText = lifeCard:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    rebirthLifeText:SetPoint("TOP", lifeCard, "TOP", 0, -32)
    rebirthLifeText:SetTextColor(0.45, 0.90, 1.00)
    rebirthLevelText = lifeCard:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    rebirthLevelText:SetPoint("TOPLEFT", lifeCard, "TOPLEFT", 24, -94)
    rebirthLevelText:SetJustifyH("LEFT")
    rebirthCapacityText = lifeCard:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    rebirthCapacityText:SetPoint("TOPLEFT", lifeCard, "TOPLEFT", 24, -160)
    rebirthCapacityText:SetJustifyH("LEFT")
    rebirthHeritageText = lifeCard:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    rebirthHeritageText:SetPoint("TOPLEFT", lifeCard, "TOPLEFT", 24, -226)
    rebirthHeritageText:SetPoint("RIGHT", lifeCard, "RIGHT", -24, 0)
    rebirthHeritageText:SetJustifyH("LEFT")
    local lifecycle = lifeCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lifecycle:SetPoint("BOTTOMLEFT", lifeCard, "BOTTOMLEFT", 24, 28)
    lifecycle:SetPoint("RIGHT", lifeCard, "RIGHT", -24, 0)
    lifecycle:SetJustifyH("LEFT")
    lifecycle:SetText("LIFE CYCLE\n|cff73e6ffLevel 1|r  →  Grow  →  |cff73e6ffLevel 80|r  →  Safe Zone  →  Next Life")

    local eligibilityCard = CreateFrame("Frame", nil, tabFrames.rebirth)
    eligibilityCard:SetPoint("TOPLEFT", tabFrames.rebirth, "TOPLEFT", 370, -2)
    eligibilityCard:SetPoint("BOTTOMRIGHT", tabFrames.rebirth, "BOTTOMRIGHT", 0, 4)
    ApplyCardBackdrop(eligibilityCard, 0.045, 0.04, 0.065)
    local rebirthBrand = eligibilityCard:CreateTexture(nil, "ARTWORK")
    rebirthBrand:SetWidth(270)
    rebirthBrand:SetHeight(270)
    rebirthBrand:SetPoint("CENTER", eligibilityCard, "CENTER", 0, -12)
    rebirthBrand:SetTexture(BRAND_TEXTURE)
    rebirthBrand:SetTexCoord(0.04, 0.96, 0.04, 0.96)
    rebirthBrand:SetAlpha(0.13)
    rebirthEligibilityText = eligibilityCard:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    rebirthEligibilityText:SetPoint("TOPLEFT", eligibilityCard, "TOPLEFT", 24, -24)
    rebirthEligibilityText:SetPoint("RIGHT", eligibilityCard, "RIGHT", -24, 0)
    rebirthEligibilityText:SetJustifyH("LEFT")
    rebirthNextText = eligibilityCard:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    rebirthNextText:SetPoint("TOPLEFT", eligibilityCard, "TOPLEFT", 24, -218)
    rebirthNextText:SetPoint("BOTTOMRIGHT", eligibilityCard, "BOTTOMRIGHT", -24, 24)
    rebirthNextText:SetJustifyH("LEFT")
    rebirthNextText:SetJustifyV("TOP")

    -- Frames are visible by default when created. Hide every inactive pane
    -- before the first render so a later content error can never expose or
    -- stack controls belonging to another tab.
    tabFrames.skills:Show()
    tabFrames.heritages:Hide()
    tabFrames.manifestations:Hide()
    tabFrames.rebirth:Hide()

    footnote = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    footnote:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 18, 48)
    footnote:SetPoint("RIGHT", panel, "RIGHT", -18, 0)
    footnote:SetJustifyH("LEFT")
    footnote:SetText("Select a progression tab to inspect server-authoritative details.")

    local function ToggleRebirthPanel()
        if state.offer then
            if choiceFrame and choiceFrame:IsShown() then
                choiceFrame:Hide()
            else
                ShowManifestationChoices(false)
            end
            UpdatePendingIndicator()
            return
        end
        panelWanted = not panel:IsShown()
        if panelWanted then
            panel:Show()
            state.notice = nil
            SendRequest("STATE")
        else
            panel:Hide()
        end
    end

    if active and MainMenuBar then
        toggleButton = CreateFrame("Button", "ProjectRebirthMicroButton", MainMenuBar)
        toggleButton:SetWidth(28)
        toggleButton:SetHeight(36)
        toggleButton:SetFrameStrata("MEDIUM")
        toggleButton:SetFrameLevel((MainMenuBar:GetFrameLevel() or 0) + 5)
        toggleButton:RegisterForClicks("LeftButtonUp")

        local icon = toggleButton:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", toggleButton, "TOPLEFT", 2, -5)
        icon:SetPoint("BOTTOMRIGHT", toggleButton, "BOTTOMRIGHT", -2, 5)
        icon:SetTexture(BRAND_TEXTURE)
        icon:SetTexCoord(0.04, 0.96, 0.04, 0.96)
        local border = toggleButton:CreateTexture(nil, "OVERLAY")
        border:SetAllPoints(toggleButton)
        border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        pendingGlow = toggleButton:CreateTexture(nil, "OVERLAY")
        pendingGlow:SetPoint("TOPLEFT", toggleButton, "TOPLEFT", -7, 3)
        pendingGlow:SetPoint("BOTTOMRIGHT", toggleButton, "BOTTOMRIGHT", 7, -3)
        pendingGlow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        pendingGlow:SetBlendMode("ADD")
        pendingGlow:SetVertexColor(0.45, 0.62, 1.00)
        pendingGlow:Hide()
        pendingCount = toggleButton:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        pendingCount:SetPoint("TOPRIGHT", toggleButton, "TOPRIGHT", 2, -2)
        pendingCount:SetTextColor(0.65, 0.88, 1.00)
        pendingCount:Hide()
        toggleButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        toggleButton:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
        toggleButton:SetScript("OnClick", ToggleRebirthPanel)
        toggleButton:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine("Project Reverie — Rebirth", 0.45, 0.90, 1.00)
            GameTooltip:AddLine("Open Skills, Heritages, Manifestations, and Life progression.", 1, 1, 1, true)
            if state.offer then
                GameTooltip:AddLine(string.format("%d Manifestation choice%s waiting", state.offer.count,
                    state.offer.count == 1 and " is" or "s are"), 0.55, 0.82, 1.00, true)
            end
            GameTooltip:Show()
        end)
        toggleButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

        local function LayoutRebirthMicroButton()
            if not active then
                return
            end
            if HelpMicroButton then
                HelpMicroButton:Hide()
            end
            if not TalentMicroButton or not QuestLogMicroButton or not AchievementMicroButton then
                return
            end
            local order = {
                QuestLogMicroButton,
                toggleButton,
                AchievementMicroButton,
                RebirthWardrobeMicroButton,
                SocialsMicroButton,
                PVPMicroButton,
                LFDMicroButton,
                MainMenuMicroButton,
            }
            local previous = TalentMicroButton
            for _, button in ipairs(order) do
                if button then
                    button:ClearAllPoints()
                    button:SetPoint("BOTTOMLEFT", previous, "BOTTOMRIGHT", -2, 0)
                    previous = button
                end
            end
        end

        ProjectRebirth_LayoutMicroButtons = LayoutRebirthMicroButton

        if HelpMicroButton then
            HelpMicroButton:HookScript("OnShow", function(self)
                if active then
                    self:Hide()
                end
            end)
        end
        LayoutRebirthMicroButton()
        if hooksecurefunc and UpdateMicroButtons then
            hooksecurefunc("UpdateMicroButtons", LayoutRebirthMicroButton)
        end
        UpdatePendingIndicator()
    end

    UpdateActivation()
    Render()
end

local function EnsureInterface()
    UpdateActivation()
    if not active then
        return false
    end
    CreateInterface()
    return panel ~= nil
end

local function HandleAddonMessage(prefix, message, channel, sender)
    if not active or prefix ~= PREFIX or channel ~= "WHISPER" or not IsLocalPlayerSender(sender) then
        return
    end
    if not message or string.len(message) > 255 then
        RejectOfferSnapshot("The server sent an oversized Rebirth addon packet; refreshing.")
        return
    end

    local fields = SplitTabs(message)
    if fields[1] ~= PROTOCOL then
        state.notice = "This server response uses an unsupported Rebirth addon protocol."
        local now = GetTime and GetTime() or 0
        if now - lastOfferResyncAt >= 1 then
            lastOfferResyncAt = now
            SendRequest("STATE")
        end
        if Render then Render() end
        return
    end

    local messageType = fields[2]
    if messageType == "STATE" then
        reopenChoiceAfterSnapshot = choiceFrame and choiceFrame:IsShown() or false
        if choiceFrame then choiceFrame:Hide() end
        state.inspectedName = nil
        state.status = fields[3] or "unknown"
        state.owned = tonumber(fields[4]) or 0
        state.capacity = tonumber(fields[5]) or 0
        state.lifeId = tonumber(fields[7]) or 0
        state.ownershipAvailable = fields[8] == "1"
        state.skills = {}
        state.offer = nil
        offerAssembly = nil
        state.heritages = {}
        state.heritage.status = "waiting"
        state.heritage.canSelect = false
        UpdatePendingIndicator()
    elseif messageType == "INSPECT_BEGIN" then
        state.inspectedName = DecodeField(fields[3])
        state.owned = tonumber(fields[4]) or 0
        state.capacity = tonumber(fields[5]) or 0
        state.ownershipAvailable = fields[6] == "1"
        state.skills = {}
        state.total = state.owned
        state.complete = false
        activeTab = "skills"
    elseif messageType == "SKILL" or messageType == "INSPECT_SKILL" then
        table.insert(state.skills, {
            id = tonumber(fields[3]) or 0,
            rarityId = tonumber(fields[4]) or 0,
            rank = tonumber(fields[5]) or 0,
            xp = tonumber(fields[6]) or 0,
            effects = fields[7] == "1",
            name = DecodeField(fields[8]),
            summary = DecodeField(fields[9]),
            tier = tonumber(fields[10]) or 0,
            valueMilli = 0,
            unit = "points",
            bucket = "unclassified",
            bucketTotalMilli = 0,
            adapter = "unclassified",
            runtimeDetail = "",
            operational = fields[7] == "1",
        })
    elseif messageType == "VALUE" or messageType == "INSPECT_VALUE" then
        local skill = FindSkill(tonumber(fields[3]) or 0)
        if skill then
            skill.valueMilli = tonumber(fields[4]) or 0
            skill.unit = DecodeField(fields[5])
            skill.bucket = DecodeField(fields[6])
            skill.bucketTotalMilli = tonumber(fields[7]) or skill.valueMilli
            skill.adapter = DecodeField(fields[8])
            skill.runtimeDetail = DecodeField(fields[9])
            skill.operational = fields[10] ~= "0"
            skill.effects = skill.effects and skill.operational
        end
    elseif messageType == "OFFER_BEGIN" then
        local opportunityId = ParseInteger(fields[3], 1, 9007199254740991)
        local rowVersion = ParseInteger(fields[4], 0, 4294967295)
        local count = ParseInteger(fields[5], 1, 3)
        local expired = fields[6] == "1"
        if #fields ~= 6 or offerAssembly or not opportunityId or not rowVersion or not count or
            (fields[6] ~= "0" and fields[6] ~= "1") then
            RejectOfferSnapshot("The server sent a malformed Manifestation header; refreshing.")
            return
        end
        offerAssembly = {
            opportunityId = opportunityId,
            rowVersion = rowVersion,
            count = count,
            expired = expired,
            choices = {},
        }
    elseif messageType == "OFFER_CHOICE" then
        local opportunityId = ParseInteger(fields[3], 1, 9007199254740991)
        local ordinal = ParseInteger(fields[4], 1, 3)
        local skillId = ParseInteger(fields[5], 1, 4294967295)
        local rarityId = ParseInteger(fields[6], 0, 6)
        local tier = ParseInteger(fields[7], 0, 5)
        if #fields ~= 8 or not offerAssembly or opportunityId ~= offerAssembly.opportunityId or
            not ordinal or ordinal > offerAssembly.count or not skillId or not rarityId or not tier or
            not IsEncodedField(fields[8]) or offerAssembly.choices[ordinal] then
            RejectOfferSnapshot("The server sent a mismatched Manifestation choice; refreshing.")
            return
        end
        for _, existing in pairs(offerAssembly.choices) do
            if existing.skillId == skillId then
                RejectOfferSnapshot("The server sent duplicate Manifestation Skills; refreshing.")
                return
            end
        end
        offerAssembly.choices[ordinal] = {
            ordinal = ordinal,
            skillId = skillId,
            rarityId = rarityId,
            tier = tier,
            icon = DecodeField(fields[8]),
            name = "",
            shortEffect = "",
            detail = "",
            sourceContext = "",
            valueMilli = 0,
            unit = "points",
            bucket = "unclassified",
            adapter = "unclassified",
            rankCurve = "server_authoritative",
            stacking = "server_authoritative",
            hasText = false,
            hasValue = false,
        }
    elseif messageType == "OFFER_TEXT" then
        local opportunityId = ParseInteger(fields[3], 1, 9007199254740991)
        local ordinal = ParseInteger(fields[4], 1, 3)
        local choice = offerAssembly and ordinal and offerAssembly.choices[ordinal]
        if #fields ~= 8 or not offerAssembly or opportunityId ~= offerAssembly.opportunityId or not choice or
            choice.hasText or not IsEncodedField(fields[5]) or not IsEncodedField(fields[6]) or
            not IsEncodedField(fields[7]) or not IsEncodedField(fields[8]) then
            RejectOfferSnapshot("The server sent malformed Manifestation text; refreshing.")
            return
        end
        choice.name = DecodeField(fields[5])
        choice.shortEffect = DecodeField(fields[6])
        choice.detail = DecodeField(fields[7])
        choice.sourceContext = DecodeField(fields[8])
        if choice.name == "" then
            RejectOfferSnapshot("The server sent an unnamed Manifestation Skill; refreshing.")
            return
        end
        choice.hasText = true
    elseif messageType == "OFFER_VALUE" then
        local opportunityId = ParseInteger(fields[3], 1, 9007199254740991)
        local ordinal = ParseInteger(fields[4], 1, 3)
        local valueMilli = ParseInteger(fields[5], -2147483648, 2147483647)
        local choice = offerAssembly and ordinal and offerAssembly.choices[ordinal]
        if #fields ~= 10 or not offerAssembly or opportunityId ~= offerAssembly.opportunityId or not choice or
            choice.hasValue or not valueMilli or not IsEncodedField(fields[6]) or not IsEncodedField(fields[7]) or
            not IsEncodedField(fields[8]) or not IsEncodedField(fields[9]) or not IsEncodedField(fields[10]) then
            RejectOfferSnapshot("The server sent malformed Manifestation values; refreshing.")
            return
        end
        choice.valueMilli = valueMilli
        choice.unit = DecodeField(fields[6])
        choice.bucket = DecodeField(fields[7])
        choice.adapter = DecodeField(fields[8])
        choice.rankCurve = DecodeField(fields[9])
        choice.stacking = DecodeField(fields[10])
        choice.hasValue = true
    elseif messageType == "OFFER_END" then
        local opportunityId = ParseInteger(fields[3], 1, 9007199254740991)
        if #fields ~= 3 or not offerAssembly or opportunityId ~= offerAssembly.opportunityId then
            RejectOfferSnapshot("The server ended a mismatched Manifestation snapshot; refreshing.")
            return
        end
        for ordinal = 1, offerAssembly.count do
            local choice = offerAssembly.choices[ordinal]
            if not choice or not choice.hasText or not choice.hasValue then
                RejectOfferSnapshot("The server ended an incomplete Manifestation snapshot; refreshing.")
                return
            end
        end
        CommitOfferSnapshot(offerAssembly)
    elseif messageType == "HERITAGE_BEGIN" then
        state.heritages = {}
        state.heritage.status = fields[3] or "unknown"
        state.heritage.canSelect = false
    elseif messageType == "HERITAGE_OPTION" then
        local option = {
            id = tonumber(fields[3]) or 0,
            selected = fields[4] == "1",
            rank = tonumber(fields[5]) or 0,
            xp = tonumber(fields[6]) or 0,
            canSelect = fields[7] == "1",
            effects = fields[8] == "1",
            name = DecodeField(fields[9]),
            summary = DecodeField(fields[10]),
            maxRank = tonumber(fields[11]) or 0,
            nextThreshold = tonumber(fields[12]) or 0,
            bonusMilli = tonumber(fields[13]) or 0,
            eligible = fields[14] ~= "0",
            eligibilityReason = DecodeField(fields[15]),
            progressionScope = fields[16] ~= "" and fields[16] or "life",
            reputationBonusMilli = tonumber(fields[17]) or 0,
            cooldownSeconds = tonumber(fields[18]) or 0,
            hasteBonusMilli = tonumber(fields[19]) or 0,
            hasteSecondsRemaining = tonumber(fields[20]) or 0,
            hasteActive = fields[21] == "1",
        }
        table.insert(state.heritages, option)
        if option.selected then
            state.heritage = option
        end
    elseif messageType == "HERITAGE" then
        local legacyHeritage = {
            status = fields[3] or "unknown",
            selected = fields[4] == "1",
            id = tonumber(fields[5]) or 1101,
            rank = tonumber(fields[6]) or 0,
            xp = tonumber(fields[7]) or 0,
            canSelect = fields[8] == "1",
            effects = fields[9] == "1",
            name = DecodeField(fields[10]),
            summary = DecodeField(fields[11]),
            maxRank = tonumber(fields[12]) or 100,
            nextThreshold = tonumber(fields[13]) or 0,
            bonusMilli = tonumber(fields[14]) or 0,
        }
        state.heritage = legacyHeritage
        if #(state.heritages or {}) == 0 then
            state.heritages = { legacyHeritage }
        end
        actionPending = false
        Render()
    elseif messageType == "NOTICE" then
        local code = fields[3] or "unknown"
        if (code == "accepted" or code == "declined") and state.offer then
            resolvedOpportunities[state.offer.opportunityId] = true
            ClearOfferState()
        end
        state.notice = notices[code] or ("Server response: " .. string.gsub(code, "_", " "))
        actionPending = false
        Render()
    elseif messageType == "INSPECT_END" then
        state.total = tonumber(fields[4]) or state.owned
        state.complete = fields[5] == "1"
        actionPending = false
        Render()
    elseif messageType == "END" then
        state.total = tonumber(fields[4]) or state.owned
        state.complete = fields[5] == "1"
        if offerAssembly then
            RejectOfferSnapshot("The server state ended before its Manifestation choices were complete; refreshing.")
            return
        end
        if not state.offer then
            selectedChoiceOrdinal = nil
            selectedChoiceOpportunityId = nil
            reopenChoiceAfterSnapshot = false
            if choiceFrame then choiceFrame:Hide() end
            UpdatePendingIndicator()
        end
        actionPending = false
        Render()
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        if RegisterAddonMessagePrefix then
            RegisterAddonMessagePrefix(PREFIX)
        end
        UpdateActivation()
        if active then
            EnsureInterface()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        UpdateActivation()
        if active then
            state.notice = nil
            actionPending = false
            SendRequest("STATE")
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if active and state.offer and deferredOfferReveal then
            ShowManifestationChoices(revealedOpportunityId ~= state.offer.opportunityId)
        end
    elseif event == "CHAT_MSG_ADDON" then
        HandleAddonMessage(...)
    end
end)

SLASH_PROJECTREBIRTHSKILLS1 = "/rebirthskills"
SLASH_PROJECTREBIRTHSKILLS2 = "/rskills"
SlashCmdList.PROJECTREBIRTHSKILLS = function()
    UpdateActivation()
    if not active then
        DEFAULT_CHAT_FRAME:AddMessage("|cff73e6ffRebirth Skills:|r available only on the Rebirth realm.")
        return
    end
    if not EnsureInterface() then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff6666Rebirth Skills:|r the progression interface could not be initialized.")
        return
    end
    panelWanted = not panel:IsShown()
    if panelWanted then
        panel:Show()
        state.notice = nil
        SendRequest("STATE")
        DEFAULT_CHAT_FRAME:AddMessage("|cff73e6ffRebirth Skills:|r panel opened; requesting server state.")
    else
        panel:Hide()
    end
end

SLASH_PROJECTREBIRTHINSPECT1 = "/rinspect"
SlashCmdList.PROJECTREBIRTHINSPECT = function()
    UpdateActivation()
    if not active or not EnsureInterface() then
        return
    end
    if not UnitExists("target") or not UnitIsPlayer("target") then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff6666Rebirth Build:|r select a player or PlayerBot first.")
        return
    end
    local name = UnitName("target")
    panelWanted = true
    panel:Show()
    activeTab = "skills"
    state.notice = "Requesting " .. name .. "'s public Rebirth build…"
    SendRequest("INSPECT\t" .. name)
    Render()
end
