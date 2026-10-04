-- Stock Wrath presentation only. No gameplay formula or committing transport lives here.
-- Spec: docs/design/heritage-panel-v2.md. Missing server data hides a control; it is never
-- reported to the player as a developer message.
ProjectRebirthPanel = {}
local V = ProjectRebirthPanel
local ART = "Interface\\AchievementFrame\\"
local INK = {0.12, 0.07, 0.02}
local INK2 = {0.23, 0.14, 0.05}
local VALUE = {0, 0.36, 0}
local WARN = {0.65, 0.14, 0}
local GOLD = {1, 0.82, 0}
local context
local roman = {"I", "II", "III", "IV", "V"}

-- Heritage roles (owner rulings 2026-10-04). Paragon is retired; Enlightened Human is the
-- Human Bloodline and is never offered as a Life Heritage.
V.RETIRED = {[1101] = true}
V.BLOODLINE = {[1102] = {race = "Human", portrait = "Achievement_Character_Human"}}

-- Human Bloodline milestones, transcribed from the live rows in
-- 2026_09_02_15_rebirth_enlightened_human_heritage.sql and RebirthEnlightenedHuman.h.
-- Used only until the server sends milestones[] itself (spec section 7).
V.HUMAN_MILESTONES = {
    {1, "+0.1% all primary stats, and +0.1% more every rank"},
    {10, "+1% positive reputation gains, and +1% more every 10 ranks"},
    {25, "Every Man for Himself cooldown 110 sec"},
    {50, "Cooldown 100 sec. Every Man for Himself grants 7.5% haste for 40 sec"},
    {75, "Cooldown 90 sec. Haste 11.25%"},
    {100, "Cooldown 80 sec. Haste 15%. +10% primary stats and +10% reputation in total"},
}

local function ShowIf(widget, shown) if shown then widget:Show() else widget:Hide() end end

local function Pin(widget, parent, x, y, width, height)
    widget:ClearAllPoints()
    widget:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    if width then widget:SetWidth(width) end
    if height then widget:SetHeight(height) end
end

local function Text(parent, text, x, y, width, font, color)
    local value = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    Pin(value, parent, x, y, width)
    value:SetJustifyH("LEFT")
    value:SetJustifyV("TOP")
    value:SetTextColor(unpack(color or INK))
    value:SetShadowOffset(0, 0)
    value:SetText(text or "")
    return value
end

local function Texture(parent, asset, x, y, width, height, coords, layer)
    local value = parent:CreateTexture(nil, layer or "BACKGROUND")
    Pin(value, parent, x, y, width, height)
    value:SetTexture(asset)
    if coords then value:SetTexCoord(unpack(coords)) end
    return value
end

local function Category(parent, label, y)
    local bar = CreateFrame("Frame", nil, parent)
    Pin(bar, parent, 0, y, 198, 24)
    Texture(bar, ART .. "UI-Achievement-Category-Background", 0, 0, 198, 24, {0,.6641,0,1})
    bar.label = Text(bar, label, 10, 5, 178, "GameFontNormalSmall", GOLD)
    bar.label:SetShadowOffset(1, -1)
    return bar
end

local function Section(parent, label, y, width)
    local bar = CreateFrame("Frame", nil, parent)
    Pin(bar, parent, 0, y, width, 20)
    Texture(bar, ART .. "UI-Achievement-Title", 0, 0, width, 20, {0,.9766,0,.3125})
    bar.label = Text(bar, label, 0, 4, width, "GameFontNormal", GOLD)
    bar.label:SetJustifyH("CENTER")
    bar.label:SetShadowOffset(1, -1)
    return bar
end

local function Button(parent, label, x, y, width, callback)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    Pin(button, parent, x, y, width, 22)
    button:SetText(label)
    button:SetScript("OnClick", callback)
    return button
end

local function Scroll(parent, name, x, y, width, height)
    local scroll = CreateFrame("ScrollFrame", name, parent, "UIPanelScrollFrameTemplate")
    Pin(scroll, parent, x, y, width - 20, height)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetWidth(width - 24)
    child:SetHeight(1)
    scroll:SetScrollChild(child)
    return scroll, child
end

local function Bar(parent, x, y, width)
    local bar = CreateFrame("StatusBar", nil, parent)
    Pin(bar, parent, x + 4, y + 4, width - 8, 12)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0, .6, 0)
    bar:SetMinMaxValues(0, 1)
    Texture(bar, ART .. "UI-Achievement-ProgressBar-Border", -6, -4, 16, 20, {0,.0625,0,.75}, "OVERLAY")
    Texture(bar, ART .. "UI-Achievement-ProgressBar-Border", 10, -4, width - 28, 20, {.0625,.812,0,.75}, "OVERLAY")
    Texture(bar, ART .. "UI-Achievement-ProgressBar-Border", width - 18, -4, 16, 20, {.812,.8745,0,.75}, "OVERLAY")
    local back = bar:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints(bar)
    back:SetTexture(0, 0, 0, .8)
    bar.label = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.label:SetPoint("CENTER", bar, "CENTER", 0, 0)
    return bar
end

-- A criteria row: stock achievement check when met, a dim bullet otherwise.
local function Criterion(parent, width)
    local row = CreateFrame("Frame", nil, parent)
    row:SetWidth(width)
    row:SetHeight(18)
    row.check = Texture(row, ART .. "UI-Achievement-Criteria-Check", 0, 0, 20, 16, {0,.625,0,1}, "ARTWORK")
    row.dot = Texture(row, "Interface\\Buttons\\WHITE8X8", 7, 6, 5, 5, nil, "ARTWORK")
    row.dot:SetVertexColor(INK2[1], INK2[2], INK2[3], .7)
    row.band = Texture(row, "Interface\\Buttons\\WHITE8X8", -4, -2, width + 4, 18, nil, "BACKGROUND")
    row.band:SetVertexColor(1, .82, 0, .18)
    row.rank = Text(row, "", 24, 2, 64)
    row.text = Text(row, "", 90, 2, width - 160)
    row.note = Text(row, "", width - 72, 2, 72, "GameFontHighlightSmall", WARN)
    row.note:SetJustifyH("RIGHT")
    return row
end

local function SetCriterion(row, met, rank, text, next, note)
    ShowIf(row.check, met == true)
    ShowIf(row.dot, met ~= true)
    ShowIf(row.band, next)
    row.rank:SetText(rank or "")
    row.rank:SetTextColor(unpack(met and VALUE or INK))
    row.text:SetText(text or "")
    row.text:SetTextColor(unpack(met and VALUE or INK2))
    row.note:SetText(note or "")
    if rank then Pin(row.text, row, 90, 2, row:GetWidth() - 160) else Pin(row.text, row, 24, 2, row:GetWidth() - 28) end
    row:SetHeight(math.max(18, row.text:GetStringHeight() + 4))
    row:Show()
end

-- Split one Skill's five rank texts into lines shared by every rank and rows whose
-- value changes per rank. Returns nil when the texts do not line up into a table.
function V.RankTable(texts)
    if #texts < 2 then return nil end
    local split = {}
    for rank, text in ipairs(texts) do
        local lines = {}
        for line in (text .. "\n"):gmatch("([^\n]*)\n") do
            line = line:gsub("^%s+", ""):gsub("%s+$", "")
            if line ~= "" then lines[#lines + 1] = line end
        end
        split[rank] = lines
    end
    for rank = 2, #split do if #split[rank] ~= #split[1] then return nil end end
    local common, rows = {}, {}
    for index, first in ipairs(split[1]) do
        local same = true
        for rank = 2, #split do if split[rank][index] ~= first then same = false end end
        if same then
            common[#common + 1] = first
        else
            local labels, values = {}, {}
            for rank = 1, #split do
                local line = split[rank][index]:gsub("%.$", "")
                local label, value = line:match("^(Rank %d+):%s*(.+)$")
                if label then label = "Value"
                else label, value = line:match("^([^:]+):%s*(.+)$") end
                if not label then return nil end
                labels[rank], values[rank] = label, value
            end
            for rank = 2, #split do if labels[rank] ~= labels[1] then return nil end end
            -- "0.5%; max 3" becomes two rows: the labelled value and "Max".
            local parts = {}
            for rank = 1, #split do
                parts[rank] = {}
                for piece in (values[rank] .. ";"):gmatch("([^;]+);") do
                    parts[rank][#parts[rank] + 1] = piece:gsub("^%s+", ""):gsub("%s+$", "")
                end
                if #parts[rank] ~= #parts[1] then parts = nil; break end
            end
            if not parts then parts = {}; for rank = 1, #split do parts[rank] = {values[rank]} end end
            for part = 1, #parts[1] do
                local row = {label = labels[1], values = {}}
                for rank = 1, #split do
                    local piece = parts[rank][part]:gsub(" percentage points", " pts"):gsub(" percent", "%%")
                    if part > 1 then
                        local word, number = piece:match("^(%a[%a ]-)%s+([%d%.%%]+%S*)$")
                        if word then row.label = word:sub(1,1):upper() .. word:sub(2); piece = number end
                    end
                    row.values[rank] = piece
                end
                rows[#rows + 1] = row
            end
        end
    end
    if #rows == 0 or #rows > 4 then return nil end
    for _, row in ipairs(rows) do
        for _, value in ipairs(row.values) do if #value > 12 then return nil end end
    end
    return {common = common, rows = rows}
end

function V.Attach(c)
    context = c
    c.panel:SetWidth(768)
    c.panel:SetHeight(500)
    c.panel:SetBackdrop({edgeFile=ART .. "UI-Achievement-WoodBorder", edgeSize=64, tileSize=32, tile=true,
        insets={left=16,right=16,top=16,bottom=16}})
    c.panel:SetScript("OnShow", function(self)
        self:SetScale(math.min(1, math.max(.25, (UIParent:GetWidth()-24)/768),
            math.max(.25, (UIParent:GetHeight()-120)/560)))
    end)
    c.backing:SetTexture(.08,.06,.04,1)
    c.interior:Hide()
    c.brand:Hide()
    c.subtitle:Hide()
    if c.panel.refreshButton then c.panel.refreshButton:Hide() end
    -- Carved header, anchored exactly as AchievementFrameHeader: it rises above the frame
    -- and draws over the wood border, so it lives on its own higher frame.
    local header = CreateFrame("Frame", nil, c.panel)
    header:SetFrameLevel(c.panel:GetFrameLevel() + 6)
    header:SetAllPoints(c.panel)
    Texture(header, ART .. "UI-Achievement-Header", 26, -67, 512, 106, {0,1,0,.4141}, "ARTWORK")
    Texture(header, ART .. "UI-Achievement-Header", 538, -61, 215, 100, {0,.4199,.4141,.8047}, "ARTWORK")
    Texture(header, ART .. "UI-Achievement-Header", 343, -16, 133, 39, {.4199,.6797,.4141,.5664}, "OVERLAY")
    c.title:SetParent(header)
    Pin(c.title, header, 259, -38, 250, 16)
    c.title:SetJustifyH("CENTER")
    c.title:SetDrawLayer("OVERLAY")
    c.plaque = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    Pin(c.plaque, header, 343, -2, 133, 14)
    c.plaque:SetJustifyH("CENTER")
    -- Server state is only shown when there is something to say (a notice or error).
    Pin(c.status, c.panel, 24, 470, 720, 14)
    Pin(c.footnote, c.panel, 242, 427, 340, 24)
    c.footnote:Hide()
    for _, tab in ipairs({"skills","heritages","rebirth","glossary"}) do
        local frame = c.tabs[tab]
        Pin(frame, c.panel, 20, 94, 728, 362)
        Texture(frame, ART .. "UI-Achievement-Parchment", 0, 0, 198, 362)
        Texture(frame, ART .. "UI-Achievement-AchievementBackground", 214, 0, 514, 362)
        local mark = Texture(frame, ART .. "UI-Achievement-AchievementWatermark", 466, 106, 256, 256)
        mark:SetAlpha(.25)
        -- Metal frame around the detail well (left/right/top/bottom, as AchievementFrame).
        Texture(frame, ART .. "UI-Achievement-MetalBorder-Left", 206, 0, 16, 362, {0,1,0,.87}, "BORDER")
        Texture(frame, ART .. "UI-Achievement-MetalBorder-Left", 720, 0, 16, 362, {1,0,.87,0}, "BORDER")
        Texture(frame, ART .. "UI-Achievement-MetalBorder-Top", 214, -8, 514, 16, {.87,0,0,1}, "BORDER")
        Texture(frame, ART .. "UI-Achievement-MetalBorder-Top", 214, 354, 514, 16, {0,.87,1,0}, "BORDER")
        frame.left = CreateFrame("Frame", nil, frame)
        Pin(frame.left, frame, 0, 0, 198, 362)
        frame.right = CreateFrame("Frame", nil, frame)
        Pin(frame.right, frame, 214, 0, 514, 362)
        -- Dark action strip along the bottom of the well.
        local strip = Texture(frame.right, "Interface\\Buttons\\WHITE8X8", 6, 320, 502, 38, nil, "BORDER")
        strip:SetVertexColor(0, 0, 0, .35)
    end

    -- Skills ────────────────────────────────────────────────────────────────
    local s = c.tabs.skills
    Category(s.left, "Life slots", 0)
    Pin(c.capacity, s.left, 10, 28, 178, 18)
    c.capacity:SetTextColor(unpack(INK))
    for index, slot in ipairs(c.slots) do
        Pin(slot, s.left, 18 + ((index-1)%3)*56, 50 + math.floor((index-1)/3)*48, 40, 40)
        slot.lock:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-LOCK")
    end
    Category(s.left, "Skill choices", 150)
    Pin(c.pending, s.left, 12, 178, 174, 22)
    Category(s.left, "Library", 208)
    Pin(c.skillCount, s.left, 10, 236, 178, 16)
    c.skillCount:SetTextColor(unpack(INK))
    Pin(c.search, s.left, 18, 254, 160, 20)
    c.searchLabel:Hide()
    Pin(c.skillGrid, s.left, 12, 282, 158, 74)
    c.skillGridChild:SetWidth(156)
    Pin(c.skillWell, s.right, 0, 0, 514, 362)
    c.skillWell:SetBackdrop(nil)
    Pin(c.skillIcon, c.skillWell, 16, 14, 52, 52)
    Texture(c.skillWell, ART .. "UI-Achievement-IconFrame", 10, 8, 64, 64, {0,.5625,0,.5625}, "OVERLAY")
    Pin(c.skillName, c.skillWell, 84, 16, 300, 22)
    Pin(c.skillMeta, c.skillWell, 84, 42, 300, 28)
    c.skillMeta:SetTextColor(unpack(INK2))
    c.skillPlaque = Texture(c.skillWell, ART .. "UI-Achievement-Header", 372, 18, 133, 39, {.4199,.6797,.4141,.5664}, "ARTWORK")
    c.skillRank = Text(c.skillWell, "", 372, 30, 133, "GameFontHighlight", {1,1,1})
    c.skillRank:SetJustifyH("CENTER")
    c.skillXP = Bar(c.skillWell, 14, 80, 486)
    c.skillXPText = Text(c.skillWell, "", 14, 86, 486, "GameFontHighlightSmall", INK2)
    c.skillXPText:SetJustifyH("CENTER")
    c.rankTitle = Section(c.skillWell, "Rank by rank", 108, 500)
    Pin(c.skillScroll, c.skillWell, 10, 134, 494, 180)
    c.skillChild:SetWidth(470)
    c.skillSummary:SetWidth(466)
    c.skillSummary:SetTextColor(unpack(INK))
    c.rankCommon = Text(c.skillChild, "", 4, 0, 462, "GameFontHighlightSmall", INK)
    c.rankBand = Texture(c.skillChild, "Interface\\Buttons\\WHITE8X8", 0, 0, 60, 10, nil, "BACKGROUND")
    c.rankBand:SetVertexColor(0, .36, 0, .16)
    c.rankHead = {}
    for rank = 1, 5 do c.rankHead[rank] = Text(c.skillChild, roman[rank], 0, 0, 58, "GameFontNormal", INK) end
    c.rankLines = {}
    for line = 1, 4 do
        local row = {label = Text(c.skillChild, "", 4, 0, 150, "GameFontHighlightSmall", INK2), cells = {}}
        for rank = 1, 5 do
            row.cells[rank] = Text(c.skillChild, "", 0, 0, 58, "GameFontHighlight", INK)
            row.cells[rank]:SetJustifyH("CENTER")
        end
        c.rankLines[line] = row
    end
    c.rankRows = {}
    for rank = 1, 5 do
        local row = CreateFrame("Frame", nil, c.skillChild)
        row:SetWidth(466)
        row.rank = Text(row, roman[rank], 4, 2, 30, "GameFontNormal", INK)
        row.body = Text(row, "", 40, 2, 420, "GameFontHighlightSmall", INK)
        c.rankRows[rank] = row
    end
    c.skillStatus = Text(c.skillWell, "", 16, 330, 320, "GameFontHighlightSmall", {1,.5,.25})
    c.skillStatus:SetShadowOffset(1, -1)
    Pin(c.inspect, c.skillWell, 360, 328, 140, 22)

    -- Heritages ─────────────────────────────────────────────────────────────
    local h = c.tabs.heritages
    Category(h.left, "Bloodline", 0)
    c.bloodline = CreateFrame("Button", nil, h.left)
    Pin(c.bloodline, h.left, 6, 30, 186, 52)
    c.bloodline:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    c.bloodlineIcon = Texture(c.bloodline, "Interface\\Icons\\INV_Misc_QuestionMark", 6, 6, 34, 34, {.07,.93,.07,.93}, "ARTWORK")
    Texture(c.bloodline, ART .. "UI-Achievement-IconFrame", 2, 2, 42, 42, {0,.5625,0,.5625}, "OVERLAY")
    c.bloodlineSel = Texture(c.bloodline, "Interface\\Buttons\\CheckButtonHilight", 2, 2, 42, 42, nil, "OVERLAY")
    c.bloodlineSel:SetBlendMode("ADD")
    c.bloodlineName = Text(c.bloodline, "", 50, 6, 134, "GameFontNormalSmall", INK)
    c.bloodlineRank = Text(c.bloodline, "", 50, 20, 134, "GameFontHighlightSmall", INK2)
    c.bloodlineBar = CreateFrame("StatusBar", nil, c.bloodline)
    Pin(c.bloodlineBar, c.bloodline, 50, 36, 128, 6)
    c.bloodlineBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    c.bloodlineBar:SetStatusBarColor(0, .6, 0)
    c.bloodlineBar:SetMinMaxValues(0, 1)
    local back = c.bloodlineBar:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints(c.bloodlineBar)
    back:SetTexture(0, 0, 0, .8)
    c.bloodline:SetScript("OnClick", function() if c.bloodlineId then c.selectHeritage(c.bloodlineId) end end)
    c.bloodlineNone = Text(h.left, "Your race's Bloodline has not been revealed yet.", 12, 36, 174, "GameFontHighlightSmall", INK2)
    c.bloodlineBrowse = Button(h.left, "Bloodlines of Azeroth", 12, 88, 174, function() c.openGlossary("bloodlines") end)
    Category(h.left, "Life Heritage", 120)
    Pin(c.heritageCount, h.left, 10, 148, 178, 16)
    c.heritageCount:SetTextColor(unpack(INK2))
    Pin(c.heritageGrid, h.left, 14, 170, 172, 150)
    c.heritageGridChild:SetWidth(170)
    c.heritageLegend = Text(h.left, "Number = your level in it", 12, 330, 174, "GameFontHighlightSmall", INK2)
    Pin(c.heritageWell, h.right, 0, 0, 514, 362)
    c.heritageWell:SetBackdrop(nil)
    Pin(c.heritageIcon, c.heritageWell, 16, 14, 52, 52)
    Texture(c.heritageWell, ART .. "UI-Achievement-IconFrame", 10, 8, 64, 64, {0,.5625,0,.5625}, "OVERLAY")
    Pin(c.heritageName, c.heritageWell, 84, 16, 286, 22)
    Pin(c.heritageMeta, c.heritageWell, 84, 42, 286, 28)
    Texture(c.heritageWell, ART .. "UI-Achievement-Header", 372, 18, 133, 39, {.4199,.6797,.4141,.5664}, "ARTWORK")
    c.heritageRank = Text(c.heritageWell, "", 372, 30, 133, "GameFontHighlight", {1,1,1})
    c.heritageRank:SetJustifyH("CENTER")
    c.heritageRankSub = Text(c.heritageWell, "", 372, 60, 133, "GameFontHighlightSmall", INK2)
    c.heritageRankSub:SetJustifyH("CENTER")
    c.heritageAvailability = Text(c.heritageWell, "", 84, 66, 286, "GameFontHighlightSmall", VALUE)
    c.heritageAvailability:Hide()
    -- The Progress module's per-Heritage bar is the progress row (its right-click menu holds
    -- the XP-bar settings, spec section 2).
    if ProjectRebirthProgress.LayoutPanel then ProjectRebirthProgress.LayoutPanel(c.heritageWell, c.tabs.rebirth.left) end
    c.previewLabel = Text(c.heritageWell, "Preview at level", 16, 96, 120, "GameFontHighlight", INK)
    c.previewButtons = {}
    for index, level in ipairs({1,10,50,100}) do
        local previewLevel = level
        c.previewButtons[index] = Button(c.heritageWell, tostring(level), 136+(index-1)*50, 92, 46,
            function() c.previewHeritage(previewLevel) end)
    end
    Pin(c.heritageScroll, c.heritageWell, 10, 112, 494, 202)
    c.heritageChild:SetWidth(470)
    c.heritageSummary:SetWidth(462)
    c.heritageSummary:SetTextColor(unpack(INK))
    c.bonusTitle = Section(c.heritageChild, "Your bonuses now", 0, 466)
    c.bonusRows = {}
    for index = 1, 4 do
        c.bonusRows[index] = {label = Text(c.heritageChild, "", 8, 0, 300, "GameFontHighlight", INK),
            value = Text(c.heritageChild, "", 300, 0, 158, "GameFontHighlight", VALUE)}
        c.bonusRows[index].value:SetJustifyH("RIGHT")
    end
    c.milestoneTitle = Section(c.heritageChild, "Milestones", 0, 466)
    c.milestones = {}
    for index = 1, 8 do c.milestones[index] = Criterion(c.heritageChild, 462) end
    c.milestoneNote = Text(c.heritageChild, "Haste from Every Man for Himself does not stack with Bloodlust or Heroism; the stronger one applies.",
        8, 0, 450, "GameFontHighlightSmall", INK2)
    Pin(c.aspect, c.heritageWell, 280, 296, 210, 22)
    UIDropDownMenu_SetWidth(c.aspect, 174)
    Pin(c.heritageWarning, c.heritageWell, 16, 328, 330, 24)
    c.heritageWarning:SetShadowOffset(1, -1)
    Pin(c.heritageButton, c.heritageWell, 360, 328, 140, 22)

    -- Rebirth ───────────────────────────────────────────────────────────────
    local r = c.tabs.rebirth
    c.lifeCard:SetBackdrop(nil)
    Pin(c.lifeCard, r.left, 0, 0, 198, 362)
    Category(c.lifeCard, "This Life", 0)
    c.lifeRows = {}
    for index = 1, 5 do
        c.lifeRows[index] = {label = Text(c.lifeCard, "", 12, 30 + (index-1)*20, 100, "GameFontHighlightSmall", INK2),
            value = Text(c.lifeCard, "", 88, 30 + (index-1)*20, 100, "GameFontHighlightSmall", INK)}
        c.lifeRows[index].value:SetJustifyH("RIGHT")
    end
    for _, value in ipairs({c.rebirthLife,c.rebirthLevel,c.rebirthCapacity,c.rebirthHeritage}) do value:Hide() end
    Category(c.lifeCard, "Permanent", 232)
    c.eligibilityCard:SetBackdrop(nil)
    Pin(c.eligibilityCard, r.right, 0, 0, 514, 362)
    Texture(c.eligibilityCard, "Interface\\Icons\\Spell_Holy_Resurrection", 16, 14, 52, 52, nil, "ARTWORK")
    Texture(c.eligibilityCard, ART .. "UI-Achievement-IconFrame", 10, 8, 64, 64, {0,.5625,0,.5625}, "OVERLAY")
    c.rebirthHeading = Text(c.eligibilityCard, "Rebirth", 84, 16, 286, "GameFontNormalLarge", GOLD)
    c.rebirthHeading:SetShadowOffset(1, -1)
    Pin(c.rebirthEligibility, c.eligibilityCard, 84, 42, 286, 28)
    c.rebirthEligibility:SetTextColor(unpack(INK2))
    Texture(c.eligibilityCard, ART .. "UI-Achievement-Header", 372, 18, 133, 39, {.4199,.6797,.4141,.5664}, "ARTWORK")
    c.rebirthRank = Text(c.eligibilityCard, "", 372, 30, 133, "GameFontHighlight", {1,1,1})
    c.rebirthRank:SetJustifyH("CENTER")
    c.rebirthRankSub = Text(c.eligibilityCard, "Rebirth Level", 372, 60, 133, "GameFontHighlightSmall", INK2)
    c.rebirthRankSub:SetJustifyH("CENTER")
    c.rebirthScroll, c.rebirthChild = Scroll(c.eligibilityCard, "ProjectRebirthV2RebirthScroll", 10, 80, 514, 234)
    c.rebirthNext:Hide()
    c.whereTitle = Section(c.rebirthChild, "Where you can be reborn", 0, 470)
    c.whereIntro = Text(c.rebirthChild, "Any character level. The server checks these when you preview:", 8, 26, 450, "GameFontHighlightSmall", INK2)
    c.criteria = {}
    for index = 1, 6 do c.criteria[index] = Criterion(c.rebirthChild, 458) end
    c.happensTitle = Section(c.rebirthChild, "What happens", 0, 470)
    c.resetsHead = Text(c.rebirthChild, "Resets", 8, 0, 220, "GameFontNormal", GOLD)
    c.resetsHead:SetShadowOffset(1, -1)
    c.keepsHead = Text(c.rebirthChild, "You keep", 242, 0, 220, "GameFontNormal", GOLD)
    c.keepsHead:SetShadowOffset(1, -1)
    c.resets = Text(c.rebirthChild, "Level, talents, quests, this Life's Skills, and your Life Heritage.", 8, 0, 222)
    c.keeps = Text(c.rebirthChild, "Items, equipment, money, collections, professions, reputation, class abilities, and Bloodline rank.", 242, 0, 222)
    c.previewResult = Text(c.rebirthChild, "", 8, 0, 450, "GameFontHighlight", INK)
    c.rebirthNote = Text(c.eligibilityCard, "", 16, 328, 330, "GameFontHighlightSmall", {1,.5,.25})
    c.rebirthNote:SetShadowOffset(1, -1)
    Pin(c.rebirthPreview, c.eligibilityCard, 360, 328, 140, 22)
    Pin(c.rebirthConfirm, c.eligibilityCard, 360, 328, 140, 22)
    V.Context = c
end

local function Format(value)
    return ProjectRebirthProgress.Format(value == nil and "0" or tostring(value))
end

local function RenderSkills(c, state, skill)
    c.skillCount:SetText(state.complete and ("Owned: " .. state.total) or "Loading your Skills...")
    c.skillSummary:Hide()
    local catalog = skill and ProjectRebirthSkillData and ProjectRebirthSkillData[skill.id]
    local live = state.presentation and state.presentation.skills[skill and skill.id or 0]
    c.skillRank:SetText(skill and ("Rank " .. (roman[skill.rank] or skill.rank)) or "")
    c.skillMeta:SetTextColor(unpack(INK2))
    -- Progress: a bar only when the server sends the next-rank target; otherwise the total.
    local fraction = ProjectRebirthProgress.RankFraction(live)
    if skill and fraction and live.nextXp and live.atCap ~= true then
        c.skillXP:SetValue(fraction)
        c.skillXP.label:SetText(Format(live.earnedXp) .. " / " .. Format(live.nextXp) ..
            "  (" .. Format(live.remainingXp) .. " to rank " .. (roman[skill.rank + 1] or "") .. ")")
        c.skillXP:Show(); c.skillXPText:Hide()
    else
        c.skillXP:Hide()
        c.skillXPText:SetText(skill and (Format(skill.xpExact or skill.xp) .. " Skill experience") or "Choose a Skill in the Library.")
        c.skillXPText:Show()
    end
    local texts = {}
    for rank = 1, 5 do
        local value = catalog and catalog.ranks and catalog.ranks[rank]
        if value then texts[rank] = ProjectRebirthSkillPresentation.Clean(value.text or "") end
    end
    local tableData = #texts == 5 and V.RankTable(texts)
    local current = skill and skill.rank or 0
    for _, row in ipairs(c.rankRows) do row:Hide() end
    for _, line in ipairs(c.rankLines) do line.label:Hide(); for _, cell in ipairs(line.cells) do cell:Hide() end end
    for _, head in ipairs(c.rankHead) do head:Hide() end
    c.rankBand:Hide(); c.rankCommon:Hide()
    local offset = 0
    if tableData then
        c.rankCommon:SetText(table.concat(tableData.common, "\n"))
        Pin(c.rankCommon, c.skillChild, 4, 0, 462)
        c.rankCommon:Show()
        offset = (#tableData.common > 0 and c.rankCommon:GetStringHeight() + 10) or 0
        local x0, width = 170, 58
        for rank = 1, 5 do
            Pin(c.rankHead[rank], c.skillChild, x0 + (rank-1)*width, offset, width)
            c.rankHead[rank]:SetJustifyH("CENTER")
            c.rankHead[rank]:SetTextColor(unpack(rank == current and VALUE or INK))
            c.rankHead[rank]:Show()
        end
        for index, row in ipairs(tableData.rows) do
            local line, y = c.rankLines[index], offset + 18 + (index-1)*20
            Pin(line.label, c.skillChild, 4, y + 2, 164)
            line.label:SetText(row.label); line.label:Show()
            for rank = 1, 5 do
                Pin(line.cells[rank], c.skillChild, x0 + (rank-1)*width, y, width)
                line.cells[rank]:SetText(row.values[rank] or "")
                line.cells[rank]:SetTextColor(unpack(rank == current and VALUE or INK))
                line.cells[rank]:Show()
            end
        end
        if current >= 1 and current <= 5 then
            Pin(c.rankBand, c.skillChild, x0 + (current-1)*width + 2, offset - 2, width - 4, 22 + #tableData.rows*20)
            c.rankBand:Show()
        end
        offset = offset + 24 + #tableData.rows*20
    elseif #texts > 0 then
        for rank, row in ipairs(c.rankRows) do
            if texts[rank] then
                row.body:SetText(texts[rank])
                row.rank:SetTextColor(unpack(rank == current and VALUE or INK))
                row.body:SetTextColor(unpack(rank == current and VALUE or INK))
                local height = math.max(18, row.body:GetStringHeight() + 6)
                Pin(row, c.skillChild, 0, offset, 466, height)
                row:Show()
                offset = offset + height + 4
            end
        end
    else
        c.skillSummary:Show()
        c.skillSummary:SetText(skill and (skill.summary or "") or "Choose a Skill in the Library to see what it does at every rank.")
        offset = c.skillSummary:GetStringHeight() + 12
    end
    c.rankTitle.label:SetText("Rank by rank")
    c.skillChild:SetHeight(math.max(1, offset))
    c.skillScroll:UpdateScrollChildRect()
    c.skillStatus:SetText(live and live.status or "")
end

local function HeritageFor(state, id)
    for _, entry in ipairs(state.heritages or {}) do if entry.id == id then return entry end end
end

local function RenderBloodlineRow(c, state, viewed)
    c.bloodlineId = nil
    for id, info in pairs(V.BLOODLINE) do
        local entry = HeritageFor(state, id)
        if entry and entry.eligible ~= false then
            c.bloodlineId = id
            local gender = UnitSex and UnitSex("player") == 3 and "_Female" or "_Male"
            c.bloodlineIcon:SetTexture("Interface\\Icons\\" .. info.portrait .. gender)
            c.bloodlineName:SetText(info.race .. " Bloodline")
            c.bloodlineRank:SetText("Rank " .. (tonumber(entry.rank) or 0) .. " of " .. (tonumber(entry.maxRank) or 100))
            local live = state.presentation and state.presentation.heritages[id]
            local fraction = live and ProjectRebirthProgress.RankFraction(live)
            c.bloodlineBar:SetValue(fraction or 0)
            ShowIf(c.bloodlineBar, fraction ~= nil)
            ShowIf(c.bloodlineSel, viewed and viewed.id == id)
        end
    end
    ShowIf(c.bloodline, c.bloodlineId ~= nil)
    ShowIf(c.bloodlineNone, c.bloodlineId == nil)
end

local function Milli(value)
    value = tonumber(value) or 0
    return string.format(value % 1000 == 0 and "%d%%" or "%.1f%%", value / 1000)
end

local function RenderBloodlineDetail(c, heritage, record)
    local info = V.BLOODLINE[heritage.id]
    local rank = tonumber(heritage.rank) or 0
    c.heritageName:SetText(info.race .. " Bloodline")
    c.heritageMeta:SetText("Bloodline · " .. info.race)
    c.heritageRank:SetText("Rank " .. rank)
    c.heritageRankSub:SetText("of " .. (tonumber(heritage.maxRank) or 100))
    c.heritageSummary:Hide()
    local y = 0
    local rows = record and record.rows and #record.rows > 0 and record.rows or {
        {label = "All primary stats", value = "+" .. Milli(heritage.bonusMilli)},
        {label = "Positive reputation gains", value = "+" .. Milli(heritage.reputationBonusMilli)},
        {label = "Every Man for Himself cooldown", value = (tonumber(heritage.cooldownSeconds) or 0) .. " sec"},
        {label = "Every Man for Himself haste", value = (tonumber(heritage.hasteBonusMilli) or 0) > 0 and Milli(heritage.hasteBonusMilli) or "from rank 50"},
    }
    Pin(c.bonusTitle, c.heritageChild, 0, y, 466); c.bonusTitle:Show(); y = y + 26
    for index, row in ipairs(c.bonusRows) do
        local data = rows[index]
        if data then
            Pin(row.label, c.heritageChild, 8, y, 300); Pin(row.value, c.heritageChild, 300, y, 158)
            row.label:SetText(data.label); row.value:SetText(data.value)
            row.label:Show(); row.value:Show(); y = y + 18
        else row.label:Hide(); row.value:Hide() end
    end
    y = y + 8
    Pin(c.milestoneTitle, c.heritageChild, 0, y, 466); c.milestoneTitle:Show(); y = y + 26
    local list = {}
    if record and record.milestones and #record.milestones > 0 then
        for _, m in ipairs(record.milestones) do list[#list + 1] = {tonumber(m.rank), m.text, m.reached} end
    elseif heritage.id == 1102 then list = V.HUMAN_MILESTONES end
    local nextShown = false
    for index, row in ipairs(c.milestones) do
        local m = list[index]
        if m then
            local reached
            if record and record.milestones and #record.milestones > 0 then
                reached = m[3]
            else reached = rank >= m[1] end
            local isNext = reached == false and not nextShown
            if isNext then nextShown = true end
            Pin(row, c.heritageChild, 4, y)
            SetCriterion(row, reached, "Rank " .. m[1], m[2], isNext, isNext and ("Next · " .. (m[1] - rank) .. " to go") or nil)
            y = y + row:GetHeight() + 4
        else row:Hide() end
    end
    if heritage.id == 1102 then
        Pin(c.milestoneNote, c.heritageChild, 8, y + 4, 450); c.milestoneNote:Show()
        y = y + c.milestoneNote:GetStringHeight() + 10
    else c.milestoneNote:Hide() end
    c.heritageChild:SetHeight(math.max(1, y))
    c.heritageWarning:SetText("Rank and experience are kept through Rebirth.")
    c.heritageWarning:SetTextColor(.4, 1, .4)
    c.heritageButton:Hide()
end

local function RenderLifeDetail(c, heritage, record)
    for _, widget in ipairs({c.bonusTitle, c.milestoneTitle, c.milestoneNote}) do widget:Hide() end
    for _, row in ipairs(c.bonusRows) do row.label:Hide(); row.value:Hide() end
    for _, row in ipairs(c.milestones) do row:Hide() end
    c.heritageSummary:Show()
    if record then
        local lines = {}
        for _, row in ipairs(record.rows or {}) do lines[#lines + 1] = row.label .. ": |cff005c00" .. row.value .. "|r" end
        if record.signature then
            lines[#lines + 1] = "\n|cff8a5a00Level " .. record.signature.unlockLevel .. ": " .. record.signature.name ..
                (record.signature.active == true and "  (Active)" or "") .. "|r\n" .. record.signature.text
        end
        if record.growth then lines[#lines + 1] = "\n" .. record.growth end
        c.heritageSummary:SetText(table.concat(lines, "\n"))
    end
    Pin(c.heritageSummary, c.heritageChild, 4, 0, 462)
    c.heritageChild:SetHeight(math.max(1, c.heritageSummary:GetStringHeight() + 12))
    local level = record and tonumber(record.previewLevel) or 0
    if level <= 0 then level = tonumber(heritage.rank) or 0 end
    c.heritageMeta:SetText(heritage.selected and "Life Heritage · chosen for this Life" or "Life Heritage · not chosen this Life")
    c.heritageRank:SetText("Level " .. level)
    c.heritageRankSub:SetText("of " .. (tonumber(heritage.maxRank) or 100))
    -- Bug 2 fix: the "locks in" warning is about choosing, never a claim it is chosen.
    if heritage.selected then
        c.heritageWarning:SetText("Chosen for this Life. Its level carries into future Lives.")
        c.heritageWarning:SetTextColor(.4, 1, .4)
        c.heritageButton:Hide()
    else
        c.heritageWarning:SetText("Locks in for this Life. You can choose again after Rebirth.")
        c.heritageWarning:SetTextColor(1, .5, .25)
        c.heritageButton:SetText("Choose " .. (heritage.name or "Heritage"))
        c.heritageButton:Show()
    end
    if heritage.eligible == false then
        c.heritageWarning:SetText((heritage.eligibilityReason or "") ~= "" and heritage.eligibilityReason or "Not available to your race")
        c.heritageWarning:SetTextColor(1, .35, .25)
        c.heritageButton:Hide()
    end
end

local function RenderHeritages(c, state, heritage)
    local record = state.presentation and state.presentation.heritages[heritage and heritage.id or 0]
    local preview = state.presentationPreview
    if preview and heritage and preview.id == heritage.id then record = preview end
    RenderBloodlineRow(c, state, heritage)
    local life = 0
    for _, entry in ipairs(state.heritages or {}) do
        if not V.RETIRED[entry.id] and not V.BLOODLINE[entry.id] then life = life + 1 end
    end
    c.heritageCount:SetText("Choose one each Life · " .. life .. " to choose from")
    c.heritageWarning:Show()
    if not heritage then return end
    if V.BLOODLINE[heritage.id] then
        RenderBloodlineDetail(c, heritage, record)
    else
        RenderLifeDetail(c, heritage, record)
    end
    -- Level preview only exists when the server answers it; otherwise the row is absent.
    local previews = state.presentationAvailable == true and not heritage.selected and
        not V.BLOODLINE[heritage.id] and not state.inspectedName
    ShowIf(c.previewLabel, previews)
    for _, button in ipairs(c.previewButtons) do ShowIf(button, previews) end
    Pin(c.heritageScroll, c.heritageWell, 10, previews and 120 or 94, 494, previews and 196 or 222)
    c.heritageScroll:UpdateScrollChildRect()
end

local function RenderRebirth(c, state)
    local r = state.rebirth
    local life = r.lifeNumber > 0 and r.lifeNumber or 1
    local ready = r.status == "preview_ready" and r.transaction and r.token
    local bloodline, lifeHeritage = "None", "None"
    for _, entry in ipairs(state.heritages or {}) do
        if V.BLOODLINE[entry.id] and entry.eligible ~= false then
            bloodline = V.BLOODLINE[entry.id].race .. ", rank " .. (tonumber(entry.rank) or 0)
        elseif entry.selected and not V.RETIRED[entry.id] then lifeHeritage = entry.name end
    end
    local rows = {{"Life", tostring(life)}, {"Character level", tostring(UnitLevel and UnitLevel("player") or "")},
        {"Skills", state.owned .. " / " .. state.capacity}, {"Bloodline", bloodline}, {"Life Heritage", lifeHeritage}}
    for index, row in ipairs(c.lifeRows) do
        row.label:SetText(rows[index][1]); row.value:SetText(rows[index][2])
    end
    c.rebirthRank:SetText("Level " .. (r.rebirthLevel or 0))
    c.rebirthHeading:SetText(ready and ("Begin Life " .. r.lifeAfter) or "Rebirth")
    c.rebirthEligibility:SetText(ready and "Preview ready. Confirm before it expires." or
        ("Begin Life " .. (life + 1) .. " · nothing changes until you confirm"))
    local y = 0
    Pin(c.whereTitle, c.rebirthChild, 0, y, 470); y = y + 26
    Pin(c.whereIntro, c.rebirthChild, 8, y, 450); y = y + 18
    local criteria = state.presentation and state.presentation.criteria or {}
    if #criteria == 0 then
        criteria = {{label = "In an inn, rested area, city, or capital"}, {label = "Standing still and out of combat"},
            {label = "Not in an instance, queue, taxi, or transport"}, {label = "Not in a duel or a trade"}}
    end
    for index, row in ipairs(c.criteria) do
        local data = criteria[index]
        if data then
            Pin(row, c.rebirthChild, 8, y)
            SetCriterion(row, data.met, nil, data.label, false, data.met == false and "Not met" or nil)
            y = y + row:GetHeight() + 2
        else row:Hide() end
    end
    y = y + 10
    Pin(c.happensTitle, c.rebirthChild, 0, y, 470); y = y + 26
    Pin(c.resetsHead, c.rebirthChild, 8, y, 220); Pin(c.keepsHead, c.rebirthChild, 242, y, 220); y = y + 18
    Pin(c.resets, c.rebirthChild, 8, y, 222); Pin(c.keeps, c.rebirthChild, 242, y, 222)
    y = y + math.max(c.resets:GetStringHeight(), c.keeps:GetStringHeight()) + 12
    if ready then
        c.previewResult:SetText("RXP awarded: |cff005c00" .. Format(r.awardRxpExact) .. "|r\nNew total: " ..
            Format(r.totalRxpAfterExact) .. "\nNew Rebirth Level: " .. r.levelAfter ..
            "\nHeirloom Skills kept: " .. r.heirloomCount)
        Pin(c.previewResult, c.rebirthChild, 8, y, 450); c.previewResult:Show()
        y = y + c.previewResult:GetStringHeight() + 8
    else c.previewResult:Hide() end
    c.rebirthChild:SetHeight(math.max(1, y))
    c.rebirthScroll:UpdateScrollChildRect()
    c.rebirthNote:SetText(#r.denials > 0 and not ready and ("Not here: " .. table.concat(r.denials, ", ")) or
        "Preview first. Closing the window changes nothing.")
    if ready then c.rebirthPreview:Hide(); c.rebirthConfirm:Show()
    else c.rebirthPreview:Show(); c.rebirthConfirm:Hide() end
end

function V.Render(state, activeTab, skill, heritage)
    local c = context
    if not c then return end
    local titles = {skills="Skills",heritages="Heritages",rebirth="Rebirth",glossary="Glossary"}
    c.title:SetText(titles[activeTab] or "Project Reverie")
    local life = state.rebirth.lifeNumber > 0 and state.rebirth.lifeNumber or 1
    local race = UnitRace and UnitRace("player") or ""
    c.plaque:SetText(activeTab == "skills" and ("Life " .. life .. " · " .. state.owned .. "/" .. state.capacity) or
        activeTab == "rebirth" and ("Life " .. life) or
        activeTab == "heritages" and ("Life " .. life .. " · " .. race) or "Library")
    ShowIf(c.status, state.notice ~= nil)
    if activeTab == "skills" then RenderSkills(c, state, skill)
    elseif activeTab == "heritages" then RenderHeritages(c, state, heritage)
    elseif activeTab == "rebirth" then RenderRebirth(c, state) end
end

-- The redesigned Glossary uses its existing pure ownership/filter functions.
-- Category navigation replaces the competing tier/ownership dropdowns.
function V.CreateGlossary(parent)
    local frame = CreateFrame("Frame", "ProjectRebirthSkillGlossary", parent)
    Pin(frame, parent, 0, 0, 728, 362)
    local filter = {search="",tier={},rarity={},ownership={},group="Alphabetical"}
    local category, page, selected = "all", 1, nil
    frame.rows, frame.categories = {}, {}
    local function refresh() if frame:IsShown() then frame:Refresh() end end
    local categories = {{"all","All Skills"},{"tier1","Tier 1"},{"tier2","Tier 2"},
        {"owned","Owned this Life"},{"heritages","Heritages"},{"bloodlines","Bloodlines of Azeroth"},{"rebirth","Rebirth"}}
    for index, entry in ipairs(categories) do
        local key = entry[1]
        local button = CreateFrame("Button", nil, frame)
        Pin(button, frame, 0, (index-1)*36, 198, 32)
        Texture(button, ART .. "UI-Achievement-Category-Background", 0, 0, 198, 32, {0,.6641,0,1})
        button:SetHighlightTexture(ART .. "UI-Achievement-Category-Highlight")
        button.label = Text(button, entry[2], 10, 8, 178, "GameFontNormalSmall", {1,.82,0})
        button:SetScript("OnClick", function() category=key; page=1; selected=nil; refresh() end)
        frame.categories[key] = button
    end
    frame.search = CreateFrame("EditBox", "ProjectRebirthV2GlossarySearch", frame, "InputBoxTemplate")
    Pin(frame.search, frame, 230, 8, 262, 22)
    frame.search:SetAutoFocus(false)
    frame.search:SetMaxLetters(100)
    frame.search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    frame.searchHint = Text(frame.search, "Search names and effects", 2, 5, 250, "GameFontDisableSmall", {.5,.5,.5})
    frame.search:SetScript("OnTextChanged", function(self) filter.search=self:GetText() or ""; page=1
        if filter.search == "" then frame.searchHint:Show() else frame.searchHint:Hide() end; refresh() end)
    frame.search:SetScript("OnEditFocusGained", function() frame.searchHint:Hide() end)
    frame.search:SetScript("OnEditFocusLost", function(self) if (self:GetText() or "") == "" then frame.searchHint:Show() end end)
    frame.rarity = CreateFrame("Frame", "ProjectRebirthV2GlossaryRarity", frame, "UIDropDownMenuTemplate")
    Pin(frame.rarity, frame, 494, 4, 110, 26)
    UIDropDownMenu_SetWidth(frame.rarity, 88)
    local rarity = "All"
    UIDropDownMenu_SetText(frame.rarity, "All rarities")
    UIDropDownMenu_Initialize(frame.rarity, function()
        for _, value in ipairs({"All","Common","Uncommon","Rare","Epic","Legendary","Mythic"}) do
            local choice = value
            local info = UIDropDownMenu_CreateInfo()
            info.text, info.checked = choice, rarity==choice
            info.func = function() rarity=choice; filter.rarity=choice; page=1; UIDropDownMenu_SetText(frame.rarity,choice); refresh() end
            UIDropDownMenu_AddButton(info)
        end
    end)
    frame.sort = CreateFrame("Frame", "ProjectRebirthV2GlossarySort", frame, "UIDropDownMenuTemplate")
    Pin(frame.sort, frame, 612, 4, 110, 26)
    UIDropDownMenu_SetWidth(frame.sort, 86)
    UIDropDownMenu_SetText(frame.sort, "Name")
    UIDropDownMenu_Initialize(frame.sort, function()
        for _, value in ipairs({"Alphabetical","Tier","Rarity","Category","Mastery"}) do
            local choice=value
            local info=UIDropDownMenu_CreateInfo()
            info.text,info.checked=choice,filter.group==choice
            info.func=function() filter.group=choice; page=1; UIDropDownMenu_SetText(frame.sort,choice); refresh() end
            UIDropDownMenu_AddButton(info)
        end
    end)
    frame.count = Text(frame,"",232,40,470,"GameFontHighlightSmall",INK2)
    local quality = {Common={1,1,1},Uncommon={.12,1,.12},Rare={0,.44,.87},Epic={.64,.21,.93},Legendary={1,.5,0},Mythic={.35,.9,1}}
    for index=1,9 do
        local row=CreateFrame("Button",nil,frame)
        Pin(row,frame,228,58+(index-1)*29,476,28)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        row.icon=Texture(row,"Interface\\Icons\\INV_Misc_Book_11",0,1,24,24,nil,"ARTWORK")
        row.name=Text(row,"",32,1,434,"GameFontNormalSmall")
        row.name:SetShadowOffset(1,-1)
        row.name:SetHeight(12)
        row.meta=Text(row,"",32,15,434,"GameFontHighlightSmall",INK2)
        row.meta:SetHeight(12)
        row:SetScript("OnEnter",function(self)
            if not self.entry then return end
            local entry=self.entry
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
            GameTooltip:AddLine(entry.name,1,.82,0)
            if entry.designText then
                GameTooltip:AddLine(entry.heritageId and "Current native Heritage · inspect before confirming" or
                    entry.information and "Read-only information" or "Bloodline design · revealed as each race is released",1,.4,.15,true)
                GameTooltip:AddLine(entry.designText,1,1,1,true)
            else
                local snapshot=ProjectRebirthGlossary.Snapshot()
                local owned=ProjectRebirthGlossary.Ownership(entry,snapshot)
                GameTooltip:AddLine("Tier "..entry.tier.." · "..entry.rarity.." · "..entry.category,1,1,1,true)
                GameTooltip:AddLine(ProjectRebirthSkillPresentation.Effect(entry.id),1,.82,0,true)
                local card=ProjectRebirthSkillData and ProjectRebirthSkillData[entry.id]
                if card and card.ranks then
                    GameTooltip:AddLine("Rank I: "..ProjectRebirthSkillPresentation.Clean(card.ranks[1].text),1,1,1,true)
                    GameTooltip:AddLine("Rank V: "..ProjectRebirthSkillPresentation.Clean(card.ranks[5].text),1,1,1,true)
                end
                GameTooltip:AddLine(owned, .6,1,.6)
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave",function() GameTooltip:Hide() end)
        row:SetScript("OnClick",function(self)
            if self.entry and self.entry.heritageId and context then context.selectHeritage(self.entry.heritageId) end
        end)
        frame.rows[index]=row
    end
    frame.previous=Button(frame,"<",230,326,30,function() page=page-1; refresh() end)
    frame.next=Button(frame,">",674,326,30,function() page=page+1; refresh() end)
    frame.previous:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
    frame.next:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    frame.pageText=Text(frame,"",310,332,300,"GameFontHighlightSmall")
    frame.notice=Text(frame,"",12,272,174,"GameFontHighlightSmall",INK2)
    frame.portraits={}
    for index=1,10 do
        local portrait=CreateFrame("Button",nil,frame)
        Pin(portrait,frame,230+((index-1)%2)*240,64+math.floor((index-1)/2)*52,232,48)
        portrait.icon=Texture(portrait,"Interface\\Icons\\INV_Misc_QuestionMark",0,0,42,42,nil,"ARTWORK")
        portrait.name=Text(portrait,"",50,2,178,"GameFontNormalSmall")
        portrait.name:SetHeight(28)
        portrait.meta=Text(portrait,"Design preview",50,30,178,"GameFontHighlightSmall")
        portrait:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        portrait:SetScript("OnEnter",function(self)
            if not self.entry then return end
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
            GameTooltip:AddLine(self.entry.name,1,.82,0)
            GameTooltip:AddLine(self.entry.designText,1,1,1,true)
            GameTooltip:Show()
        end)
        portrait:SetScript("OnLeave",function() GameTooltip:Hide() end)
        frame.portraits[index]=portrait
    end
    function frame:SetCategory(value) category=value;page=1;selected=nil;refresh() end
    function frame:Refresh()
        local snapshot=ProjectRebirthGlossary.Snapshot()
        local results={}
        if category=="bloodlines" then
            results=ProjectRebirthBloodlineDesignData or {}
            self.notice:SetText("Every race carries its own Bloodline. Its rank is kept per race and carries through Rebirth.")
        elseif category=="heritages" then
            for _, heritage in ipairs(context and context.state().heritages or {}) do
                results[#results+1]={name=heritage.name,designText=heritage.summary or "",heritageId=heritage.id}
            end
            self.notice:SetText("Current native choices. Click a Heritage to inspect it; selection requires confirmation.")
        elseif category=="rebirth" then
            results={{name="Begin a new Life",information=true,designText="Preview exact server results before confirming. Level, talents, quests and current-Life choices reset; permanent possessions and progression remain."}}
            self.notice:SetText("Rebirth commits are available only in the Rebirth tab.")
        else
            filter.tier=category=="tier1" and 1 or category=="tier2" and 2 or {}
            filter.ownership=category=="owned" and "Owned" or {}
            results=ProjectRebirthGlossary.Filter(ProjectRebirthGlossaryData or {},filter,snapshot)
            self.notice:SetText(snapshot.available and "" or "")
        end
        local pages=math.max(1,math.ceil(#results/9))
        page=math.min(math.max(page,1),pages)
        self.count:SetText(#results.." entries")
        self.pageText:SetText("Page "..page.." of "..pages)
        for index,row in ipairs(self.rows) do
            local entry=results[(page-1)*9+index]
            row.entry=entry
            if entry then
                row.name:SetText(entry.name)
                row.name:SetTextColor(unpack(quality[entry.rarity] or INK))
                local card=entry.id and ProjectRebirthSkillData and ProjectRebirthSkillData[entry.id]
                row.icon:SetTexture(entry.icon or card and card.icon or "Interface\\Icons\\INV_Misc_Book_11")
                if entry.designText then row.meta:SetText(entry.heritageId and "Inspect native Heritage" or entry.information and "Read-only information" or "Design preview · not live bonuses")
                else row.meta:SetText("Tier "..entry.tier.." · "..entry.category.." · "..ProjectRebirthGlossary.Ownership(entry,snapshot)) end
                if category=="bloodlines" then row:Hide() else row:Show() end
            else row:Hide() end
        end
        for index,portrait in ipairs(self.portraits) do
            local entry=category=="bloodlines" and results[index]
            portrait.entry=entry
            if entry then portrait.name:SetText(entry.name);portrait.icon:SetTexture(entry.icon);portrait:Show()
            else portrait:Hide() end
        end
        if category=="bloodlines" then
            self.pageText:SetText("The ten Bloodlines of Azeroth")
            self.previous:Hide();self.next:Hide()
        else self.previous:Show();self.next:Show() end
        if page>1 then self.previous:Enable() else self.previous:Disable() end
        if page<pages then self.next:Enable() else self.next:Disable() end
        for _, widget in ipairs({self.search,self.searchHint,self.rarity,self.sort}) do
            if category=="all" or category=="tier1" or category=="tier2" or category=="owned" then widget:Show() else widget:Hide() end
        end
    end
    frame:SetScript("OnShow",refresh)
    frame:Hide()
    return frame
end
