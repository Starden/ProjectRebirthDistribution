-- Presentation only. Preserve native clicks, enabled states and keybindings.
ProjectRebirthMicroMenu = {}
local menu = ProjectRebirthMicroMenu
local queued = false
local layingOut = false
local order = {
    "CharacterMicroButton", "SpellbookMicroButton", "TalentMicroButton",
    "QuestLogMicroButton", "ProjectRebirthMicroButton", "AchievementMicroButton",
    "RebirthWardrobeMicroButton", "SocialsMicroButton", "PVPMicroButton",
    "LFDMicroButton", "MainMenuMicroButton",
}

-- Stock Wrath micro buttons are 28x58 with artwork below the top 18 pixels.
-- The portrait shell is a native empty frame, unlike an action-slot border.
function menu.Skin(button, texture)
    button:SetWidth(28)
    button:SetHeight(58)
    button:SetHitRectInsets(0, 0, 18, 0)
    button:SetNormalTexture("Interface\\Buttons\\UI-MicroButtonCharacter-Up")
    button:SetPushedTexture("Interface\\Buttons\\UI-MicroButtonCharacter-Down")
    button:SetHighlightTexture("Interface\\Buttons\\UI-MicroButton-Hilight", "ADD")
    local icon = button:CreateTexture(nil, "OVERLAY")
    icon:SetWidth(18)
    icon:SetHeight(25)
    icon:SetPoint("TOP", button, "TOP", 0, -28)
    icon:SetTexture(texture)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button:HookScript("OnMouseDown", function() icon:SetAlpha(0.5) end)
    button:HookScript("OnMouseUp", function() icon:SetAlpha(1) end)
    button:HookScript("OnHide", function() icon:SetAlpha(1) end)
    return icon
end

function menu.Buttons()
    local result = {}
    -- Iterate names, not a sparse table of optional frames: ipairs stops at nil.
    for _, name in ipairs(order) do
        if _G[name] then result[#result + 1] = _G[name] end
    end
    return result
end

function menu.Step(count, available)
    if count < 2 then return 25 end
    -- Keep native art/height unscaled. At most one extra pixel of shell overlap
    -- is needed for the standard eleven-button row with a visible keyring.
    return math.min(25, math.max(22, (available - 28) / (count - 1)))
end

function menu.Layout()
    if layingOut or GetRealmName() ~= "Rebirth" then return end
    if InCombatLockdown and InCombatLockdown() then queued = true; return end
    local first = CharacterMicroButton
    local parent = MainMenuBarArtFrame or MainMenuBar
    if not first or not parent then queued = true; return end
    -- Vehicle/override layouts are owned by Blizzard. Never rearrange their row.
    if first:GetParent() ~= parent then queued = false; return end
    local buttons = menu.Buttons()
    for _, button in ipairs(buttons) do
        if button:GetParent() ~= parent then queued = false; return end
    end
    local scale = first:GetEffectiveScale()
    local left = first:GetLeft()
    if not left or not scale or scale <= 0 then queued = true; return end
    local boundary
    for _, name in ipairs({ "KeyRingButton", "CharacterBag3Slot", "CharacterBag2Slot",
        "CharacterBag1Slot", "CharacterBag0Slot", "MainMenuBarBackpackButton" }) do
        local bag = _G[name]
        if bag and bag:IsShown() and bag:GetLeft() then
            local edge = bag:GetLeft() * bag:GetEffectiveScale() / scale
            if edge > left and (not boundary or edge < boundary) then boundary = edge end
        end
    end
    local available = boundary and boundary - left - 3 or 278
    -- Leave third-party compressed bars alone rather than overlap bags or icons.
    if available < 28 + (#buttons - 1) * 22 then return end
    layingOut = true
    local step = menu.Step(#buttons, available)
    for i = 2, #buttons do
        local button = buttons[i]
        button:ClearAllPoints()
        button:SetPoint("BOTTOMLEFT", buttons[i - 1], "BOTTOMRIGHT", step - 28, 0)
    end
    if HelpMicroButton then HelpMicroButton:Hide() end
    layingOut = false
    queued = false
end

ProjectRebirth_LayoutMicroButtons = menu.Layout
local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
    "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED", "UNIT_EXITED_VEHICLE" }) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function() queued = true end)
events:SetScript("OnUpdate", function()
    if queued and not (InCombatLockdown and InCombatLockdown()) then menu.Layout() end
end)
if hooksecurefunc and UpdateMicroButtons then hooksecurefunc("UpdateMicroButtons", menu.Layout) end
if MainMenuBarArtFrame then MainMenuBarArtFrame:HookScript("OnShow", function() queued = true end) end
if HelpMicroButton then HelpMicroButton:HookScript("OnShow", function() menu.Layout() end) end
