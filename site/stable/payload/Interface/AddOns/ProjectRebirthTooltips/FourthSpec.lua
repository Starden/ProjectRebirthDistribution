-- Server-authoritative Rebirth fourth tree embedded in Wrath's Talent frame.
local D = ProjectRebirthFourthSpecData
if not D or D.schemaVersion ~= 2 then return end

local PREFIX, PROTOCOL = "ProjectRebirth", "3"
local tree, snapshot, incoming, selected, hoveredButton
local integrated, customActive, refreshing, awaiting = false, false, false, false
local customTab, customPane, customScroll, customCanvas, customHeader, customStatus, placeholder
local customGrid, customBackground, backgroundAspect
local buttons, lines = {}, {}
local hiddenNativeWidgets = {}
local nativeLayout, layoutBusy
local frameExtensions = {}
local PositionTabs, RestoreTalentLayout, layoutDriver, pendingLayout, pendingPanelReflow
-- Owner-supplied portrait backgrounds. Preserve source proportions at full scroll height.
local treeArtwork = {
    PALADIN = {"HolyArcher", 2 / 3}, DRUID = {"Guardian", 2 / 3},
    WARLOCK = {"Incarnation", 2 / 3}, HUNTER = {"Skirmisher", 2 / 3},
    ROGUE = {"Swashbuckler", 2 / 3}, MAGE = {"Battlemage", 3 / 4},
    WARRIOR = {"Gladiator", 2 / 3}, PRIEST = {"Inquisitor", 2 / 3},
    SHAMAN = {"Primalist", 3 / 4},
}
-- Presentation only. These stock icons never grant the represented spells.
local skyIcons = {
    "Spell_Frost_FrostBolt02", "Ability_Marksmanship", "Ability_ImpalingBolt",
    "Spell_DeathKnight_EmpowerRuneBlade2", "Spell_Shadow_BlackPlague", "Ability_Hunter_RangedDamage",
    "Spell_DeathKnight_RuneTap", "Spell_Shadow_PlagueCloud", "Ability_Hunter_SniperShot",
    "Ability_Hunter_RapidKilling", "Spell_Shadow_Contagion", "Spell_DeathKnight_Runeforging",
    "Spell_Frost_IceStorm", "Spell_Shadow_DeathPact", "Ability_Hunter_PiercingShots",
    "Spell_Shadow_DeathAndDecay", "Ability_Hunter_LongShots", "Spell_Shadow_DeathCoil",
    "Spell_DeathKnight_FrostPresence", "Ability_Hunter_ImprovedSteadyShot", "Ability_Hunter_MasterMarksman",
    "Spell_DeathKnight_Butcher2", "INV_Misc_Quiver_04", "Spell_Shadow_SoulLeech_3",
    "Spell_Shadow_Rune", "Ability_Hunter_Assassinate2", "Spell_Shadow_ShadeTrueSight",
}
local NODE_SIZE, COLUMN_STEP, ROW_STEP = 32, 63, 63
local function NodePosition(node)
    return 35 + (node.column - 1) * COLUMN_STEP, 20 + (node.row - 1) * ROW_STEP
end
local Render

local function Active()
    return GetRealmName and GetRealmName() == "Rebirth"
end

local function ClassTree()
    local _, token = UnitClass("player")
    for _, candidate in ipairs(D.trees) do
        if candidate.classToken == token then return candidate end
    end
end

local function Profile()
    return GetActiveTalentGroup and GetActiveTalentGroup() or 1
end

local function Say(text)
    if UIErrorsFrame then
        UIErrorsFrame:AddMessage(text, 1, 0.125, 0.125)
    elseif DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(text)
    end
end

local function SendRequest(request)
    if not Active() or not SendAddonMessage or not UnitName("player") then return end
    SendAddonMessage(PREFIX, PROTOCOL .. "\t" .. request, "WHISPER", UnitName("player"))
end

local function RequestState()
    SendRequest("FOURTH_STATE")
end

local function Text(parent, template)
    local text = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
    text:SetJustifyH("LEFT")
    return text
end

local function SmallButton(parent, label, width, click)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 20)
    button:SetText(label)
    button:SetScript("OnClick", click)
    return button
end

local function NativeSurface(visible)
    if visible then
        for widget, wasShown in pairs(hiddenNativeWidgets) do
            if wasShown then widget:Show() else widget:Hide() end
        end
        hiddenNativeWidgets = {}
        return
    end
    for _, name in ipairs({
        "PlayerTalentFrameScrollFrame", "PlayerTalentFrameScrollButtonOverlay",
        "PlayerTalentFramePreviewBar", "PlayerTalentFrameLearnButton",
        "PlayerTalentFrameResetButton", "PlayerTalentFrameActivateButton",
        "PlayerTalentFrameStatusFrame", "GlyphFrame"
    }) do
        local widget = _G[name]
        if widget then
            if hiddenNativeWidgets[widget] == nil then
                hiddenNativeWidgets[widget] = widget:IsShown() and true or false
            end
            widget:Hide()
        end
    end
end

local function DeselectNativeTabs()
    for i = 1, 4 do
        local tab = _G["PlayerTalentFrameTab" .. i]
        if tab then
            if PanelTemplates_DeselectTab then PanelTemplates_DeselectTab(tab)
            elseif tab.SetButtonState then tab:SetButtonState("NORMAL") end
            if tab.Enable then tab:Enable() end
        end
    end
end

local function SelectCustomTab(value)
    if not customTab then return end
    if value then
        DeselectNativeTabs()
        PanelTemplates_SelectTab(customTab)
    else
        PanelTemplates_DeselectTab(customTab)
    end
end

local function ApplyCustomView()
    if not customActive or not PlayerTalentFrame then return end
    NativeSurface(false)
    if PlayerTalentFramePointsBar then PlayerTalentFramePointsBar:Show() end
    if customPane then customPane:Show() end
    SelectCustomTab(true)
    if Render then Render() end
end

local function DeactivateCustom(refreshNative)
    if not customActive then return end
    if hoveredButton and GameTooltip:IsOwned(hoveredButton) then GameTooltip:Hide() end
    selected, hoveredButton = nil, nil
    customActive = false
    if customPane then customPane:Hide() end
    SelectCustomTab(false)
    NativeSurface(true)
    if refreshNative and PlayerTalentFrame_Refresh and not refreshing then
        refreshing = true
        PlayerTalentFrame_Refresh()
        refreshing = false
    end
end

local function NodeByKey(key)
    for _, node in ipairs(tree.nodes) do
        if node.key == key then return node end
    end
end

local function Rank(key)
    return snapshot and snapshot.ranks[key] or 0
end

local function Tooltip(node, button)
    local rank = Rank(node.key)
    local required = NodeByKey(node.prerequisite)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:AddLine(node.name, 1, 1, 1)
    GameTooltip:AddLine("Rank " .. rank .. "/" .. node.maxRank, 1, 1, 1)
    if required then
        local met = Rank(required.key) >= node.prerequisiteRank
        GameTooltip:AddLine("Requires " .. node.prerequisiteRank .. " points in " .. required.name,
            1, met and 1 or 0.125, met and 1 or 0.125, true)
    end
    if node.requiredPoints > (snapshot and snapshot.fourthSpent or 0) then
        GameTooltip:AddLine("Requires " .. node.requiredPoints .. " points in " .. tree.name,
            1, 0.125, 0.125, true)
    end
    local card = node.ranks[math.max(1, rank)]
    local alpha = ProjectRebirthFourthSpecAlpha and ProjectRebirthFourthSpecAlpha[node.talentId]
    if card then GameTooltip:AddLine(alpha and alpha[math.max(1, rank)] or card.preview, 1, 0.82, 0, true) end
    if rank > 0 and rank < node.maxRank then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Next rank:", 1, 1, 1)
        GameTooltip:AddLine(alpha and alpha[rank + 1] or node.ranks[rank + 1].preview, 1, 0.82, 0, true)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(alpha and "Alpha defaults. Effects require the alpha server; configured values may differ."
        or "Work in progress. Effect not yet active.", 0.65, 0.65, 0.65, true)
    if rank < node.maxRank and snapshot and snapshot.status == "ready" and snapshot.writable and
        snapshot.budget > snapshot.nativeSpent + snapshot.fourthSpent and
        snapshot.fourthSpent >= node.requiredPoints and Rank(node.prerequisite) >= node.prerequisiteRank then
        GameTooltip:AddLine("Click to learn", 0.1, 1, 0.1)
    end
    ProjectRebirthCompletion.Tooltip(GameTooltip, rank, node.maxRank, node.talentId)
    GameTooltip:Show()
end

local function Adjust(node, delta)
    selected = node
    if awaiting then return end
    if not snapshot or snapshot.status ~= "ready" or not snapshot.writable then
        Say("Talents are not available yet. Please try again.")
        RequestState()
        return
    end
    local target = Rank(node.key) + delta
    if target < 0 or target > node.maxRank then return end
    awaiting = true
    SendRequest("FOURTH_SET\t" .. snapshot.rowVersion .. "\t" .. node.key .. "\t" .. target)
end

local function MakeNode(node, index)
    -- Use the client's actual template, including its BACKGROUND slot, item
    -- icon, normal/pushed/highlight textures and 32px OVERLAY rank badge.
    -- Do not inherit PlayerTalentButtonTemplate: its handlers call LearnTalent.
    local name = "ProjectRebirthFourthTalent" .. node.talentId
    local button = CreateFrame("Button", name, customGrid, "TalentButtonTemplate")
    button:SetSize(NODE_SIZE, NODE_SIZE)
    local x, y = NodePosition(node)
    button:SetPoint("TOPLEFT", customGrid, "TOPLEFT", x, -y)
    button.icon = _G[name .. "IconTexture"]
    if not button.icon:SetTexture("Interface\\Icons\\" ..
        (node.icon or (tree.key == "SKY_DARKENER" and skyIcons[index] or tree.icon))) then
        button.icon:SetTexture("Interface\\Icons\\" .. tree.icon)
    end
    button.slot = _G[name .. "Slot"]
    button.rankBorder = _G[name .. "RankBorder"]
    button.rank = _G[name .. "Rank"]
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnClick", function(_, mouse)
        selected, hoveredButton = node, button
        Adjust(node, mouse == "RightButton" and -1 or 1)
        Tooltip(node, button)
    end)
    button:SetScript("OnEnter", function() selected, hoveredButton = node, button; Tooltip(node, button) end)
    button:SetScript("OnLeave", function()
        selected, hoveredButton = nil, nil
        if GameTooltip:IsOwned(button) then GameTooltip:Hide() end
    end)
    buttons[node.key] = button
end

local function LayoutFourthSurface()
    if not customCanvas then return end
    -- Fill the shell's native interior rather than inheriting the deliberately
    -- fixed-width native viewport. Leave the 31px scrollbar trim at the right
    -- border, not floating halfway across an expanded frame.
    local width = math.max(296, PlayerTalentFrame:GetWidth() - 88)
    customScroll:SetWidth(width)
    customCanvas:SetWidth(width)
    customGrid:SetWidth(296)
    customGrid:ClearAllPoints()
    customGrid:SetPoint("TOP", customCanvas, "TOP", 0, 0)
    if customBackground then
        local height = customCanvas:GetHeight()
        customBackground:SetSize(width, height)
        -- Aspect-preserving cover, expressed as UVs inside the exact scrolling
        -- canvas. Oversized textures could extend scroll bounds past the art;
        -- undersized textures leave black side gutters. Neither is needed.
        local ratio = width / height
        if ratio < backgroundAspect then
            local visible = ratio / backgroundAspect
            customBackground:SetTexCoord((1 - visible) / 2, (1 + visible) / 2, 0, 1)
        else
            local visible = backgroundAspect / ratio
            customBackground:SetTexCoord(0, 1, (1 - visible) / 2, (1 + visible) / 2)
        end
    end
end

local function BuildTreeCanvas()
    -- Native 64px slots and rank badges extend 16px below a 32px icon.
    -- Include that artwork in the scroll child, plus a small bottom margin,
    -- so the last row cannot extend the scroll range beyond the background.
    local canvasHeight = 690
    for _, node in ipairs(tree.nodes) do
        local _, y = NodePosition(node)
        canvasHeight = math.max(canvasHeight, y + NODE_SIZE + 16 + 8)
    end
    customCanvas:SetHeight(canvasHeight)
    customGrid:SetHeight(canvasHeight)
    if tree.key == "SKY_DARKENER" then
        customBackground = customCanvas:CreateTexture("ProjectRebirthSkyDarkenerBackground", "BACKGROUND")
        backgroundAspect = 1 / 2
        customBackground:SetPoint("TOPLEFT", customCanvas, "TOPLEFT", 0, 0)
        customBackground:SetTexture("Interface\\AddOns\\ProjectRebirthTooltips\\Media\\SkyDarkener.tga")
    elseif treeArtwork[tree.classToken] then
        local art = treeArtwork[tree.classToken]
        customBackground = customCanvas:CreateTexture("ProjectRebirthFourthTreeBackground", "BACKGROUND")
        backgroundAspect = art[2]
        customBackground:SetPoint("TOPLEFT", customCanvas, "TOPLEFT", 0, 0)
        customBackground:SetTexture("Interface\\AddOns\\ProjectRebirthTooltips\\Media\\" .. art[1] .. ".tga")
    end
    LayoutFourthSurface()

    if #tree.nodes == 0 then
        placeholder = Text(customCanvas, "GameFontNormalLarge")
        placeholder:SetPoint("TOPLEFT", customCanvas, "TOPLEFT", 18, -70)
        placeholder:SetWidth(235)
        placeholder:SetText("|cff88ddff" .. tree.name .. "|r\n\nThis native fourth-tree slot is active and server-owned. Its authored talent catalog is still WIP; no ranks are available yet.")
        return
    end
    for index, node in ipairs(tree.nodes) do MakeNode(node, index) end
    for _, node in ipairs(tree.nodes) do
        local parent = NodeByKey(node.prerequisite)
        if parent then
            local x1, y1 = NodePosition(parent)
            local x2, y2 = NodePosition(node)
            x1, x2 = x1 + 16, x2 + 16
            local mid = y2 - 14
            if parent.column == node.column then
                -- Native branch atlas, at native pixel density, not a solid
                -- colored line. All Sky Darkener prerequisites are vertical.
                for y = y1 + 31, y2 - 20, 31 do
                    local branch = customGrid:CreateTexture(nil, "BORDER")
                    branch:SetTexture("Interface\\TalentFrame\\UI-TalentBranches")
                    branch:SetSize(32, 32)
                    branch:SetPoint("TOPLEFT", customGrid, "TOPLEFT", x1 - 14, -y)
                    lines[#lines + 1] = {texture=branch, node=node, branch=true}
                end
            else
            for _, segment in ipairs({{x1,y1+32,x1,mid},{x1,mid,x2,mid},{x2,mid,x2,y2-4}}) do
                local line = customGrid:CreateTexture(nil, "BORDER")
                line:SetTexture(0.65, 0.65, 0.65, 1)
                line:SetPoint("TOPLEFT", customGrid, "TOPLEFT", math.min(segment[1], segment[3]), -math.min(segment[2], segment[4]))
                line:SetSize(math.max(2, math.abs(segment[3] - segment[1])), math.max(2, math.abs(segment[4] - segment[2])))
                lines[#lines + 1] = {texture=line, node=node}
            end
            end
            local arrow = customGrid:CreateTexture(nil, "BORDER")
            arrow:SetTexture("Interface\\TalentFrame\\UI-TalentArrows")
            arrow:SetTexCoord(0, 0.5, 0, 0.5)
            arrow:SetSize(32, 32)
            arrow:SetPoint("TOPLEFT", customGrid, "TOPLEFT", x2 - 14, -y2 + 19)
            lines[#lines + 1] = {texture=arrow, node=node, arrow=true}
        end
    end
end

local function SaveAnchors(widget)
    local points = {}
    for i = 1, widget:GetNumPoints() do points[i] = {widget:GetPoint(i)} end
    return points
end

local function RestoreAnchors(widget, points)
    widget:ClearAllPoints()
    for _, point in ipairs(points) do widget:SetPoint(unpack(point)) end
end

local function ScheduleTalentLayout(rebuild)
    pendingLayout = pendingLayout or rebuild
    pendingPanelReflow = true
    if not layoutDriver then layoutDriver = CreateFrame("Frame") end
    layoutDriver:SetScript("OnUpdate", function(self)
        if InCombatLockdown and InCombatLockdown() then return end
        if pendingLayout then
            pendingLayout = nil
            if PlayerTalentFrame:IsShown() then PositionTabs() else RestoreTalentLayout() end
        end
        if pendingPanelReflow then
            pendingPanelReflow = nil
            -- Dispatch after the native OnShow/update stack unwinds. Its
            -- FramePositionDelegate ignores nested panel updates; SetWidth
            -- alone does not recalculate CENTER_OFFSET for adjacent windows.
            if PlayerTalentFrame:IsShown() and UpdateUIPanelPositions then
                UpdateUIPanelPositions(PlayerTalentFrame)
            end
        end
        if not pendingLayout and not pendingPanelReflow then self:SetScript("OnUpdate", nil) end
    end)
end

-- Stock art is a 300x331 mosaic (256+44 by 256+75), displayed behind
-- the scrolling buttons. Cover the wider viewport without stretching either
-- artwork or talent coordinates. Keep Blizzard's own textures so its native
-- tab update and inactive-spec desaturation continue to work normally.
local nativePieces = {
    {"TopLeft", 0, 0, 256, 256, 256, 256},
    {"TopRight", 256, 0, 44, 256, 64, 256},
    {"BottomLeft", 0, 256, 256, 75, 256, 128},
    {"BottomRight", 256, 256, 44, 75, 64, 128},
}

local function RestoreNativeSurfaceLayout()
    local saved = nativeLayout and nativeLayout.surface
    if not saved then return end
    local scroll = PlayerTalentFrameScrollFrame
    scroll:SetWidth(saved.width)
    scroll:SetHorizontalScroll(saved.horizontal)
    for _, art in ipairs(saved.art) do
        art.texture:SetSize(art.width, art.height)
        RestoreAnchors(art.texture, art.anchors)
        art.texture:SetTexCoord(unpack(art.uv))
        if art.shown then art.texture:Show() else art.texture:Hide() end
    end
end

local function LayoutNativeSurface(extra)
    local scroll, child = PlayerTalentFrameScrollFrame, PlayerTalentFrameScrollChildFrame
    if not scroll or not child or scroll:GetScrollChild() ~= child or child:GetParent() ~= scroll then return end
    if not nativeLayout.surface then
        local saved = {width=scroll:GetWidth(), horizontal=scroll:GetHorizontalScroll(), art={}}
        for _, piece in ipairs(nativePieces) do
            local texture = _G["PlayerTalentFrameBackground" .. piece[1]]
            if not texture then return end -- Unknown client layout: leave native content alone.
            saved.art[#saved.art + 1] = {texture=texture, width=texture:GetWidth(), height=texture:GetHeight(),
                anchors=SaveAnchors(texture), uv={texture:GetTexCoord()}, shown=texture:IsShown()}
        end
        nativeLayout.surface = saved
        scroll:HookScript("OnSizeChanged", function()
            if not layoutBusy then ScheduleTalentLayout(true) end
        end)
    end
    local saved = nativeLayout.surface
    if extra == 0 or (GlyphFrame and GlyphFrame:IsShown() and not customActive) then
        RestoreNativeSurfaceLayout()
        return
    end
    local width, height = nativeLayout.width + extra - 88, scroll:GetHeight()
    scroll:SetWidth(width)
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", PlayerTalentFrame, "TOPLEFT", 23, -77)
    scroll:SetPoint("BOTTOMRIGHT", PlayerTalentFramePointsBar, "TOPRIGHT", -29, 0)
    -- Wrath's original scroll child owns clipping for the native buttons,
    -- branches and arrow frame. Replacing it with a wrapper breaks that
    -- relationship and lets lower rows draw over tabs/chat. Keep its parent,
    -- registration, anchors and native scroll bounds completely untouched.
    -- A negative horizontal view offset adds the desired left padding without
    -- moving any widget out of Blizzard's native scrolling hierarchy.
    scroll:SetHorizontalScroll(saved.horizontal - extra / 2)
    if height <= 0 then return end
    local scale = math.max(width / 300, height / 331)
    local cropX, cropY = (300 - width / scale) / 2, (331 - height / scale) / 2
    for index, piece in ipairs(nativePieces) do
        local texture = saved.art[index].texture
        local left, top = math.max(piece[2], cropX), math.max(piece[3], cropY)
        local right = math.min(piece[2] + piece[4], cropX + width / scale)
        local bottom = math.min(piece[3] + piece[5], cropY + height / scale)
        texture:ClearAllPoints()
        if right > left and bottom > top then
            texture:SetPoint("TOPLEFT", scroll, "TOPLEFT", (left-cropX)*scale, -(top-cropY)*scale)
            texture:SetSize((right-left)*scale, (bottom-top)*scale)
            texture:SetTexCoord((left-piece[2])/piece[6], (right-piece[2])/piece[6],
                (top-piece[3])/piece[7], (bottom-piece[3])/piece[7])
            texture:Show()
        else
            texture:Hide()
        end
    end
end

RestoreTalentLayout = function()
    if not nativeLayout then return end
    if InCombatLockdown and InCombatLockdown() then ScheduleTalentLayout(true); return end
    local changed = PlayerTalentFrame:GetWidth() ~= nativeLayout.width
    PlayerTalentFrame:SetWidth(nativeLayout.width)
    LayoutFourthSurface()
    RestoreNativeSurfaceLayout()
    RestoreAnchors(PlayerTalentFrameScrollFrame, nativeLayout.scroll)
    RestoreAnchors(PlayerTalentFrameTab4, nativeLayout.glyphTab)
    if nativeLayout.glyphFrame then RestoreAnchors(GlyphFrame, nativeLayout.glyphFrame) end
    for _, extension in ipairs(frameExtensions) do extension:Hide() end
    if changed then ScheduleTalentLayout(false) end
end

local function ExtendTalentBorder(extra)
    -- The stock frame is four fixed 256-high texture quadrants. Never stretch
    -- those quadrants (portrait/corners), the tree artwork or the glyph sheet.
    -- Fill only the new center seam with pixel-for-pixel 32px strips from the
    -- right edge of each left quadrant. The final partial strip uses matching UVs.
    local used = 0
    for _, half in ipairs({"Top", "Bottom"}) do
        local source = _G["PlayerTalentFrame" .. half .. "Left"]
        for offset = 0, extra - 1, 32 do
            used = used + 1
            local strip = frameExtensions[used]
            if not strip then
                strip = PlayerTalentFrame:CreateTexture(nil, "BORDER")
                frameExtensions[used] = strip
            end
            local width = math.min(32, extra - offset)
            strip:SetTexture(source:GetTexture())
            strip:SetSize(width, 256)
            strip:SetTexCoord((256 - width) / 256, 1, 0, 1)
            strip:ClearAllPoints()
            strip:SetPoint(half == "Top" and "TOPLEFT" or "BOTTOMLEFT", source,
                half == "Top" and "TOPRIGHT" or "BOTTOMRIGHT", offset, 0)
            strip:Show()
        end
    end
    for i = used + 1, #frameExtensions do frameExtensions[i]:Hide() end
end

PositionTabs = function()
    if not customTab or not PlayerTalentFrameTab3 or not PlayerTalentFrameTab4 then return end
    if layoutBusy then return end
    if InCombatLockdown and InCombatLockdown() then ScheduleTalentLayout(true); return end
    if not Active() or PlayerTalentFrame.pet or PlayerTalentFrame.inspect then
        DeactivateCustom(false)
        customTab:Hide()
        RestoreTalentLayout()
        return
    end
    layoutBusy = true
    if not nativeLayout then
        nativeLayout = {width=PlayerTalentFrame:GetWidth(),
            scroll=SaveAnchors(PlayerTalentFrameScrollFrame), glyphTab=SaveAnchors(PlayerTalentFrameTab4)}
    end
    if GlyphFrame and not nativeLayout.glyphFrame then nativeLayout.glyphFrame = SaveAnchors(GlyphFrame) end
    customTab:Show()
    -- Native TabResize's fourth argument is MAX text width, not minimum width.
    -- Reset old ellipsis constraints before measuring; retain the stock 20px
    -- end caps and -15px overlap, and never change font size or global UI scale.
    local rowWidth, shown = 0, 0
    for _, tab in ipairs({PlayerTalentFrameTab1, PlayerTalentFrameTab2,
            PlayerTalentFrameTab3, customTab, PlayerTalentFrameTab4}) do
        if tab and tab:IsShown() then
            tab:GetFontString():SetWidth(0)
            PanelTemplates_TabResize(tab, 0)
            rowWidth, shown = rowWidth + tab:GetWidth(), shown + 1
        end
    end
    rowWidth = rowWidth - math.max(0, shown - 1) * 15
    -- Native tab origin is x=15; the visible frame ends 36px before its right
    -- edge. Increase only the missing width. Recompute after native refreshes.
    local extra = math.max(0, math.ceil(rowWidth + 51 - nativeLayout.width))
    local hasNativeArt = PlayerTalentFrameTopLeft and PlayerTalentFrameBottomLeft
    if not hasNativeArt then extra = 0 end
    local width = nativeLayout.width + extra
    local changed = PlayerTalentFrame:GetWidth() ~= width
    PlayerTalentFrame:SetWidth(width)
    LayoutFourthSurface()
    if hasNativeArt then ExtendTalentBorder(extra) end
    RestoreAnchors(PlayerTalentFrameScrollFrame, nativeLayout.scroll)
    LayoutNativeSurface(extra)
    if nativeLayout.glyphFrame then
        RestoreAnchors(GlyphFrame, nativeLayout.glyphFrame)
        for _, point in ipairs(nativeLayout.glyphFrame) do
            if point[1] == "TOPLEFT" then
                GlyphFrame:SetPoint(point[1], point[2], point[3], point[4] + extra / 2, point[5])
            end
        end
    end
    customTab:ClearAllPoints()
    customTab:SetPoint("LEFT", PlayerTalentFrameTab3, "RIGHT", -15, 0)
    PlayerTalentFrameTab4:ClearAllPoints()
    PlayerTalentFrameTab4:SetPoint("LEFT", customTab, "RIGHT", -15, 0)
    SelectCustomTab(customActive)
    layoutBusy = false
    if changed then ScheduleTalentLayout(false) end
end

local function BuildIntegratedPane()
    customPane = CreateFrame("Frame", "ProjectRebirthFourthSpecPane", PlayerTalentFrame)
    customPane:SetPoint("TOPLEFT", PlayerTalentFrame, "TOPLEFT", 16, -78)
    customPane:SetPoint("BOTTOMRIGHT", PlayerTalentFrame, "BOTTOMRIGHT", -37, 82)
    customPane:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background", tile=true, tileSize=16})
    customPane:SetBackdropColor(0.025, 0.035, 0.09, 0.96)
    customHeader = Text(customPane, "GameFontNormalSmall")
    customHeader:SetPoint("TOPLEFT", customPane, "TOPLEFT", 8, -7)
    customHeader:SetWidth(270)
    customHeader:Hide()
    customScroll = CreateFrame("ScrollFrame", "ProjectRebirthFourthSpecScrollFrame", customPane, "UIPanelScrollFrameTemplate")
    customScroll:SetPoint("TOPLEFT", PlayerTalentFrame, "TOPLEFT", 23, -77)
    customScroll:SetPoint("BOTTOMRIGHT", PlayerTalentFramePointsBar, "TOPRIGHT", -29, 0)
    -- UIPanelScrollFrameTemplate supplies buttons/slider but NOT the Talent
    -- panel's PaperDoll trim. These are its exact native sizes and atlas UVs.
    local trimTop = customScroll:CreateTexture("ProjectRebirthFourthScrollTrimTop", "ARTWORK")
    trimTop:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-ScrollBar")
    trimTop:SetSize(31, 256)
    trimTop:SetPoint("TOPLEFT", customScroll, "TOPRIGHT", -2, 5)
    trimTop:SetTexCoord(0, 0.484375, 0, 1)
    local trimBottom = customScroll:CreateTexture("ProjectRebirthFourthScrollTrimBottom", "ARTWORK")
    trimBottom:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-ScrollBar")
    trimBottom:SetSize(31, 106)
    trimBottom:SetPoint("BOTTOMLEFT", customScroll, "BOTTOMRIGHT", -2, -2)
    trimBottom:SetTexCoord(0.515625, 1, 0, 0.4140625)
    customCanvas = CreateFrame("Frame", "ProjectRebirthFourthSpecScrollChild", customScroll)
    customScroll:SetScrollChild(customCanvas)
    customGrid = CreateFrame("Frame", "ProjectRebirthFourthSpecTalentGrid", customCanvas)
    BuildTreeCanvas()
    customStatus = Text(customPane, "GameFontNormalSmall")
    customStatus:SetPoint("TOPLEFT", customPane, "TOPLEFT", 8, 22)
    customStatus:SetWidth(275)
    customStatus:SetHeight(22)
    customStatus:SetJustifyV("BOTTOM")
    customPane:Hide()
end

local function Integrate()
    if integrated then
        PositionTabs()
        return true
    end
    if not Active() or not PlayerTalentFrame then return false end
    tree = ClassTree()
    if not tree then return false end
    customTab = CreateFrame("Button", "ProjectRebirthFourthTalentTab", PlayerTalentFrame, "CharacterFrameTabButtonTemplate")
    customTab:SetText(tree.name)
    customTab:SetID(5)
    if PanelTemplates_TabResize then PanelTemplates_TabResize(customTab, 0) end
    -- Replace CharacterFrame's inherited OnShow bounds checker: it belongs to
    -- the Character window, not this five-tab talent row.
    customTab:SetScript("OnShow", PositionTabs)
    SelectCustomTab(false)
    customTab:SetScript("OnClick", function()
        customActive = true
        ApplyCustomView()
        RequestState()
    end)
    customTab:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(tree.name, 0.55, 0.85, 1)
        GameTooltip:AddLine(tree.authored and (tree.name .. " Talents") or "Coming soon", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    customTab:SetScript("OnLeave", function() GameTooltip:Hide() end)
    PositionTabs()
    BuildIntegratedPane()
    for i = 1, 4 do
        local nativeTab = _G["PlayerTalentFrameTab" .. i]
        if nativeTab and nativeTab.GetScript and nativeTab.SetScript then
            local nativeClick = nativeTab:GetScript("OnClick")
            nativeTab:SetScript("OnClick", function(...)
                DeactivateCustom(false)
                if nativeClick then nativeClick(...) end
            end)
        end
    end
    if PlayerTalentFrame.HookScript then
        PlayerTalentFrame:HookScript("OnHide", function()
            DeactivateCustom(false)
            RestoreTalentLayout()
        end)
        PlayerTalentFrame:HookScript("OnShow", PositionTabs)
    end
    if hooksecurefunc and PlayerTalentFrame_Refresh then
        hooksecurefunc("PlayerTalentFrame_Refresh", function()
            PositionTabs()
            if customActive and not refreshing then ApplyCustomView() end
        end)
    end
    if hooksecurefunc and PlayerTalentFrame_UpdateTabs then
        hooksecurefunc("PlayerTalentFrame_UpdateTabs", PositionTabs)
    end
    integrated = true
    RequestState()
    return true
end

Render = function()
    if not customActive or not customPane or not tree then return end
    local status = snapshot and snapshot.status or "waiting"
    local level = snapshot and snapshot.level or (UnitLevel("player") or 1)
    local native = snapshot and snapshot.nativeSpent or 0
    local fourth = snapshot and snapshot.fourthSpent or 0
    local budget = snapshot and snapshot.budget or 0
    customHeader:SetText(string.format("|cff88ddff%s|r  |cffffb040Server-owned|r  Level %d", tree.name, level))
    customStatus:SetText(status == "waiting" and "Loading talents..." or "Talents are currently unavailable.")
    customStatus:SetTextColor(1, 0.82, 0)
    if status ~= "ready" then customStatus:Show() else customStatus:Hide() end
    if PlayerTalentFrameSpentPointsText then
        PlayerTalentFrameSpentPointsText:SetText(tree.name .. " Talents: |cffffffff" .. fourth .. "|r")
    end
    if PlayerTalentFrameTalentPointsText then
        PlayerTalentFrameTalentPointsText:SetText("Unspent Talents: |cffffffff" .. math.max(0, budget - native - fourth) .. "|r")
    end
    for _, node in ipairs(tree.nodes) do
        local button, rank = buttons[node.key], Rank(node.key)
        ProjectRebirthCompletion.Talent(button, rank, node.maxRank, node.talentId)
        local eligible = status == "ready" and snapshot.writable and
            fourth >= node.requiredPoints and Rank(node.prerequisite) >= node.prerequisiteRank
        local available = eligible and rank < node.maxRank and budget > native + fourth
        local lit = rank > 0 or available
        button.rank:SetText(tostring(rank))
        button.icon:SetDesaturated(not lit)
        local r, g, b = 0.5, 0.5, 0.5
        if rank == node.maxRank then r, g, b = 1, 0.82, 0
        elseif lit then r, g, b = 0.1, 1, 0.1 end
        button.slot:SetVertexColor(r, g, b)
        button.rank:SetTextColor(r, g, b)
        if lit then button.rank:Show(); button.rankBorder:Show()
        else button.rank:Hide(); button.rankBorder:Hide() end
    end
    for _, link in ipairs(lines) do
        local unlocked = Rank(link.node.prerequisite) >= link.node.prerequisiteRank
        if link.arrow then
            link.texture:SetTexCoord(0, 0.5, unlocked and 0 or 0.5, unlocked and 0.5 or 1)
        elseif link.branch then
            link.texture:SetTexCoord(0, 0.125, unlocked and 0 or 0.515625, unlocked and 0.484375 or 1)
        else
            link.texture:SetVertexColor(unlocked and 1 or 0.45, unlocked and 0.82 or 0.45, unlocked and 0 or 0.45)
        end
    end
    -- Refresh the owned tooltip in the same render as the confirmed rank and
    -- point counter. Never reopen a dismissed tooltip or steal a native one.
    if selected and hoveredButton and GameTooltip:IsShown() and GameTooltip:IsOwned(hoveredButton) then
        Tooltip(selected, hoveredButton)
    end
end

local function EnsureTalentFrame()
    if not PlayerTalentFrame and UIParentLoadAddOn then UIParentLoadAddOn("Blizzard_TalentUI") end
    return PlayerTalentFrame and Integrate()
end

local function Open(command)
    if not Active() then return end
    if not EnsureTalentFrame() then Say("The original Talent window could not be loaded."); return end
    if command == "reset" then
        if snapshot and not awaiting then
            awaiting = true
            SendRequest("FOURTH_RESET\t" .. snapshot.rowVersion)
        else RequestState() end
        return
    end
    if ShowUIPanel then ShowUIPanel(PlayerTalentFrame) else PlayerTalentFrame:Show() end
    customActive = true
    ApplyCustomView()
    RequestState()
end

local function Split(message)
    local fields = {}
    for value in string.gmatch(message .. "\t", "([^\t]*)\t") do fields[#fields + 1] = value end
    return fields
end

local function IsLocalPlayerSender(sender)
    local player = UnitName("player")
    if not player or not sender then return false end
    return sender == player or string.match(sender, "^[^-]+") == player
end

local notices = {
    stale="Your talents have changed. Please try again.",
    invalid_build="Not enough talent points, or a required talent is missing.",
    unknown_node="That talent is unavailable.", invalid_rank="That rank is unavailable.",
    schema_unavailable="Talents are currently unavailable.",
    persistence_failed="Unable to learn that talent. Please try again.", catalog_mismatch="Please update your game before changing talents."
}

local function Receive(message)
    local fields = Split(message)
    if fields[1] ~= PROTOCOL then return end
    local kind = fields[2]
    if kind == "FOURTH_BEGIN" and #fields == 15 then
        incoming = {
            status=fields[3], profile=tonumber(fields[4]), rowVersion=tonumber(fields[5]),
            classId=tonumber(fields[6]), revision=tonumber(fields[7]), level=tonumber(fields[8]),
            budget=tonumber(fields[9]), nativeSpent=tonumber(fields[10]), fourthSpent=tonumber(fields[11]),
            count=tonumber(fields[12]), writable=fields[13] == "1", authored=fields[14] == "1",
            treeKey=fields[15], ranks={}
        }
    elseif kind == "FOURTH_RANK" and #fields == 4 and incoming then
        local rank = tonumber(fields[4])
        if NodeByKey(fields[3]) and rank and rank >= 1 and rank <= 5 then incoming.ranks[fields[3]] = rank end
    elseif kind == "FOURTH_END" and #fields == 3 and incoming then
        local count = 0
        for _ in pairs(incoming.ranks) do count = count + 1 end
        if tonumber(fields[3]) == incoming.rowVersion and incoming.profile == Profile() and
            tree and incoming.classId == tree.classId and incoming.treeKey == tree.key and
            incoming.revision == tree.revision and count == incoming.count then
            snapshot = incoming
        else
            Say("Unable to update your talents. Please try again.")
        end
        incoming, awaiting = nil, false
        if Render then Render() end
    elseif kind == "FOURTH_NOTICE" and #fields == 3 then
        -- Success is silent. Keep the click guard until its complete snapshot
        -- arrives, so a second click cannot reuse the preceding row version.
        if notices[fields[3]] then Say(notices[fields[3]]) end
    end
end

SLASH_REBIRTHFOURTHSPEC1 = "/rspec"
SLASH_REBIRTHFOURTHSPEC2 = "/rfourth"
SlashCmdList.REBIRTHFOURTHSPEC = Open

local events = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_LOGIN", "ADDON_LOADED", "ACTIVE_TALENT_GROUP_CHANGED",
    "CHARACTER_POINTS_CHANGED", "PLAYER_LEVEL_UP", "CHAT_MSG_ADDON"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent", function(_, event, ...)
    if event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        if Active() and prefix == PREFIX and channel == "WHISPER" and IsLocalPlayerSender(sender) then Receive(message) end
        return
    end
    if not Active() then
        snapshot, incoming, awaiting = nil, nil, false
        DeactivateCustom(false)
        if customPane then customPane:Hide() end
        if customTab then customTab:Hide() end
        RestoreTalentLayout()
        return
    end
    if event == "ADDON_LOADED" then
        local name = ...
        if name ~= "Blizzard_TalentUI" and name ~= "ProjectRebirthTooltips" then return end
    end
    tree = ClassTree()
    if PlayerTalentFrame then Integrate() end
    if event == "ACTIVE_TALENT_GROUP_CHANGED" then snapshot, incoming, awaiting = nil, nil, false end
    RequestState()
    if customActive then ApplyCustomView() end
end)
