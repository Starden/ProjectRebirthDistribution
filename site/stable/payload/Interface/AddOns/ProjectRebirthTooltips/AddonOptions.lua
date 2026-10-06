-- Rebirth's Esc-menu addon controls. Native addon enable flags only; no addon loading,
-- downloaded code, saved-variable deletion or gameplay commands. Reload is an explicit click.
ProjectRebirthAddonOptions = {}
local A = ProjectRebirthAddonOptions
local HOST = "ProjectRebirthTooltips"
local ROW_HEIGHT, VISIBLE_ROWS = 32, 8
local baseline, pending = {}, {}

local function Active() return GetRealmName and GetRealmName() == "Rebirth" end
local function InCombat() return InCombatLockdown and InCombatLockdown() end
local function Enabled(value) return value == true or value == 1 end
local function Builtin(name) return string.sub(name, 1, 9) == "Blizzard_" end

local function Button(parent, text, width, point, relative, x, y, action)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetWidth(width); button:SetHeight(24)
    button:SetPoint(point, relative, point, x, y); button:SetText(text)
    button:SetScript("OnClick", action)
    return button
end

local function Snapshot()
    local list, byName = {}, {}
    for index = 1, GetNumAddOns() do
        local name, title, notes, enabled, loadable, reason = GetAddOnInfo(index)
        if type(name) == "string" then
            local row = {index = index, name = name, title = title or name, notes = notes,
                enabled = Enabled(enabled), loadable = Enabled(loadable), reason = reason,
                loaded = IsAddOnLoaded(name) and true or false}
            list[#list + 1], byName[name] = row, row
            if baseline[name] == nil then baseline[name] = row.enabled end
        end
    end
    return list, byName
end

-- Resolve hard dependencies before any changes. Reject missing dependencies and cycles
-- without leaving a partly enabled tree. Native LoadOnDemand behavior remains untouched.
local function EnableOrder(name, byName, visiting, seen, order)
    if seen[name] then return true end
    if visiting[name] or not byName[name] then return false end
    visiting[name] = true
    for _, dependency in ipairs({GetAddOnDependencies(byName[name].index)}) do
        if not EnableOrder(dependency, byName, visiting, seen, order) then return false end
    end
    visiting[name], seen[name] = nil, true
    order[#order + 1] = byName[name]
    return true
end

function A.SetEnabled(name, value)
    if not Active() or InCombat() or type(name) ~= "string" or Builtin(name) then return false end
    local _, byName = Snapshot()
    local row = byName[name]
    if not row then return false end
    if value then
        local order = {}
        if not EnableOrder(name, byName, {}, {}, order) then
            A.Refresh()
            if A.frame then A.frame.message:SetText("Cannot enable: a required addon is missing or has a dependency cycle.") end
            return false
        end
        for _, dependency in ipairs(order) do
            if not dependency.enabled then EnableAddOn(dependency.index); pending[dependency.name] = true end
        end
    elseif row.enabled then
        DisableAddOn(row.index); pending[name] = true
    end
    A.Refresh()
    return true
end

function A.Undo()
    if not Active() or InCombat() then return end
    local _, byName = Snapshot()
    for name in pairs(pending) do
        local row = byName[name]
        if row and baseline[name] ~= nil then
            if baseline[name] then EnableAddOn(row.index) else DisableAddOn(row.index) end
        end
    end
    pending = {}
    A.Refresh()
end

function A.Reload()
    if not Active() or InCombat() then return false end
    ReloadUI()
    return true
end

function A.Refresh()
    local f = A.frame
    if not f then return end
    local list, byName = Snapshot()
    for name in pairs(pending) do
        if byName[name] and byName[name].enabled == baseline[name] then pending[name] = nil end
    end
    local search, matches = string.lower(f.search:GetText() or ""), {}
    for _, row in ipairs(list) do
        if not Builtin(row.name) and (search == "" or string.find(string.lower(row.title .. " " .. row.name), search, 1, true)) then
            matches[#matches + 1] = row
        end
    end
    table.sort(matches, function(left, right) return string.lower(left.title) < string.lower(right.title) end)
    FauxScrollFrame_Update(f.scroll, #matches, VISIBLE_ROWS, ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(f.scroll)
    for i, widget in ipairs(f.rows) do
        local row = matches[offset + i]
        if row then
            widget.addonName = row.name
            widget:SetChecked(row.enabled)
            widget.label:SetText(row.title)
            local status = row.loaded and "Loaded" or "Not loaded"
            if pending[row.name] then status = "Reload to apply" end
            if not row.enabled then status = row.loaded and "Disable on reload" or "Disabled" end
            if row.enabled then
                for _, dependency in ipairs({GetAddOnDependencies(row.index)}) do
                    if not byName[dependency] or not byName[dependency].enabled then
                        status = "Requires " .. dependency; break
                    end
                end
            end
            if row.enabled and not row.loadable and row.reason and row.reason ~= "DISABLED" then
                status = _G["ADDON_" .. row.reason] or row.reason
            end
            widget.status:SetText(status)
            if InCombat() then widget:Disable() else widget:Enable() end
            widget:Show()
        else widget.addonName = nil; widget:Hide() end
    end
    local changed = next(pending) ~= nil
    if changed and not InCombat() then f.reload:Enable(); f.undo:Enable() else f.reload:Disable(); f.undo:Disable() end
    f.count:SetText(string.format("%d addons", #matches))
    if InCombat() then
        f.message:SetText("Finish combat before changing addons or reloading.")
    elseif byName[HOST] and not byName[HOST].enabled then
        f.message:SetText("This menu closes after reload. Re-enable Project Reverie from AddOns at character selection.")
    else f.message:SetText("Changes apply after Reload UI. Built-in game interface addons are kept enabled.") end
end

function A.Open()
    if not Active() then return end
    if not A.frame then
        local f = CreateFrame("Frame", "ProjectRebirthAddonOptionsFrame", UIParent)
        A.frame = f
        f:SetWidth(465); f:SetHeight(445); f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        f:SetFrameStrata("DIALOG"); f:SetToplevel(true); f:EnableMouse(true)
        f:SetMovable(true); f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f:SetBackdrop({bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32,
            edgeSize = 32, insets = {left = 11, right = 12, top = 12, bottom = 11}})
        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", f, "TOP", 0, -23); title:SetText("AddOns")
        f.search = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        f.search:SetWidth(280); f.search:SetHeight(22); f.search:SetAutoFocus(false)
        f.search:SetPoint("TOPLEFT", f, "TOPLEFT", 30, -57)
        f.search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        f.search:SetScript("OnTextChanged", function() if f.scroll then f.scroll.offset = 0; A.Refresh() end end)
        local searchLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        searchLabel:SetPoint("LEFT", f.search, "RIGHT", 10, 0); searchLabel:SetText("Search addons")
        f.scroll = CreateFrame("ScrollFrame", "ProjectRebirthAddonOptionsScroll", f, "FauxScrollFrameTemplate")
        f.scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 24, -90)
        f.scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -43, 94)
        f.scroll:SetScript("OnVerticalScroll", function(self, value)
            FauxScrollFrame_OnVerticalScroll(self, value, ROW_HEIGHT, A.Refresh)
        end)
        f.rows = {}
        for i = 1, VISIBLE_ROWS do
            local row = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
            row:SetWidth(26); row:SetHeight(26); row:SetPoint("TOPLEFT", f, "TOPLEFT", 24, -91 - (i - 1) * ROW_HEIGHT)
            row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.label:SetWidth(225); row.label:SetJustifyH("LEFT"); row.label:SetPoint("LEFT", row, "RIGHT", 4, 3)
            row.status = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.status:SetWidth(148); row.status:SetJustifyH("RIGHT"); row.status:SetPoint("LEFT", row.label, "RIGHT", 0, 0)
            row:SetScript("OnClick", function(self) A.SetEnabled(self.addonName, Enabled(self:GetChecked())) end)
            f.rows[i] = row
        end
        f.count = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.count:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 28, 81)
        f.message = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f.message:SetWidth(405); f.message:SetJustifyH("LEFT")
        f.message:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 28, 51)
        f.reload = Button(f, "Reload UI", 112, "BOTTOMLEFT", f, 25, 19, A.Reload)
        f.undo = Button(f, "Undo changes", 124, "BOTTOMLEFT", f, 145, 19, A.Undo)
        Button(f, "Close", 90, "BOTTOMRIGHT", f, -25, 19, function() f:Hide() end)
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4); close:SetScript("OnClick", function() f:Hide() end)
        f:SetScript("OnShow", A.Refresh)
        table.insert(UISpecialFrames, f:GetName())
    end
    A.Refresh(); A.frame:Show()
end

local function ArrangeMenu()
    if not GameMenuFrame or not GameMenuButtonQuit or not GameMenuButtonContinue then return end
    if not A.menuButton then
        A.menuButton = CreateFrame("Button", "ProjectRebirthGameMenuAddOns", GameMenuFrame, "GameMenuButtonTemplate")
        A.menuButton:SetWidth(140); A.menuButton:SetHeight(20); A.menuButton:SetText("AddOns")
        A.menuButton:SetScript("OnClick", function() HideUIPanel(GameMenuFrame); A.Open() end)
    end
    if Active() then
        A.menuButton:SetPoint("TOP", GameMenuButtonQuit, "BOTTOM", 0, -1); A.menuButton:Show()
        GameMenuButtonContinue:ClearAllPoints()
        GameMenuButtonContinue:SetPoint("TOP", A.menuButton, "BOTTOM", 0, -16)
        if not A.expanded then
            A.baseHeight = GameMenuFrame:GetHeight()
            GameMenuFrame:SetHeight(A.baseHeight + 21); A.expanded = true
        end
    else
        A.menuButton:Hide()
        if A.expanded then
            GameMenuButtonContinue:ClearAllPoints()
            GameMenuButtonContinue:SetPoint("TOP", GameMenuButtonQuit, "BOTTOM", 0, -16)
            GameMenuFrame:SetHeight(A.baseHeight); A.expanded = false
        end
        if A.frame then A.frame:Hide() end
    end
end

A.driver = CreateFrame("Frame")
A.driver:RegisterEvent("PLAYER_LOGIN"); A.driver:RegisterEvent("PLAYER_ENTERING_WORLD")
A.driver:RegisterEvent("PLAYER_REGEN_DISABLED"); A.driver:RegisterEvent("PLAYER_REGEN_ENABLED")
A.driver:SetScript("OnEvent", function(self, event)
    if GameMenuFrame and not A.menuHooked then
        GameMenuFrame:HookScript("OnShow", ArrangeMenu); A.menuHooked = true
    end
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then ArrangeMenu() end
    if A.frame and A.frame:IsShown() then A.Refresh() end
end)
