local PREFIX = "ProjectRebirth"
local PROTOCOL = "1"
local REALM = "Rebirth"

local active = false
local panel
local toggleButton
local scrollFrame
local scrollChild
local ownedLabel
local capacityText
local statusText
local heritageFrame
local heritageName
local heritageMeta
local heritageSummary
local heritageButton
local offerFrame
local offerName
local offerRarity
local offerSummary
local acceptButton
local declineButton
local rows = {}
local panelWanted = false
local actionPending = false

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

local function UpdateActivation()
    active = (GetRealmName and GetRealmName() or "") == REALM
    if toggleButton then
        if active and CharacterFrame and CharacterFrame:IsShown() then
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

local function HideRows()
    for _, row in ipairs(rows) do
        row:Hide()
    end
end

local function AcquireRow(index)
    if rows[index] then
        return rows[index]
    end

    local row = CreateFrame("Frame", nil, scrollChild)
    row:SetWidth(276)
    row:SetHeight(68)
    row:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    row:SetBackdropColor(0.035, 0.045, 0.07, 0.96)
    row:SetBackdropBorderColor(0.28, 0.34, 0.45, 1)

    row.rarityBar = row:CreateTexture(nil, "ARTWORK")
    row.rarityBar:SetWidth(4)
    row.rarityBar:SetPoint("TOPLEFT", row, "TOPLEFT", 5, -5)
    row.rarityBar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 5, 5)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 15, -9)
    row.name:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.name:SetJustifyH("LEFT")

    row.meta = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.meta:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
    row.meta:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.meta:SetJustifyH("LEFT")

    row.summary = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.summary:SetPoint("TOPLEFT", row.meta, "BOTTOMLEFT", 0, -3)
    row.summary:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.summary:SetJustifyH("LEFT")
    row.summary:SetJustifyV("TOP")
    rows[index] = row
    return row
end

local function Render()
    if not panel then
        return
    end

    capacityText:SetText(string.format("Skill Capacity: |cff73e6ff%d / %d|r", state.owned, state.capacity))
    if state.owned > state.capacity then
        capacityText:SetText(string.format("Skill Capacity: |cffff6666%d / %d — over capacity|r", state.owned, state.capacity))
    end

    local status = state.notice or ("Server state: " .. string.gsub(state.status or "unknown", "_", " "))
    statusText:SetText(status)
    statusText:SetTextColor(state.notice and 1.0 or 0.68, state.notice and 0.82 or 0.72, state.notice and 0.28 or 0.82)

    local heritage = state.heritage
    heritageName:SetText(heritage.name or "Prototype Heritage 001")
    heritageName:SetTextColor(0.45, 0.90, 1.00)
    heritageSummary:SetText(heritage.summary or "Work in progress; no gameplay effect.")
    if heritage.selected then
        heritageMeta:SetText(string.format("Rank %d  •  %d XP  •  Locked for this Life%s",
            heritage.rank, heritage.xp, heritage.effects and "" or "  •  WIP / no effect"))
        heritageButton:SetText("Locked")
        SetButtonEnabled(heritageButton, false)
        heritageFrame:SetBackdropBorderColor(0.45, 0.90, 1.00, 1)
    else
        heritageMeta:SetText("Not selected  •  Selection is permanent for this current Life")
        heritageButton:SetText("Select")
        SetButtonEnabled(heritageButton, heritage.canSelect and not actionPending)
        heritageFrame:SetBackdropBorderColor(0.28, 0.34, 0.45, 1)
    end

    if state.offer then
        local rarity = Rarity(state.offer.rarityId)
        offerFrame:Show()
        offerFrame:SetBackdropBorderColor(rarity.color[1], rarity.color[2], rarity.color[3], 1)
        offerName:SetText(state.offer.name)
        offerName:SetTextColor(rarity.color[1], rarity.color[2], rarity.color[3])
        offerRarity:SetText(string.format("%s Manifestation Offer%s", rarity.name,
            state.offer.expired and " — expired" or ""))
        offerSummary:SetText(state.offer.summary)
        SetButtonEnabled(acceptButton, not state.offer.expired and not actionPending)
        SetButtonEnabled(declineButton, not actionPending)
        ownedLabel:ClearAllPoints()
        ownedLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -332)
        scrollFrame:ClearAllPoints()
        scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -354)
    else
        offerFrame:Hide()
        ownedLabel:ClearAllPoints()
        ownedLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -214)
        scrollFrame:ClearAllPoints()
        scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -236)
    end
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, 42)

    HideRows()
    for index, skill in ipairs(state.skills) do
        local row = AcquireRow(index)
        local rarity = Rarity(skill.rarityId)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -((index - 1) * 72))
        row.rarityBar:SetTexture(rarity.color[1], rarity.color[2], rarity.color[3], 1)
        row.name:SetText(skill.name)
        row.name:SetTextColor(rarity.color[1], rarity.color[2], rarity.color[3])
        row.meta:SetText(string.format("%s  •  Rank %d  •  %d XP%s", rarity.name, skill.rank,
            skill.xp, skill.effects and "" or "  •  WIP / no effect"))
        row.summary:SetText(skill.summary)
        row:Show()
    end

    local rowCount = math.max(#state.skills, 1)
    scrollChild:SetHeight(rowCount * 72)
    ownedLabel:SetText(string.format("Owned Skills (%d)%s", state.total,
        state.complete and "" or " — partial display"))
    if #state.skills == 0 then
        ownedLabel:SetText(state.ownershipAvailable and "Owned Skills (0)" or "Owned Skills — unavailable")
    end
end

local function CreateInterface()
    if panel or not CharacterFrame then
        return
    end

    toggleButton = CreateFrame("Button", "ProjectRebirthSkillsToggle", UIParent, "UIPanelButtonTemplate")
    toggleButton:SetWidth(72)
    toggleButton:SetHeight(20)
    toggleButton:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", -34, -52)
    toggleButton:SetFrameStrata("DIALOG")
    toggleButton:SetFrameLevel(100)
    toggleButton:EnableMouse(true)
    toggleButton:RegisterForClicks("LeftButtonUp")
    toggleButton:SetText("Rebirth")
    toggleButton:SetScript("OnClick", function()
        panelWanted = not panel:IsShown()
        if panelWanted then
            panel:Show()
            state.notice = nil
            SendRequest("STATE")
        else
            panel:Hide()
        end
    end)

    panel = CreateFrame("Frame", "ProjectRebirthSkillsPanel", UIParent)
    panel:SetWidth(326)
    panel:SetHeight(560)
    panel:SetPoint("TOPLEFT", CharacterFrame, "TOPRIGHT", 4, -10)
    panel:SetFrameStrata("DIALOG")
    panel:SetFrameLevel(90)
    panel:SetClampedToScreen(true)
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
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -18)
    title:SetText("Rebirth Progression")
    title:SetTextColor(0.45, 0.90, 1.00)

    local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetText("Server-authoritative current-Life progression")

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

    capacityText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    capacityText:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -66)

    statusText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -88)
    statusText:SetPoint("RIGHT", panel, "RIGHT", -18, 0)
    statusText:SetJustifyH("LEFT")

    heritageFrame = CreateFrame("Frame", nil, panel)
    heritageFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -112)
    heritageFrame:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, -112)
    heritageFrame:SetHeight(92)
    heritageFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 14,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    heritageFrame:SetBackdropColor(0.035, 0.055, 0.075, 0.98)

    heritageName = heritageFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    heritageName:SetPoint("TOPLEFT", heritageFrame, "TOPLEFT", 10, -9)
    heritageName:SetPoint("RIGHT", heritageFrame, "RIGHT", -90, 0)
    heritageName:SetJustifyH("LEFT")

    heritageMeta = heritageFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    heritageMeta:SetPoint("TOPLEFT", heritageName, "BOTTOMLEFT", 0, -4)
    heritageMeta:SetPoint("RIGHT", heritageFrame, "RIGHT", -10, 0)
    heritageMeta:SetJustifyH("LEFT")

    heritageSummary = heritageFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    heritageSummary:SetPoint("TOPLEFT", heritageMeta, "BOTTOMLEFT", 0, -4)
    heritageSummary:SetPoint("RIGHT", heritageFrame, "RIGHT", -10, 0)
    heritageSummary:SetJustifyH("LEFT")

    heritageButton = CreateFrame("Button", nil, heritageFrame, "UIPanelButtonTemplate")
    heritageButton:SetWidth(72)
    heritageButton:SetHeight(20)
    heritageButton:SetPoint("TOPRIGHT", heritageFrame, "TOPRIGHT", -10, -8)
    heritageButton:SetText("Select")
    heritageButton:SetScript("OnClick", function()
        actionPending = true
        state.notice = "Waiting for server Heritage selection…"
        Render()
        SendRequest("HERITAGE_SELECT")
    end)

    offerFrame = CreateFrame("Frame", nil, panel)
    offerFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -214)
    offerFrame:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, -214)
    offerFrame:SetHeight(108)
    offerFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 14,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    offerFrame:SetBackdropColor(0.06, 0.045, 0.08, 0.98)

    offerName = offerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    offerName:SetPoint("TOPLEFT", offerFrame, "TOPLEFT", 10, -9)
    offerName:SetPoint("RIGHT", offerFrame, "RIGHT", -10, 0)
    offerName:SetJustifyH("LEFT")

    offerRarity = offerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    offerRarity:SetPoint("TOPLEFT", offerName, "BOTTOMLEFT", 0, -3)

    offerSummary = offerFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    offerSummary:SetPoint("TOPLEFT", offerRarity, "BOTTOMLEFT", 0, -3)
    offerSummary:SetPoint("RIGHT", offerFrame, "RIGHT", -10, 0)
    offerSummary:SetJustifyH("LEFT")
    acceptButton = CreateFrame("Button", nil, offerFrame, "UIPanelButtonTemplate")
    acceptButton:SetWidth(76)
    acceptButton:SetHeight(20)
    acceptButton:SetPoint("BOTTOMRIGHT", offerFrame, "BOTTOMRIGHT", -92, 8)
    acceptButton:SetText("Accept")
    acceptButton:SetScript("OnClick", function()
        actionPending = true
        state.notice = "Waiting for server acceptance…"
        Render()
        SendRequest("ACCEPT")
    end)

    declineButton = CreateFrame("Button", nil, offerFrame, "UIPanelButtonTemplate")
    declineButton:SetWidth(76)
    declineButton:SetHeight(20)
    declineButton:SetPoint("BOTTOMRIGHT", offerFrame, "BOTTOMRIGHT", -10, 8)
    declineButton:SetText("Decline")
    declineButton:SetScript("OnClick", function()
        actionPending = true
        state.notice = "Waiting for server decision…"
        Render()
        SendRequest("DECLINE")
    end)

    ownedLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ownedLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -214)

    scrollFrame = CreateFrame("ScrollFrame", "ProjectRebirthSkillsScrollFrame", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -236)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, 42)
    scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(276)
    scrollChild:SetHeight(72)
    scrollFrame:SetScrollChild(scrollChild)

    local footnote = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    footnote:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 18, 18)
    footnote:SetPoint("RIGHT", panel, "RIGHT", -18, 0)
    footnote:SetJustifyH("LEFT")
    footnote:SetText("Prototype Skills and Heritage are WIP placeholders with no gameplay effects.")

    CharacterFrame:HookScript("OnHide", function()
        toggleButton:Hide()
        panel:Hide()
    end)
    CharacterFrame:HookScript("OnShow", function()
        if active then
            toggleButton:Show()
        end
        if panelWanted and active then
            panel:Show()
            SendRequest("STATE")
        end
    end)

    UpdateActivation()
    Render()
end

local function EnsureInterface()
    if not CharacterFrame and LoadAddOn then
        LoadAddOn("Blizzard_CharacterUI")
    end
    CreateInterface()
    return panel ~= nil
end

local function HandleAddonMessage(prefix, message)
    if not active or prefix ~= PREFIX then
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
        })
    elseif messageType == "OFFER" then
        state.offer = {
            opportunityId = tonumber(fields[3]) or 0,
            skillId = tonumber(fields[4]) or 0,
            rarityId = tonumber(fields[5]) or 0,
            expired = fields[6] == "1",
            name = DecodeField(fields[7]),
            summary = DecodeField(fields[8]),
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
        EnsureInterface()
        UpdateActivation()
    elseif event == "PLAYER_ENTERING_WORLD" then
        UpdateActivation()
        if active then
            SendRequest("STATE")
        end
    elseif event == "CHAT_MSG_ADDON" then
        HandleAddonMessage(...)
    end
end)

SLASH_PROJECTREBIRTHSKILLS1 = "/rebirthskills"
SLASH_PROJECTREBIRTHSKILLS2 = "/rskills"
SlashCmdList.PROJECTREBIRTHSKILLS = function()
    if not EnsureInterface() then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff6666Rebirth Skills:|r the Character UI could not be loaded.")
        return
    end
    UpdateActivation()
    if not active then
        DEFAULT_CHAT_FRAME:AddMessage("|cff73e6ffRebirth Skills:|r available only on the Rebirth realm.")
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
