local PREFIX = "ProjectRebirth"
local PROTOCOL = "1"
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
local footnote
local searchBox
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
local selectedHeritageId = 1001
local panelWanted = false
local actionPending = false
local Render

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
    offer = nil,
    heritage = {
        status = "waiting",
        selected = false,
        id = 1001,
        rank = 0,
        xp = 0,
        canSelect = false,
        effects = false,
        name = "Prototype Heritage 001",
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
    capacity_blocked = "No Skill slot is currently available.",
    conflict = "The Skill state changed. The panel has been refreshed.",
    persistence_failed = "The server could not persist that action.",
    schema_unavailable = "The Rebirth Skill service is temporarily unavailable.",
    unsupported_version = "This addon protocol does not match the server.",
    malformed = "The server rejected a malformed addon request.",
    unknown_request = "The server rejected an unknown addon request.",
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
    capacityText:SetText(string.format("Current Life Slots: |cff73e6ff%d / %d|r", state.owned, state.capacity))
    if state.owned > state.capacity then
        capacityText:SetText(string.format("Current Life Slots: |cffff6666%d / %d — protected overflow|r", state.owned, state.capacity))
    end
    RenderLoadoutSlots()

    local filteredSkills = GetFilteredSkills()
    skillCountLabel:SetText(string.format("Owned Skill Library (%d)%s", state.total,
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
        button.tooltipMeta = string.format("%s • Rank %d • %d XP", rarity.name, skill.rank, skill.xp)
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
    skillDetailMeta:SetText(string.format("%s  •  Rank %d  •  %d XP  •  %s%s", rarity.name,
        skill.rank, skill.xp, tierText, skill.effects and "" or "  •  WIP / no effect"))
    skillDetailSummary:SetText(skill.summary)
    skillDetailFrame:SetBackdropBorderColor(rarity.color[1], rarity.color[2], rarity.color[3], 1)
end

local function RenderHeritageTab()
    local heritage = state.heritage or {}
    heritage.id = tonumber(heritage.id) or 1001
    heritage.rank = tonumber(heritage.rank) or 0
    heritage.xp = tonumber(heritage.xp) or 0
    heritage.name = heritage.name ~= "" and heritage.name or "Prototype Heritage 001"
    heritage.summary = heritage.summary ~= "" and heritage.summary or "Work in progress; no gameplay effect."
    selectedHeritageId = heritage.id
    heritageCountLabel:SetText("Heritages (1 available)")

    HideGridButtons(heritageButtons)
    local heritages = { heritage }
    for index, entry in ipairs(heritages) do
        local button = AcquireHeritageButton(index)
        local column = (index - 1) % 4
        local row = math.floor((index - 1) / 4)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", heritageGridChild, "TOPLEFT", column * 68, -(row * 62))
        button.icon:SetTexture(HERITAGE_ICON)
        button.entryId = entry.id or 1001
        button.rank:SetText((tonumber(entry.rank) or 0) > 0 and entry.rank or "")
        button.tooltipName = entry.name or "Prototype Heritage 001"
        button.tooltipMeta = entry.selected and
            string.format("Rank %d • %d XP • Locked", tonumber(entry.rank) or 0, tonumber(entry.xp) or 0) or
            "Not selected • Permanent for this Life"
        if selectedHeritageId == button.entryId then
            button.selection:Show()
        else
            button.selection:Hide()
        end
        button:SetBackdropBorderColor(0.45, 0.90, 1.00, 1)
        button:Show()
    end
    heritageGridChild:SetHeight(math.max(3, math.ceil(#heritages / 4)) * 62)

    heritageDetailIcon:SetTexture(HERITAGE_ICON)
    heritageDetailName:SetText(heritage.name or "Prototype Heritage 001")
    heritageDetailName:SetTextColor(0.45, 0.90, 1.00)
    heritageDetailSummary:SetText(heritage.summary or "Work in progress; no gameplay effect.")
    if heritage.selected then
        heritageDetailMeta:SetText(string.format("Rank %d  •  %d XP  •  Locked for this Life%s",
            tonumber(heritage.rank) or 0, tonumber(heritage.xp) or 0,
            heritage.effects and "" or "  •  WIP / no effect"))
        heritageWarning:SetText("This Heritage is permanently selected for the current Life.")
        heritageButton:SetText("Selected")
        SetButtonEnabled(heritageButton, false)
    else
        heritageDetailMeta:SetText("Not selected  •  Rank 0  •  0 XP  •  WIP / no effect")
        heritageWarning:SetText("Selection is permanent for this current Life.")
        heritageButton:SetText("Select Heritage")
        SetButtonEnabled(heritageButton, heritage.canSelect and not actionPending)
    end
end

local function RenderManifestationTab()
    if not state.offer then
        offerFrame:SetBackdropBorderColor(0.28, 0.34, 0.45, 1)
        offerIcon:SetTexture(OFFER_ICON)
        offerName:SetText("No active Manifestation")
        offerName:SetTextColor(0.62, 0.62, 0.62)
        offerRarity:SetText("The server has no open Skill offer for this Life.")
        offerSummary:SetText("When a Manifestation offer is available, its Skill details and server-authoritative Accept or Decline actions will appear here.")
        acceptButton:Hide()
        declineButton:Hide()
        return
    end

    local rarity = Rarity(state.offer.rarityId)
    local tierText = state.offer.tier and state.offer.tier > 0 and ("Tier " .. state.offer.tier) or "Tier WIP"
    offerFrame:SetBackdropBorderColor(rarity.color[1], rarity.color[2], rarity.color[3], 1)
    offerIcon:SetTexture(state.offer.icon or OFFER_ICON)
    offerName:SetText(state.offer.name)
    offerName:SetTextColor(rarity.color[1], rarity.color[2], rarity.color[3])
    offerRarity:SetText(string.format("%s Manifestation Offer  •  %s%s", rarity.name, tierText,
        state.offer.expired and "  •  expired" or ""))
    offerSummary:SetText(state.offer.summary)
    acceptButton:Show()
    declineButton:Show()
    SetButtonEnabled(acceptButton, not state.offer.expired and not actionPending)
    SetButtonEnabled(declineButton, not actionPending)
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
        footnote:SetText("Select a Skill icon to inspect its server-authoritative rarity, Rank, XP, tier, and WIP state.")
    elseif activeTab == "heritages" then
        footnote:SetText("Heritage selection is permanent for the current Life; prototype effects remain disabled.")
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
    local heritage = state.heritage or {}
    if actionPending or heritage.selected or not heritage.canSelect then
        return
    end

    actionPending = true
    state.notice = "Waiting for server Heritage selection…"
    Render()
    SendRequest("HERITAGE_SELECT")
end

StaticPopupDialogs.PROJECT_REBIRTH_CONFIRM_HERITAGE = {
    text = "Select %s as your Heritage?\n\nThis choice is permanent for the current Life.",
    button1 = "Select Heritage",
    button2 = CANCEL,
    OnAccept = ConfirmHeritageSelection,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

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
        local heritage = state.heritage or {}
        if actionPending or heritage.selected or not heritage.canSelect then
            return
        end
        StaticPopup_Show("PROJECT_REBIRTH_CONFIRM_HERITAGE", heritage.name or "this Heritage")
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
    acceptButton:SetPoint("BOTTOMRIGHT", offerFrame, "BOTTOMRIGHT", -104, 14)
    acceptButton:SetText("Accept")
    acceptButton:SetScript("OnClick", function()
        actionPending = true
        state.notice = "Waiting for server acceptance…"
        Render()
        SendRequest("ACCEPT")
    end)
    declineButton = CreateFrame("Button", nil, offerFrame, "UIPanelButtonTemplate")
    declineButton:SetWidth(84)
    declineButton:SetHeight(22)
    declineButton:SetPoint("BOTTOMRIGHT", offerFrame, "BOTTOMRIGHT", -14, 14)
    declineButton:SetText("Decline")
    declineButton:SetScript("OnClick", function()
        actionPending = true
        state.notice = "Waiting for server decision…"
        Render()
        SendRequest("DECLINE")
    end)

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
        toggleButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        toggleButton:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
        toggleButton:SetScript("OnClick", ToggleRebirthPanel)
        toggleButton:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine("Project Reverie — Rebirth", 0.45, 0.90, 1.00)
            GameTooltip:AddLine("Open Skills, Heritages, Manifestations, and Life progression.", 1, 1, 1, true)
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

    local fields = SplitTabs(message)
    if fields[1] ~= PROTOCOL then
        return
    end

    local messageType = fields[2]
    if messageType == "STATE" then
        state.status = fields[3] or "unknown"
        state.owned = tonumber(fields[4]) or 0
        state.capacity = tonumber(fields[5]) or 0
        state.lifeId = tonumber(fields[7]) or 0
        state.ownershipAvailable = fields[8] == "1"
        state.skills = {}
        state.offer = nil
        state.heritage.status = "waiting"
        state.heritage.canSelect = false
    elseif messageType == "SKILL" then
        table.insert(state.skills, {
            id = tonumber(fields[3]) or 0,
            rarityId = tonumber(fields[4]) or 0,
            rank = tonumber(fields[5]) or 0,
            xp = tonumber(fields[6]) or 0,
            effects = fields[7] == "1",
            name = DecodeField(fields[8]),
            summary = DecodeField(fields[9]),
            tier = tonumber(fields[10]) or 0,
        })
    elseif messageType == "OFFER" then
        state.offer = {
            opportunityId = tonumber(fields[3]) or 0,
            skillId = tonumber(fields[4]) or 0,
            rarityId = tonumber(fields[5]) or 0,
            expired = fields[6] == "1",
            name = DecodeField(fields[7]),
            summary = DecodeField(fields[8]),
            tier = tonumber(fields[9]) or 0,
        }
    elseif messageType == "HERITAGE" then
        state.heritage = {
            status = fields[3] or "unknown",
            selected = fields[4] == "1",
            id = tonumber(fields[5]) or 1001,
            rank = tonumber(fields[6]) or 0,
            xp = tonumber(fields[7]) or 0,
            canSelect = fields[8] == "1",
            effects = fields[9] == "1",
            name = DecodeField(fields[10]),
            summary = DecodeField(fields[11]),
        }
        actionPending = false
        Render()
    elseif messageType == "NOTICE" then
        local code = fields[3] or "unknown"
        state.notice = notices[code] or ("Server response: " .. string.gsub(code, "_", " "))
        actionPending = false
        Render()
    elseif messageType == "END" then
        state.total = tonumber(fields[4]) or state.owned
        state.complete = fields[5] == "1"
        actionPending = false
        Render()
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
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
