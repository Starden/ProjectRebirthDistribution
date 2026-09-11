-- Presentation only. XP, ranks, thresholds and ownership come from the server.
-- Save only per-character display preferences, never progression state.
ProjectRebirthProgress = {}
local P = ProjectRebirthProgress
local rebirth, heritage, lifeWidget, heritageWidget, tracking, hud, lockButton
local active = false
local UINT64_MAX = "18446744073709551615"

local function Unsigned(s)
    return type(s) == "string" and (s == "0" or s:match("^[1-9]%d*$")) and
        (#s < 20 or (#s == 20 and s <= UINT64_MAX))
end

local function Compare(a, b)
    if #a ~= #b then return #a < #b and -1 or 1 end
    if a == b then return 0 end
    return a < b and -1 or 1
end

local function Add(a, b)
    local result, carry, i, j = "", 0, #a, #b
    while i > 0 or j > 0 or carry > 0 do
        local sum = (i > 0 and tonumber(a:sub(i, i)) or 0) +
            (j > 0 and tonumber(b:sub(j, j)) or 0) + carry
        result = tostring(sum % 10) .. result
        carry = math.floor(sum / 10)
        i, j = i - 1, j - 1
    end
    return result
end

function P.Format(value)
    local s = tostring(value or "0")
    if not Unsigned(s) then return "—" end
    return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

-- Full, self-contained records. Keep uint64 values as decimal strings; Lua 5.1
-- doubles cannot represent every XP total. Floating point is used only for fill.
function P.Parse(fields)
    if fields[1] ~= "3" then return nil end
    local isHeritage = fields[2] == "HERITAGE_PROGRESS"
    if not isHeritage and fields[2] ~= "REBIRTH_PROGRESS" then return nil end
    if #fields ~= (isHeritage and 11 or 9) then return nil end
    local offset = isHeritage and 1 or 0
    for i = 3, 8 + offset do
        if not Unsigned(fields[i]) then return nil end
    end
    if fields[3] == "0" or tonumber(fields[4]) > 65535 then return nil end
    local capped = fields[9 + offset]
    if capped ~= "0" and capped ~= "1" then return nil end
    local p = { id = fields[3], level = tonumber(fields[4]), total = fields[5 + offset],
        earned = fields[6 + offset], needed = fields[7 + offset], remaining = fields[8 + offset],
        capped = capped == "1" }
    if Compare(p.total, p.earned) < 0 then return nil end
    if p.capped then
        if p.needed ~= "0" or p.remaining ~= "0" then return nil end
    elseif p.needed == "0" or p.remaining == "0" or Add(p.earned, p.remaining) ~= p.needed then
        return nil
    end
    if isHeritage then
        p.maximum = tonumber(fields[5])
        if p.level < 1 or p.maximum < p.level or p.maximum > 65535 or
            p.capped ~= (p.level == p.maximum) then return nil end
        p.name = fields[11]:gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex,16)) end)
        -- Server names are plain text, not hyperlinks or UI markup.
        p.name = p.name:gsub("|", "||"):gsub("[%c]", " ")
        if p.name == "" then return nil end
    end
    p.fraction = p.capped and 1 or math.min(1, tonumber(p.earned) / tonumber(p.needed))
    return p
end

local function Settings()
    if type(ProjectRebirthProgressSettings) ~= "table" then ProjectRebirthProgressSettings = {} end
    return ProjectRebirthProgressSettings
end

local function Bounded(value, fallback, low, high)
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
        value = fallback
    end
    return math.max(low, math.min(high, value))
end

local function LayoutHUD()
    if not hud or hud.adjusting then return end
    local s = Settings()
    local w, h = math.max(1, UIParent:GetWidth()), math.max(1, UIParent:GetHeight())
    local width = Bounded(s.width, 420, math.min(180, w), math.min(1200, w))
    local height = Bounded(s.height, 20, math.min(14, h), math.min(64, h))
    local x = Bounded(s.x, 0.5, width / (2*w), 1 - width / (2*w))
    local y = Bounded(s.y, 0.22, height / (2*h), 1 - height / (2*h))
    hud:SetWidth(width)
    hud:SetHeight(height)
    hud:SetMinResize(math.min(180, w), math.min(14, h))
    hud:SetMaxResize(math.min(1200, w), math.min(64, h))
    hud:ClearAllPoints()
    hud:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x*w, y*h)
end

local function SaveHUD()
    if not hud or not hud.adjusting then return end
    hud:StopMovingOrSizing()
    hud.adjusting = false
    local s = Settings()
    local x, y = hud:GetCenter()
    s.width, s.height = hud:GetWidth(), hud:GetHeight()
    if x and y then s.x, s.y = x / UIParent:GetWidth(), y / UIParent:GetHeight() end
    LayoutHUD()
end

function P.SetLocked(locked)
    SaveHUD()
    Settings().locked = locked ~= false
    if lockButton then lockButton:SetText(Settings().locked and "Unlock XP bar" or "Lock XP bar") end
    if hud then
        if Settings().locked then hud.grip:Hide() else hud.grip:Show() end
    end
end

function P.ResetHUD()
    SaveHUD()
    local s = Settings()
    s.width, s.height, s.x, s.y = nil, nil, nil, nil
    LayoutHUD()
    P.SetLocked(false)
end

local function Bar(parent, name, height)
    local bar = CreateFrame("StatusBar", name, parent)
    bar:SetHeight(height)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0.35, 0.55, 0.95)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    bg:SetTexture(0.025, 0.035, 0.065, 0.95)
    local edge = CreateFrame("Frame", nil, bar)
    edge:SetPoint("TOPLEFT", bar, "TOPLEFT", -3, 3)
    edge:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 3, -3)
    edge:SetBackdrop({edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize=8})
    edge:SetBackdropBorderColor(0.6, 0.65, 0.8, 1)
    bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.text:SetPoint("CENTER", bar, "CENTER", 0, 0)
    return bar
end

local function ProgressText(p, unit)
    if p.capped then return "Maximum " .. unit .. " reached" end
    return P.Format(p.earned) .. " / " .. P.Format(p.needed) .. "  (" ..
        string.format("%.1f", p.fraction * 100) .. "%)"
end

local function Fill(widget, p, title, unit)
    widget.bar:SetValue(p and p.fraction or 0)
    widget.title:SetText(p and title or "Progress unavailable")
    local text = p and ProgressText(p, unit) or "Waiting for server"
    if p and #text > 45 then text = string.format("%.1f%% to next %s", p.fraction * 100, unit) end
    widget.bar.text:SetText(text)
    widget.detail:SetText(p and ("Total: " .. P.Format(p.total) ..
        (p.capped and "" or ("\n" .. P.Format(p.remaining) .. " to " .. unit .. " " .. (p.level + 1)))) or
        "Refresh to request current progression.")
end

function P.UpdateHUD()
    if not hud then return end
    if not active or not heritage or Settings().trackHeritage ~= true then
        hud:Hide()
        return
    end
    hud:SetValue(heritage.fraction)
    hud.text:SetText(heritage.name .. " — Rank " .. heritage.level .. "  •  " .. ProgressText(heritage, "rank"))
    hud:Show()
end

local function Render()
    if lifeWidget then
        Fill(lifeWidget, rebirth, rebirth and ("Rebirth Level |cffffffff" .. rebirth.level .. "|r"), "level")
    end
    if heritageWidget then
        Fill(heritageWidget, heritage, heritage and
            ("Tracked Heritage: " .. heritage.name .. " — " .. heritage.level .. "/" .. heritage.maximum), "rank")
    end
    if tracking then tracking:SetChecked(Settings().trackHeritage == true) end
    P.UpdateHUD()
end

function P.Receive(fields)
    local parsed = P.Parse(fields)
    if fields[2] == "REBIRTH_PROGRESS" then rebirth = parsed
    elseif fields[2] == "HERITAGE_PROGRESS" then heritage = parsed
    else return end
    Render()
    return parsed
end

function P.NextThreshold(p)
    return p.capped and "0" or Add(p.total, p.remaining)
end

function P.Clear(kind)
    if kind == "rebirth" then rebirth = nil else heritage = nil end
    Render()
end

local function Widget(parent, name)
    local w = CreateFrame("Frame", name, parent)
    w:SetHeight(102)
    w.title = w:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    w.title:SetPoint("TOPLEFT", w, "TOPLEFT", 0, 0)
    w.title:SetPoint("RIGHT", w, "RIGHT", 0, 0)
    w.title:SetJustifyH("LEFT")
    w.bar = Bar(w, nil, 16)
    w.bar:SetPoint("TOPLEFT", w, "TOPLEFT", 0, -28)
    w.bar:SetPoint("RIGHT", w, "RIGHT", 0, 0)
    w.detail = w:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    w.detail:SetPoint("TOPLEFT", w.bar, "BOTTOMLEFT", 0, -8)
    w.detail:SetPoint("RIGHT", w, "RIGHT", 0, 0)
    w.detail:SetJustifyH("LEFT")
    return w
end

function P.CreateRebirth(parent)
    if lifeWidget then return end
    lifeWidget = Widget(parent, "ProjectRebirthRxpProgress")
    lifeWidget:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, -296)
    lifeWidget:SetPoint("RIGHT", parent, "RIGHT", -24, 0)
    Render()
end

function P.CreateHeritage(parent)
    if heritageWidget then return end
    heritageWidget = Widget(parent, "ProjectRebirthHeritageProgress")
    heritageWidget:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 14, 112)
    heritageWidget:SetPoint("RIGHT", parent, "RIGHT", -14, 0)
    tracking = CreateFrame("CheckButton", "ProjectRebirthTrackHeritageXP", parent, "UICheckButtonTemplate")
    tracking:SetWidth(24)
    tracking:SetHeight(24)
    tracking:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 10, 82)
    local label = tracking:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", tracking, "RIGHT", 2, 0)
    label:SetText("Show independent Heritage XP bar")
    tracking:SetScript("OnClick", function(self)
        Settings().trackHeritage = not not self:GetChecked()
        P.UpdateHUD()
    end)
    tracking:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Track your selected Heritage")
        GameTooltip:AddLine("Unlock to drag the bar or resize it from its bottom-right corner. Lock when finished.", 1, 1, 1, true)
        GameTooltip:AddLine("This preference is saved for this character. Select a Heritage to begin tracking.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    tracking:SetScript("OnLeave", function() GameTooltip:Hide() end)
    lockButton = CreateFrame("Button", "ProjectRebirthHeritageBarLock", parent, "UIPanelButtonTemplate")
    lockButton:SetWidth(118)
    lockButton:SetHeight(20)
    lockButton:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 14, 54)
    lockButton:SetScript("OnClick", function() P.SetLocked(Settings().locked == false) end)
    local reset = CreateFrame("Button", "ProjectRebirthHeritageBarReset", parent, "UIPanelButtonTemplate")
    reset:SetWidth(118)
    reset:SetHeight(20)
    reset:SetPoint("LEFT", lockButton, "RIGHT", 8, 0)
    reset:SetText("Reset XP bar")
    reset:SetScript("OnClick", P.ResetHUD)
    P.SetLocked(Settings().locked ~= false)
    Render()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("DISPLAY_SIZE_CHANGED")
events:RegisterEvent("UI_SCALE_CHANGED")
events:RegisterEvent("PLAYER_LOGOUT")
events:SetScript("OnEvent", function()
    SaveHUD()
    active = GetRealmName and GetRealmName() == "Rebirth"
    if not active then rebirth, heritage = nil, nil end
    if active and not hud then
        hud = Bar(UIParent, "ProjectRebirthHeritageWatchBar", 20)
        hud:SetFrameStrata("MEDIUM")
        hud:SetMovable(true)
        hud:SetResizable(true)
        hud:SetClampedToScreen(true)
        hud:EnableMouse(true)
        hud:RegisterForDrag("LeftButton")
        hud:SetScript("OnDragStart", function(self)
            if Settings().locked == false then self.adjusting = true; self:StartMoving() end
        end)
        hud:SetScript("OnDragStop", SaveHUD)
        hud:SetScript("OnHide", SaveHUD)
        hud:SetScript("OnSizeChanged", function(self)
            self.text:SetWidth(math.max(1, self:GetWidth() - 26))
        end)
        hud.grip = CreateFrame("Button", "ProjectRebirthHeritageBarResize", hud)
        hud.grip:SetWidth(16)
        hud.grip:SetHeight(16)
        hud.grip:SetPoint("BOTTOMRIGHT", hud, "BOTTOMRIGHT", 0, 0)
        local gripTexture = hud.grip:CreateTexture(nil, "OVERLAY")
        gripTexture:SetAllPoints(hud.grip)
        gripTexture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
        hud.grip:SetScript("OnMouseDown", function(_, button)
            if button == "LeftButton" and Settings().locked == false then
                hud.adjusting = true; hud:StartSizing("BOTTOMRIGHT")
            end
        end)
        hud.grip:SetScript("OnMouseUp", SaveHUD)
        hud:SetScript("OnEnter", function(self)
            if not heritage then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(heritage.name .. " — Rank " .. heritage.level .. " / " .. heritage.maximum)
            GameTooltip:AddLine(ProgressText(heritage, "rank"), 1, 1, 1)
            GameTooltip:AddLine("Total Heritage XP: " .. P.Format(heritage.total), 1, 1, 1)
            if not heritage.capped then
                GameTooltip:AddLine(P.Format(heritage.remaining) .. " XP to next rank", 1, 1, 1)
            end
            GameTooltip:AddLine("Move, resize, lock or reset: Rebirth - Heritages", 0.6, 0.8, 1)
            GameTooltip:Show()
        end)
        hud:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    LayoutHUD()
    P.SetLocked(Settings().locked ~= false)
    Render()
end)
