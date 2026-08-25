local ADDON = "RebirthWardrobe"
local REALM = "Rebirth"
local active = false
local frame
local selectedSlot = 0
local selectedAppearance
local selectedOutfit
local collection = {}
local collectionById = {}
local slots = {}
local outfits = {}
local bindings = {}
local syncComplete = false
local familyFilter = "ALL"
local searchText = ""

local SLOT_NAMES = {
    [0] = "Head", [2] = "Shoulders", [3] = "Shirt", [4] = "Chest",
    [5] = "Waist", [6] = "Legs", [7] = "Feet", [8] = "Wrists",
    [9] = "Hands", [14] = "Back", [15] = "Main Hand", [16] = "Off Hand",
    [17] = "Ranged", [18] = "Tabard",
}
local SLOT_ORDER = { 0, 2, 3, 4, 5, 6, 7, 8, 9, 14, 15, 16, 17, 18 }
local FAMILIES = {
    "ALL", "HEAD", "SHOULDER", "SHIRT", "CHEST", "WAIST", "LEGS", "FEET",
    "WRIST", "HANDS", "BACK", "MAINHAND_VISUAL", "OFFHAND_VISUAL", "RANGED_VISUAL", "TABARD",
}

local function Split(message)
    local values = {}
    local start = 1
    while true do
        local point = string.find(message, "|", start, true)
        if not point then
            table.insert(values, string.sub(message, start))
            break
        end
        table.insert(values, string.sub(message, start, point - 1))
        start = point + 1
    end
    return values
end

local function Command(text)
    if active then
        SendChatMessage(".wardrobe " .. text, "SAY")
    end
end

local function ItemName(entry)
    local name = GetItemInfo(entry)
    return name or ("Item " .. tostring(entry))
end

local function ItemTexture(entry)
    local _, _, _, _, _, _, _, _, _, texture = GetItemInfo(entry)
    return texture or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function SetStatus(text, red)
    if not frame then return end
    frame.status:SetText(text or "")
    if red then frame.status:SetTextColor(1, .35, .25) else frame.status:SetTextColor(.45, .9, 1) end
end

local function FilteredCollection()
    local result = {}
    local needle = string.lower(searchText or "")
    for _, appearance in ipairs(collection) do
        local familyOkay = familyFilter == "ALL" or appearance.family == familyFilter
        local name = string.lower(ItemName(appearance.item))
        local searchOkay = needle == "" or string.find(name, needle, 1, true) or string.find(tostring(appearance.item), needle, 1, true)
        if familyOkay and searchOkay then table.insert(result, appearance) end
    end
    return result
end

local function RefreshModel()
    if not frame or not frame.model then return end
    frame.model:SetUnit("player")
    for slot, state in pairs(slots) do
        if state.state == "APPEARANCE" and collectionById[state.appearance] then
            frame.model:TryOn(collectionById[state.appearance].item)
        end
    end
    if selectedAppearance and collectionById[selectedAppearance] then
        frame.model:TryOn(collectionById[selectedAppearance].item)
    end
end

local function RenderCollection()
    if not frame then return end
    local filtered = FilteredCollection()
    for index, button in ipairs(frame.appearanceButtons) do
        local appearance = filtered[index]
        button.appearance = appearance
        if appearance then
            button.icon:SetTexture(ItemTexture(appearance.item))
            button.count:SetText(appearance.id)
            button:Show()
            if selectedAppearance == appearance.id then
                button:SetBackdropBorderColor(.35, .85, 1, 1)
            else
                button:SetBackdropBorderColor(.35, .35, .35, 1)
            end
        else
            button:Hide()
        end
    end
    frame.collectionCount:SetText(string.format("%d of %d appearances", table.getn(filtered), table.getn(collection)))
    local selected = selectedAppearance and collectionById[selectedAppearance]
    if selected then
        frame.detailName:SetText(ItemName(selected.item))
        frame.detailMeta:SetText(string.format("Appearance %d  |  %s  |  Source item %d", selected.id, selected.family, selected.item))
        frame.detailIcon:SetTexture(ItemTexture(selected.item))
    else
        frame.detailName:SetText("Select an appearance")
        frame.detailMeta:SetText("Choose a Wardrobe icon and an equipment slot.")
        frame.detailIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end
    frame.slotLabel:SetText("Target: " .. (SLOT_NAMES[selectedSlot] or "Unknown"))
    RefreshModel()
end

local function RenderOutfits()
    if not frame then return end
    for index, button in ipairs(frame.outfitButtons) do
        local outfit = outfits[index]
        button.outfit = outfit
        if outfit then
            button:SetText(outfit.name)
            button:Show()
            if selectedOutfit == outfit.id then button:LockHighlight() else button:UnlockHighlight() end
        else
            button:Hide()
        end
    end
    frame.outfitSelected:SetText(selectedOutfit and ("Selected outfit: " .. tostring(selectedOutfit)) or "No outfit selected")
    frame.spec0:SetText("Primary: " .. (bindings.PRIMARY_SPEC_0 or "none"))
    frame.spec1:SetText("Secondary: " .. (bindings.PRIMARY_SPEC_1 or "none"))
end

local function Render()
    RenderCollection()
    RenderOutfits()
    if frame then
        frame.syncText:SetText(syncComplete and "Server synchronized" or "Waiting for server...")
    end
end

local function SelectTab(name)
    if not frame then return end
    if name == "WARDROBE" then frame.wardrobePage:Show() else frame.wardrobePage:Hide() end
    if name == "OUTFITS" then frame.outfitsPage:Show() else frame.outfitsPage:Hide() end
    if name == "SPECS" then frame.specPage:Show() else frame.specPage:Hide() end
    if name == "VISIBILITY" then frame.visibilityPage:Show() else frame.visibilityPage:Hide() end
    for key, button in pairs(frame.tabs) do
        if key == name then button:Disable() else button:Enable() end
    end
end

local function MakeButton(parent, text, width, height)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetWidth(width or 120)
    button:SetHeight(height or 24)
    button:SetText(text)
    return button
end

local function CreateWardrobePage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints(parent)
    frame.wardrobePage = page

    local modelBox = CreateFrame("Frame", nil, page)
    modelBox:SetPoint("TOPLEFT", 14, -12)
    modelBox:SetWidth(330)
    modelBox:SetHeight(492)
    modelBox:SetBackdrop({ bgFile="Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize=14 })
    local model = CreateFrame("DressUpModel", nil, modelBox)
    model:SetPoint("TOPLEFT", 52, -42)
    model:SetPoint("BOTTOMRIGHT", -52, 70)
    model:SetUnit("player")
    frame.model = model

    frame.slotButtons = {}
    for index, slot in ipairs(SLOT_ORDER) do
        local button = MakeButton(modelBox, SLOT_NAMES[slot], 88, 24)
        local column = index <= 7 and 0 or 1
        local row = column == 0 and index - 1 or index - 8
        button:SetPoint(column == 0 and "TOPLEFT" or "TOPRIGHT", column == 0 and 7 or -7, -14 - row * 34)
        button.slot = slot
        button:SetScript("OnClick", function(self)
            selectedSlot = self.slot
            for _, other in ipairs(frame.slotButtons) do other:UnlockHighlight() end
            self:LockHighlight()
            RenderCollection()
        end)
        table.insert(frame.slotButtons, button)
    end
    frame.slotButtons[1]:LockHighlight()

    local slotLabel = modelBox:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    slotLabel:SetPoint("BOTTOM", 0, 48)
    frame.slotLabel = slotLabel
    local apply = MakeButton(modelBox, "Apply", 88, 24)
    apply:SetPoint("BOTTOMLEFT", 18, 14)
    apply:SetScript("OnClick", function()
        if selectedAppearance then Command("apply " .. selectedSlot .. " " .. selectedAppearance) end
    end)
    local hide = MakeButton(modelBox, "Hide", 88, 24)
    hide:SetPoint("BOTTOM", 0, 14)
    hide:SetScript("OnClick", function() Command("hide " .. selectedSlot) end)
    local remove = MakeButton(modelBox, "Use Real", 88, 24)
    remove:SetPoint("BOTTOMRIGHT", -18, 14)
    remove:SetScript("OnClick", function() Command("clear " .. selectedSlot) end)

    local search = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    search:SetPoint("TOPLEFT", modelBox, "TOPRIGHT", 18, -8)
    search:SetWidth(245)
    search:SetHeight(28)
    search:SetAutoFocus(false)
    search:SetScript("OnTextChanged", function(self) searchText = self:GetText() or ""; RenderCollection() end)
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    frame.search = search
    local filter = MakeButton(page, "Filter: ALL", 188, 24)
    filter:SetPoint("LEFT", search, "RIGHT", 12, 0)
    local familyIndex = 1
    filter:SetScript("OnClick", function(self)
        familyIndex = familyIndex + 1
        if familyIndex > table.getn(FAMILIES) then familyIndex = 1 end
        familyFilter = FAMILIES[familyIndex]
        self:SetText("Filter: " .. familyFilter)
        RenderCollection()
    end)

    local grid = CreateFrame("Frame", nil, page)
    grid:SetPoint("TOPLEFT", search, "BOTTOMLEFT", -5, -10)
    grid:SetWidth(450)
    grid:SetHeight(330)
    frame.appearanceButtons = {}
    for index = 1, 30 do
        local button = CreateFrame("Button", nil, grid)
        button:SetWidth(58); button:SetHeight(58)
        local column = (index - 1) % 6
        local row = math.floor((index - 1) / 6)
        button:SetPoint("TOPLEFT", column * 72, -row * 66)
        button:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize=12 })
        button:SetBackdropColor(.04, .04, .04, .9)
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", 5, -5); icon:SetPoint("BOTTOMRIGHT", -5, 5)
        button.icon = icon
        local count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        count:SetPoint("BOTTOMRIGHT", -4, 4)
        button.count = count
        button:SetScript("OnClick", function(self)
            if self.appearance then selectedAppearance = self.appearance.id; RenderCollection() end
        end)
        button:SetScript("OnEnter", function(self)
            if self.appearance then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink("item:" .. self.appearance.item .. ":0:0:0:0:0:0:0")
                GameTooltip:AddLine("Wardrobe: " .. self.appearance.family, .45, .9, 1)
                GameTooltip:Show()
            end
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        table.insert(frame.appearanceButtons, button)
    end
    local count = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    count:SetPoint("TOPLEFT", grid, "BOTTOMLEFT", 2, -5)
    frame.collectionCount = count

    local detail = CreateFrame("Frame", nil, page)
    detail:SetPoint("BOTTOMLEFT", modelBox, "BOTTOMRIGHT", 18, 0)
    detail:SetWidth(438); detail:SetHeight(112)
    detail:SetBackdrop({ bgFile="Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize=14 })
    local detailIcon = detail:CreateTexture(nil, "ARTWORK")
    detailIcon:SetPoint("LEFT", 14, 0); detailIcon:SetWidth(64); detailIcon:SetHeight(64)
    frame.detailIcon = detailIcon
    local detailName = detail:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    detailName:SetPoint("TOPLEFT", detailIcon, "TOPRIGHT", 12, -3)
    frame.detailName = detailName
    local detailMeta = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detailMeta:SetPoint("TOPLEFT", detailName, "BOTTOMLEFT", 0, -8)
    detailMeta:SetWidth(330); detailMeta:SetJustifyH("LEFT")
    frame.detailMeta = detailMeta
end

local function CreateOutfitPage(parent)
    local page = CreateFrame("Frame", nil, parent); page:SetAllPoints(parent); page:Hide(); frame.outfitsPage = page
    local title = page:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 24, -22); title:SetText("Account Outfits")
    local help = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    help:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10); help:SetText("Save or apply the current slot-persistent Wardrobe state.")
    local name = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    name:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 5, -24); name:SetWidth(260); name:SetHeight(28); name:SetAutoFocus(false)
    frame.outfitName = name
    local save = MakeButton(page, "Save Current", 130, 24)
    save:SetPoint("LEFT", name, "RIGHT", 12, 0)
    save:SetScript("OnClick", function() if name:GetText() ~= "" then Command("outfit save " .. name:GetText()) end end)
    frame.outfitButtons = {}
    for index = 1, 12 do
        local button = MakeButton(page, "", 260, 28)
        local column = index <= 6 and 0 or 1
        local row = column == 0 and index - 1 or index - 7
        button:SetPoint("TOPLEFT", 30 + column * 290, -150 - row * 42)
        button:SetScript("OnClick", function(self) if self.outfit then selectedOutfit = self.outfit.id; RenderOutfits() end end)
        table.insert(frame.outfitButtons, button)
    end
    local selected = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    selected:SetPoint("BOTTOMLEFT", 30, 80); frame.outfitSelected = selected
    local apply = MakeButton(page, "Apply", 120, 26); apply:SetPoint("BOTTOMLEFT", 30, 35)
    apply:SetScript("OnClick", function() if selectedOutfit then Command("outfit apply " .. selectedOutfit) end end)
    local delete = MakeButton(page, "Delete", 120, 26); delete:SetPoint("LEFT", apply, "RIGHT", 15, 0)
    delete:SetScript("OnClick", function() if selectedOutfit then Command("outfit delete " .. selectedOutfit) end end)
end

local function CreateSpecPage(parent)
    local page = CreateFrame("Frame", nil, parent); page:SetAllPoints(parent); page:Hide(); frame.specPage = page
    local title = page:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 24, -22); title:SetText("Specialization Bindings")
    local help = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    help:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    help:SetText("Bind the selected account outfit to the character's primary or secondary talent spec.")
    local spec0 = MakeButton(page, "Primary: none", 280, 34); spec0:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 0, -45)
    spec0:SetScript("OnClick", function() if selectedOutfit then Command("bind 0 " .. selectedOutfit) end end); frame.spec0 = spec0
    local spec1 = MakeButton(page, "Secondary: none", 280, 34); spec1:SetPoint("TOPLEFT", spec0, "BOTTOMLEFT", 0, -24)
    spec1:SetScript("OnClick", function() if selectedOutfit then Command("bind 1 " .. selectedOutfit) end end); frame.spec1 = spec1
    local clear0 = MakeButton(page, "Unbind Primary", 150, 26); clear0:SetPoint("LEFT", spec0, "RIGHT", 35, 0)
    clear0:SetScript("OnClick", function() Command("unbind 0") end)
    local clear1 = MakeButton(page, "Unbind Secondary", 150, 26); clear1:SetPoint("LEFT", spec1, "RIGHT", 35, 0)
    clear1:SetScript("OnClick", function() Command("unbind 1") end)
end

local function CreateVisibilityPage(parent)
    local page = CreateFrame("Frame", nil, parent); page:SetAllPoints(parent); page:Hide(); frame.visibilityPage = page
    local title = page:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 24, -22); title:SetText("Visibility")
    local text = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -30); text:SetWidth(650); text:SetJustifyH("LEFT")
    text:SetText("Show All is active. Hide Others and Hide All are unavailable until the server has a safe per-viewer appearance serialization capability. Your appearance is never rewritten globally.")
end

local function CreateInterface()
    if frame then return end
    frame = CreateFrame("Frame", "RebirthWardrobeFrame", UIParent)
    frame:SetWidth(840); frame:SetHeight(650); frame:SetPoint("CENTER"); frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:SetBackdrop({ bgFile="Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", tile=true, tileSize=32, edgeSize=32, insets={left=11,right=12,top=12,bottom=11} })
    frame:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -17); title:SetText("Rebirth Wardrobe")
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)
    local refresh = MakeButton(frame, "Refresh", 90, 24); refresh:SetPoint("TOPRIGHT", close, "TOPLEFT", -4, -1)
    refresh:SetScript("OnClick", function() Command("sync") end)
    local sync = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sync:SetPoint("TOPLEFT", 18, -20); frame.syncText = sync

    local body = CreateFrame("Frame", nil, frame); body:SetPoint("TOPLEFT", 16, -50); body:SetPoint("BOTTOMRIGHT", -16, 62)
    CreateWardrobePage(body); CreateOutfitPage(body); CreateSpecPage(body); CreateVisibilityPage(body)

    frame.tabs = {}
    local labels = { {"WARDROBE","Wardrobe"}, {"OUTFITS","Outfits"}, {"SPECS","Spec Bindings"}, {"VISIBILITY","Visibility"} }
    local previous
    for _, info in ipairs(labels) do
        local tab = MakeButton(frame, info[2], 150, 26)
        if previous then tab:SetPoint("LEFT", previous, "RIGHT", 8, 0) else tab:SetPoint("BOTTOMLEFT", 28, 24) end
        tab:SetScript("OnClick", function() SelectTab(info[1]) end)
        frame.tabs[info[1]] = tab; previous = tab
    end
    local status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("BOTTOMRIGHT", -22, 30); status:SetWidth(175); status:SetJustifyH("RIGHT"); frame.status = status
    SelectTab("WARDROBE")

    if MainMenuBar then
        local micro = CreateFrame("Button", "RebirthWardrobeMicroButton", MainMenuBar)
        micro:SetWidth(28); micro:SetHeight(36); micro:SetFrameStrata("MEDIUM")
        local icon = micro:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", 2, -5); icon:SetPoint("BOTTOMRIGHT", -2, 5)
        icon:SetTexture("Interface\\Icons\\INV_Misc_EngGizmos_19"); icon:SetTexCoord(.08,.92,.08,.92)
        local border = micro:CreateTexture(nil, "OVERLAY"); border:SetAllPoints(micro); border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        micro:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        micro:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
        micro:SetScript("OnClick", function() if frame:IsShown() then frame:Hide() else frame:Show(); Command("sync") end end)
        micro:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self,"ANCHOR_TOP"); GameTooltip:AddLine("Rebirth Wardrobe",.45,.9,1); GameTooltip:AddLine("Account appearances and outfits.",1,1,1); GameTooltip:Show() end)
        micro:SetScript("OnLeave", function() GameTooltip:Hide() end)
        micro:ClearAllPoints(); micro:SetPoint("BOTTOMLEFT", AchievementMicroButton or ProjectRebirthMicroButton or QuestLogMicroButton, "BOTTOMRIGHT", -2, 0)
        if ProjectRebirth_LayoutMicroButtons then ProjectRebirth_LayoutMicroButtons() end
    end
    Render()
end

local function HandleProtocol(message)
    local fields = Split(message)
    if fields[1] ~= "RWD" then return false end
    local kind = fields[2]
    if kind == "BEGIN" then
        collection = {}; collectionById = {}; slots = {}; outfits = {}; bindings = {}; syncComplete = false
    elseif kind == "COLLECTION" then
        local appearance = { id=tonumber(fields[3]), item=tonumber(fields[4]), family=fields[5], quality=tonumber(fields[6]) or 0 }
        table.insert(collection, appearance); collectionById[appearance.id] = appearance
        GetItemInfo(appearance.item)
    elseif kind == "SLOT" then
        slots[tonumber(fields[3])] = { state=fields[4], appearance=tonumber(fields[5]) or 0 }
    elseif kind == "OUTFIT" then
        table.insert(outfits, { id=tonumber(fields[3]), name=fields[4], icon=tonumber(fields[5]) or 0 })
    elseif kind == "BINDING" then
        bindings[fields[3]] = fields[4]
    elseif kind == "END" then
        syncComplete = true; Render(); SetStatus("Ready")
    elseif kind == "RESULT" then
        SetStatus(fields[3] .. ": " .. fields[4], fields[4] ~= "OK")
        if fields[4] == "OK" then Command("sync") end
    elseif kind == "EVENT" then
        Command("sync")
    end
    return true
end

ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(self, event, message, ...)
    if active and string.sub(message or "", 1, 4) == "RWD|" then
        HandleProtocol(message)
        return true
    end
    return false, message, ...
end)

SLASH_REBIRTHWARDROBE1 = "/wardrobe"
SlashCmdList.REBIRTHWARDROBE = function()
    if not active then return end
    CreateInterface()
    if frame:IsShown() then frame:Hide() else frame:Show(); Command("sync") end
end

SLASH_REBIRTHWARDROBEADD1 = "/wardrobeadd"
SlashCmdList.REBIRTHWARDROBEADD = function(text)
    local _, _, bag, slot = string.find(text or "", "^(%d+)%s+(%d+)$")
    if bag and slot then Command("collect " .. bag .. " " .. slot) end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
events:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        active = GetRealmName() == REALM
        if active then CreateInterface() end
    elseif event == "GET_ITEM_INFO_RECEIVED" and active and frame and frame:IsShown() then
        RenderCollection()
    end
end)
