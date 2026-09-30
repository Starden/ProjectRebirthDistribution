-- The server grants this bonus after native quest rewards. Preview it using the
-- stock quest layout; do not replace native reward APIs or alter item choices.
local PS = ProjectSkillful
if not PS then return end

local reward
local row, item, heading, receive
local lastDisplay
local refreshing = false
local fallbackIcon = "Interface\\Icons\\INV_Drink_06"

local function UpdateItem()
    if not item or not reward then return end
    local name, link, quality, _, _, _, _, _, _, texture = GetItemInfo(reward.entry)
    _G["ProjectSkillfulQuestBottleName"]:SetText(name or "Bottle of Experience")
    SetItemButtonTexture(item, texture or fallbackIcon)
    SetItemButtonCount(item, reward.count)
    SetItemButtonTextureVertexColor(item, 1, 1, 1)
    SetItemButtonNameFrameVertexColor(item, 1, 1, 1)
    local r, g, b = GetItemQualityColor(quality or 2)
    _G["ProjectSkillfulQuestBottleName"]:SetTextColor(r, g, b)
end

local function EnsureRow()
    if row then return end
    row = CreateFrame("Frame", "ProjectSkillfulQuestReward", UIParent)
    row:SetWidth(285)
    row:Hide()
    heading = row:CreateFontString(nil, "ARTWORK", "QuestTitleFont")
    heading:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    heading:SetText(QUEST_REWARDS)
    receive = row:CreateFontString(nil, "ARTWORK", "QuestFont")
    receive:SetWidth(285)
    receive:SetJustifyH("LEFT")
    receive:SetText(REWARD_ITEMS_ONLY)
    item = CreateFrame("Button", "ProjectSkillfulQuestBottle", row, "QuestItemTemplate")
    item:SetScript("OnEnter", function(self)
        if not reward then return end
        local tooltip = _G[QuestInfoFrame.tooltip or "GameTooltip"]
        if tooltip then
            tooltip:SetOwner(self, "ANCHOR_RIGHT")
            tooltip:SetHyperlink("item:" .. reward.entry)
            tooltip:Show()
        end
    end)
    item:SetScript("OnLeave", function()
        local tooltip = _G[QuestInfoFrame.tooltip or "GameTooltip"]
        if tooltip then tooltip:Hide() end
        ResetCursor()
    end)
    item:SetScript("OnClick", function()
        if reward and IsModifiedClick("CHATLINK") then
            local _, link = GetItemInfo(reward.entry)
            if link then HandleModifiedItemClick(link) end
        end
    end)
end

local function ShowReward()
    if not reward then
        if row then row:Hide() end
        return nil
    end
    EnsureRow()
    row:ClearAllPoints()
    receive:ClearAllPoints()
    item:ClearAllPoints()
    if QuestInfoRewardsFrame:IsShown() then
        heading:Hide()
        receive:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    else
        heading:Show()
        receive:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -5)
    end
    local textColor, titleColor = GetMaterialTextColors(QuestInfoFrame.material)
    receive:SetTextColor(unpack(textColor))
    heading:SetTextColor(unpack(titleColor))
    item:SetPoint("TOPLEFT", receive, "BOTTOMLEFT", -3, -5)
    row:SetHeight((heading:IsShown() and heading:GetHeight() + 5 or 0)
        + receive:GetHeight() + 5 + item:GetHeight())
    UpdateItem()
    item:Show()
    row:Show()
    return row
end

-- All four stock reward surfaces use the same triplet-based layout. Inserting
-- one element lets the native spacer/scroll child include the extra row even
-- for quests with no native reward at all (for example Simple Letter).
for _, name in ipairs({"QUEST_TEMPLATE_DETAIL2", "QUEST_TEMPLATE_REWARD",
    "QUEST_TEMPLATE_LOG", "QUEST_TEMPLATE_MAP2"}) do
    local template = _G[name]
    if template and template.elements then
        for index = #template.elements - 2, 1, -3 do
            if template.elements[index] == QuestInfo_ShowRewards then
                table.insert(template.elements, index + 3, ShowReward)
                table.insert(template.elements, index + 4, 0)
                table.insert(template.elements, index + 5, -5)
            end
        end
    end
end

if QuestInfo_Display and hooksecurefunc then
    hooksecurefunc("QuestInfo_Display", function(template, parent, accept, cancel, material)
        lastDisplay = {template, parent, accept, cancel, material}
        local usesRewards = false
        for index = 1, #template.elements, 3 do
            if template.elements[index] == ShowReward then usesRewards = true end
        end
        if not usesRewards and row then row:Hide() end
    end)
end

local function RefreshDisplay()
    if refreshing or not lastDisplay or not lastDisplay[2]:IsShown() then return end
    refreshing = true
    local choice = QuestInfoFrame.itemChoice or 0
    local display = lastDisplay
    QuestInfo_Display(display[1], display[2], display[3], display[4], display[5])
    -- Native re-layout clears choices. Preserve a selection the player already
    -- made when a late policy arrives or is disabled while the window is open.
    if choice > 0 and _G["QuestInfoItem" .. choice] then
        QuestInfoFrame.itemChoice = choice
        QuestInfoItemHighlight:ClearAllPoints()
        QuestInfoItemHighlight:SetPoint("TOPLEFT", _G["QuestInfoItem" .. choice], "TOPLEFT", -8, 7)
        QuestInfoItemHighlight:Show()
    end
    refreshing = false
end

function PS.ClearQuestReward()
    local hadReward = reward ~= nil
    reward = nil
    if row then row:Hide() end
    if hadReward then RefreshDisplay() end
end

function PS.HandleQuestRewardMessage(message)
    if not string.match(message, "^Q|") then return false end
    if message == "Q|1|900000|1" then
        local changed = not reward
        reward = {entry = 900000, count = 1}
        if changed then RefreshDisplay() end
    else
        -- Disabled, malformed and future policies must never promise a reward.
        PS.ClearQuestReward()
    end
    return true
end

local events = CreateFrame("Frame", "ProjectSkillfulQuestRewardEvents")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("QUEST_ITEM_UPDATE")
events:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        PS.ClearQuestReward()
        lastDisplay = nil
    else
        UpdateItem()
    end
end)
