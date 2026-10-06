-- Project Reverie nameplates (Rebirth realm). Presentation only: never targets, moves health, or
-- changes data. Spec: docs/design/nameplates-v1.md. Shares its art and look with Project Skillful's
-- SkillfulPlates; the tier table is NameplateData.lua (scripts/Build-ProjectRebirthNameplateData.py).
--
-- 3.3.5a plates are anonymous WorldFrame children with two StatusBar children (health, cast) and
-- regions for the threat glow, border, cast border, cast shield, spell icon, hover glow, name,
-- level, skull, raid mark and elite dragon. Regions are recognised by their texture, not their
-- order. Sizes below are in plate units: our layout is 128 x 32 units, centred on the plate, with
-- one unit = the plate's width / 128 x the scale.
ProjectRebirthNameplates = {}
local P = ProjectRebirthNameplates
local MEDIA = "Interface\\AddOns\\ProjectRebirthTooltips\\Media\\Plate-"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local FONT = "Fonts\\FRIZQT__.TTF"

-- Health frame and level seat: two gold pills of one height. Where the bar's right end meets the
-- seat's left end, Plate-Join draws both as one shape so their rims merge into one gold wall.
-- These positions must match tools/skillful_plate_art.py (Project Skillful), which draws the join.
local FRAME_TOP, FRAME_H = 15.5, 15
local FRAME_CAP = FRAME_H / 2
local SEAT_LEFT, SEAT_TOP, SEAT_H = 104.5, 15.5, 15
local SEAT_CAP = SEAT_H / 2
local SEAT_Y = 23
local JOIN_X, JOIN_Y, JOIN_SIZE = 98, 15.5, 16
local BAR_X, BAR_Y, BAR_W, BAR_H = 3, 18, 103, 10
-- Cast bar: a slimmer pill of the same art under the health frame, the spell icon in a ring.
local CAST_TOP, CAST_H, CAST_LEFT, CAST_RIGHT = 31.5, 11, 12, 108
local CAST_CAP = CAST_H / 2
local CAST_BAR_X, CAST_BAR_Y, CAST_BAR_H = 14, 33.5, 7
local ICON_X, ICON_D, ICON_SIZE = 8, 15, 9.5
local RING, RING_X = 26, -4
local LEVEL_SIZE, NAME_SIZE = 8.5, 12.8
-- Threat: a halo of the frame's own shape behind it, this many units larger on every side.
local HALO = 1.6

P.DEFAULT_SCALE, P.MIN_SCALE, P.MAX_SCALE = 1.5, .75, 2.5
P.scale = P.DEFAULT_SCALE
P.OPTIONS = {
    {key = "scale", label = "Overall scale", min = .75, max = 2.5, default = 1.5},
    {key = "nameScale", label = "Name text size", min = .75, max = 1.5, default = 1},
    {key = "levelScale", label = "Level text size", min = .75, max = 1.5, default = 1},
    {key = "badgeScale", label = "Rank badge size", min = .75, max = 1.5, default = 1},
}
P.nameScale, P.levelScale, P.badgeScale = 1, 1, 1
P.settingsRevision = 0

local ART = {
    star = {file = "Star", bounds = {4, 5, 59, 57}},
    skull = {file = "Skull", bounds = {9, 5, 54, 55}},
    crowned = {file = "SkullCrowned", bounds = {10, 1, 54, 55}},
}

-- Badge layouts: {art, dx, dy, size}, dy downward; tiers 4 and 5 are centred by visible bounds.
local function Centre(layout)
    local x0, y0, x1, y1 = 1e9, 1e9, -1e9, -1e9
    for _, it in ipairs(layout) do
        local b, s = ART[it[1]].bounds, it[4]
        x0 = math.min(x0, it[2] + (b[1] / 64 - .5) * s); x1 = math.max(x1, it[2] + (b[3] / 64 - .5) * s)
        y0 = math.min(y0, it[3] + (b[2] / 64 - .5) * s); y1 = math.max(y1, it[3] + (b[4] / 64 - .5) * s)
    end
    local out = {}
    for i, it in ipairs(layout) do out[i] = {it[1], it[2] - (x0 + x1) / 2, it[3] - (y0 + y1) / 2, it[4]} end
    return out
end
P.Centre = Centre
P.BADGES = {
    {{"star", 0, 0, 13}},
    {{"star", -3.3, .2, 9}, {"star", 3.3, .2, 9}},
    {{"star", 0, -3, 8}, {"star", -3.4, 2.4, 8}, {"star", 3.4, 2.4, 8}},
    Centre({{"skull", 0, 0, 11.5}, {"star", -4.7, 5.5, 4.2}, {"star", -1.6, 6.7, 4.4},
        {"star", 1.6, 6.7, 4.4}, {"star", 4.7, 5.5, 4.2}}),
    Centre({{"crowned", 0, 0, 11.5}, {"star", -5.8, 4.9, 3.6}, {"star", -3.1, 6.5, 3.9},
        {"star", 0, 7.3, 4.9}, {"star", 3.1, 6.5, 3.9}, {"star", 5.8, 4.9, 3.6}}),
}

function P.SeatWidth(digits) return math.max(23, 9 + 6.2 * digits) end

-- Owner ruling 2026-10-04: Rebirth plates use Project Skillful's level rules: always the number,
-- coloured by danger, never grey and never a skull.
function P.Danger(player, level)
    if not player or not level then return 1, 1, 0 end
    local diff = level - player
    if diff >= 5 then return 1, .1, .1 end
    if diff >= 3 then return 1, .5, .25 end
    if diff >= -2 then return 1, 1, 0 end
    return .25, .75, .25
end

-- {tier, level} for a creature name from the generated table, or nil.
function P.Lookup(name)
    local data = ProjectRebirthNameplateData and ProjectRebirthNameplateData.creatures
    return name and data and data[name]
end

local ROLE = {
    ["interface\\targetingframe\\ui-targetingframe-flash"] = "threat",
    ["interface\\tooltips\\nameplate-border"] = "border",
    ["interface\\tooltips\\nameplate-castbar"] = "castBorder",
    ["interface\\tooltips\\nameplate-castbar-shield"] = "shield",
    ["interface\\tooltips\\nameplate-glow"] = "highlight",
    ["interface\\targetingframe\\ui-targetingframe-skull"] = "skull",
    ["interface\\targetingframe\\ui-raidtargetingicons"] = "raid",
    ["interface\\tooltips\\elitenameplateicon"] = "elite",
}

local function Role(region)
    local tex = region.GetTexture and region:GetTexture()
    return type(tex) == "string" and ROLE[string.lower(tex)] or nil
end

-- The plate's parts by role: textures by their art, the spell icon as the one unknown texture,
-- the first font string the name and the second the level, the two StatusBars health then cast.
function P.Parts(plate)
    local parts = {}
    for _, region in ipairs({plate:GetRegions()}) do
        local kind = region:GetObjectType()
        if kind == "FontString" then
            if not parts.name then parts.name = region else parts.level = parts.level or region end
        elseif kind == "Texture" then
            local role = Role(region)
            if role then parts[role] = parts[role] or region else parts.icon = parts.icon or region end
        end
    end
    for _, child in ipairs({plate:GetChildren()}) do
        if child:GetObjectType() == "StatusBar" then
            if not parts.health then parts.health = child else parts.cast = parts.cast or child end
        end
    end
    return parts
end

function P.IsPlate(frame)
    if not frame or frame:GetName() or not frame.GetRegions then return false end
    for _, region in ipairs({frame:GetRegions()}) do
        if Role(region) == "border" then return true end
    end
    return false
end

-- Anchor a region's top-left to layout point (x, y), the layout centred on the plate's centre.
local function Place(region, plate, u, x, y, w, h)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", plate, "CENTER", (x - 64) * u, -(y - 16) * u)
    if w then region:SetWidth(w * u) end
    if h then region:SetHeight(h * u) end
end

local function Tex(parent, layer, file, coords)
    local t = parent:CreateTexture(nil, layer)
    t:SetTexture(file)
    if coords then t:SetTexCoord(unpack(coords)) end
    return t
end

local LEFT, MIDDLE, RIGHT = {0, .25, 0, 1}, {.25, .75, 0, 1}, {.75, 1, 0, 1}
-- Stock art replaced by ours. The client shows some of it again in combat (the threat glow
-- above all, alpha included), so every refresh hides it again.
P.STOCK_ART = {"border", "castBorder", "elite", "highlight", "threat", "shield"}

function P.Skin(plate)
    local s = P.Parts(plate)
    -- A plate without the parts we draw around is left stock rather than half-skinned.
    local width = plate:GetWidth()
    if not s.health or not s.name or not s.level or not width or width ~= width or width <= 0 or
        width == math.huge then return nil end
    s.plate = plate
    -- Stock art replaced by ours: hidden through alpha so the client's own show/hide logic and
    -- addons reading IsShown() keep working.
    for _, key in ipairs(P.STOCK_ART) do
        if s[key] then s[key]:SetAlpha(0) end
    end
    -- The threat halo: the frame's pieces again, behind it, lit additively in the threat colour.
    -- No join piece: the two middles meet under the join, so the halo runs unbroken round the waist.
    s.halo = {
        Tex(plate, "BACKGROUND", MEDIA .. "Frame", LEFT), Tex(plate, "BACKGROUND", MEDIA .. "Frame", MIDDLE),
        Tex(plate, "BACKGROUND", MEDIA .. "Seat", MIDDLE), Tex(plate, "BACKGROUND", MEDIA .. "Seat", RIGHT),
    }
    for _, t in ipairs(s.halo) do t:SetBlendMode("ADD"); t:Hide() end
    s.frame = {
        Tex(plate, "ARTWORK", MEDIA .. "Frame", LEFT), Tex(plate, "ARTWORK", MEDIA .. "Frame", MIDDLE),
        Tex(plate, "ARTWORK", MEDIA .. "Join"), Tex(plate, "ARTWORK", MEDIA .. "Seat", MIDDLE),
        Tex(plate, "ARTWORK", MEDIA .. "Seat", RIGHT),
    }
    s.trough = Tex(s.health, "BACKGROUND", MEDIA .. "Trough")
    s.trough:SetAllPoints(s.health)
    s.hover = Tex(s.health, "OVERLAY", WHITE)
    s.hover:SetAllPoints(s.health)
    s.hover:SetBlendMode("ADD")
    s.hover:SetAlpha(.18)
    s.well = Tex(plate, "ARTWORK", MEDIA .. "RingWell")
    s.ring = Tex(plate, "ARTWORK", MEDIA .. "Ring")
    s.items = {}
    for i = 1, 6 do s.items[i] = Tex(plate, "OVERLAY", MEDIA .. "Star") end
    if s.cast then
        -- On the cast bar itself, so they show and hide with it; drawn over its fill's edges.
        s.castTrough = Tex(s.cast, "BACKGROUND", MEDIA .. "Trough")
        s.castTrough:SetAllPoints(s.cast)
        s.castFrame = {Tex(s.cast, "OVERLAY", MEDIA .. "Frame", LEFT), Tex(s.cast, "OVERLAY", MEDIA .. "Frame", MIDDLE),
            Tex(s.cast, "OVERLAY", MEDIA .. "Frame", RIGHT)}
        s.iconWell = Tex(s.cast, "ARTWORK", MEDIA .. "RingWell")
        s.iconRing = Tex(s.cast, "OVERLAY", MEDIA .. "Ring")
    end
    plate.rebirthPlate = s
    P.Refresh(s, true)
    return s
end

local function Shade(list, r, g, b)
    for _, t in ipairs(list) do t:SetVertexColor(r, g, b) end
end

local function Anchored(region, point, relative, relativePoint, x, y)
    if not region then return true end
    local p, r, rp, dx, dy = region:GetPoint()
    return p == point and r == relative and rp == relativePoint and dx and dy and
        math.abs(dx - x) < .0001 and math.abs(dy - y) < .0001
end

function P.Refresh(s, force)
    local plate = s.plate
    local width = plate:GetWidth()
    if not width or width ~= width or width <= 0 or width == math.huge then return end
    local u = width / 128 * P.scale
    local playerLevel = UnitLevel("player")
    local name = s.name and s.name:GetText()
    local row = P.Lookup(name)
    -- The level is always a number (owner ruling): the skull is replaced by the table's level.
    local text = s.level and s.level:GetText()
    local number = text and tonumber(string.match(text, "%d+"))
    if s.skull and s.skull:IsShown() or not number then
        if s.skull then s.skull:Hide() end
        if row and row[2] and row[2] > 0 then
            number = row[2]
            s.level:SetText(number)
            s.level:Show()
        end
    end
    local tier = row and row[1] or 0
    for _, key in ipairs(P.STOCK_ART) do
        local region = s[key]
        if region and region:GetAlpha() > 0 then region:SetAlpha(0) end
    end
    -- Threat and hover: the stock glows are shaped for the stock border. Threat lights our halo in
    -- its colour and leaves the gold frame gold; hover lights the bar.
    local threat = s.threat and s.threat:IsShown() or false
    local r, g, b = 1, 1, 1
    if threat then r, g, b = s.threat:GetVertexColor() end
    if threat ~= s.threatShown or r ~= s.threatR or g ~= s.threatG or b ~= s.threatB then
        s.threatShown, s.threatR, s.threatG, s.threatB = threat, r, g, b
        for _, t in ipairs(s.halo) do
            if threat then t:SetVertexColor(r, g, b); t:Show() else t:Hide() end
        end
    end
    local hover = s.highlight and s.highlight:IsShown() or false
    if hover ~= s.hoverShown then s.hoverShown = hover; if hover then s.hover:Show() else s.hover:Hide() end end
    if s.cast then
        local shielded = s.shield and s.shield:IsShown() or false
        if shielded ~= s.shielded then
            s.shielded = shielded
            -- An uninterruptible cast greys its frame, as the stock shield border does.
            if shielded then Shade(s.castFrame, .55, .55, .55) else Shade(s.castFrame, 1, 1, 1) end
        end
    end
    -- The client re-anchors its regions when a plate is reused; take them back.
    local sw = math.max(23, P.SeatWidth(number and string.len(tostring(number)) or 1) * P.levelScale)
    if not Anchored(s.health, "TOPLEFT", plate, "CENTER", (BAR_X - 64) * u, -(BAR_Y - 16) * u) or
        not Anchored(s.level, "CENTER", plate, "CENTER", (SEAT_LEFT + sw / 2 + .3 - 64) * u, -(SEAT_Y + .3 - 16) * u) or
        not Anchored(s.cast, "TOPLEFT", plate, "CENTER", (CAST_BAR_X - 64) * u, -(CAST_BAR_Y - 16) * u) or
        not Anchored(s.name, "BOTTOM", plate, "CENTER", 0, (16 - (FRAME_TOP - 1)) * u) or
        not Anchored(s.raid, "BOTTOM", s.name, "TOP", 0, 2 * u) then
        force = true
    end
    if not force and u == s.u and number == s.number and tier == s.tier and name == s.nameText and
        playerLevel == s.playerLevel and P.settingsRevision == s.settingsRevision then return end
    s.u, s.number, s.tier, s.nameText, s.playerLevel = u, number, tier, name, playerLevel
    s.settingsRevision = P.settingsRevision

    local right = SEAT_LEFT + sw
    local joinRight = JOIN_X + JOIN_SIZE
    local f = s.frame
    Place(f[1], plate, u, 0, FRAME_TOP, FRAME_CAP, FRAME_H)
    Place(f[2], plate, u, FRAME_CAP, FRAME_TOP, JOIN_X - FRAME_CAP, FRAME_H)
    Place(f[3], plate, u, JOIN_X, JOIN_Y, JOIN_SIZE, JOIN_SIZE)
    Place(f[4], plate, u, joinRight, SEAT_TOP, right - SEAT_CAP - joinRight, SEAT_H)
    Place(f[5], plate, u, right - SEAT_CAP, SEAT_TOP, SEAT_CAP, SEAT_H)
    local h, d, waist = s.halo, HALO, JOIN_X + JOIN_SIZE / 2
    Place(h[1], plate, u, -d, FRAME_TOP - d, FRAME_CAP + d, FRAME_H + 2 * d)
    Place(h[2], plate, u, FRAME_CAP, FRAME_TOP - d, waist - FRAME_CAP, FRAME_H + 2 * d)
    Place(h[3], plate, u, waist, SEAT_TOP - d, right - SEAT_CAP - waist, SEAT_H + 2 * d)
    Place(h[4], plate, u, right - SEAT_CAP, SEAT_TOP - d, SEAT_CAP + d, SEAT_H + 2 * d)
    Place(s.health, plate, u, BAR_X, BAR_Y, BAR_W, BAR_H)

    if s.name then
        s.name:SetFont(FONT, NAME_SIZE * u * P.nameScale)
        s.name:ClearAllPoints()
        s.name:SetPoint("BOTTOM", plate, "CENTER", 0, (16 - (FRAME_TOP - 1)) * u)
    end
    if s.raid then
        s.raid:ClearAllPoints()
        s.raid:SetPoint("BOTTOM", s.name or plate, "TOP", 0, 2 * u)
    end
    if s.level then
        s.level:SetFont(FONT, LEVEL_SIZE * u * P.levelScale)
        s.level:ClearAllPoints()
        s.level:SetPoint("CENTER", plate, "CENTER", (SEAT_LEFT + sw / 2 + .3 - 64) * u, -(SEAT_Y + .3 - 16) * u)
        if number then s.level:SetTextColor(P.Danger(playerLevel, number)) end
    end

    if s.cast then
        local c = s.castFrame
        Place(c[1], plate, u, CAST_LEFT, CAST_TOP, CAST_CAP, CAST_H)
        Place(c[2], plate, u, CAST_LEFT + CAST_CAP, CAST_TOP, CAST_RIGHT - CAST_LEFT - 2 * CAST_CAP, CAST_H)
        Place(c[3], plate, u, CAST_RIGHT - CAST_CAP, CAST_TOP, CAST_CAP, CAST_H)
        Place(s.cast, plate, u, CAST_BAR_X, CAST_BAR_Y, CAST_RIGHT - 2 - CAST_BAR_X, CAST_BAR_H)
        local cy = CAST_TOP + CAST_H / 2
        Place(s.iconWell, plate, u, ICON_X - ICON_D / 2, cy - ICON_D / 2, ICON_D, ICON_D)
        Place(s.iconRing, plate, u, ICON_X - ICON_D / 2, cy - ICON_D / 2, ICON_D, ICON_D)
        if s.icon then
            Place(s.icon, plate, u, ICON_X - ICON_SIZE / 2, cy - ICON_SIZE / 2, ICON_SIZE, ICON_SIZE)
            s.icon:SetTexCoord(.08, .92, .08, .92)
        end
    end

    local layout = P.BADGES[tier]
    if layout then
        local ring = RING * P.badgeScale
        Place(s.well, plate, u, RING_X - ring / 2, SEAT_Y - ring / 2, ring, ring)
        Place(s.ring, plate, u, RING_X - ring / 2, SEAT_Y - ring / 2, ring, ring)
        s.well:Show(); s.ring:Show()
    else
        s.well:Hide(); s.ring:Hide()
    end
    for i = 1, 6 do
        local item, it = s.items[i], layout and layout[i]
        if it then
            item:SetTexture(MEDIA .. ART[it[1]].file)
            local size = it[4] * P.badgeScale
            Place(item, plate, u, RING_X + it[2] * P.badgeScale - size / 2,
                SEAT_Y + it[3] * P.badgeScale - size / 2, size, size)
            item:Show()
        else
            item:Hide()
        end
    end
end

-- Re-enumerate on a child-count change rather than assuming a permanent append-only order.
-- Incomplete plates stay stock and are retried without allocating their replacement art.
P.seen, P.plates, P.pending = 0, {}, {}
function P.Scan()
    local n = WorldFrame:GetNumChildren()
    if n ~= P.seen then
        local kids = {WorldFrame:GetChildren()}
        P.plates, P.pending = {}, {}
        for i = 1, n do
            local f = kids[i]
            if P.IsPlate(f) then
                local s = f.rebirthPlate or P.Skin(f)
                if s then table.insert(P.plates, s) else table.insert(P.pending, f) end
            end
        end
        P.seen = n
    end
    for i = #P.pending, 1, -1 do
        local s = P.Skin(P.pending[i])
        if s then table.insert(P.plates, s); table.remove(P.pending, i) end
    end
    for _, s in ipairs(P.plates) do
        if s.plate:IsShown() then P.Refresh(s) end
    end
end

function P.SetOption(key, value)
    local option
    for _, candidate in ipairs(P.OPTIONS) do if candidate.key == key then option = candidate; break end end
    if not option then return false end
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then return false end
    P[key] = math.max(option.min, math.min(option.max, value))
    if type(ProjectRebirthNameplateSettings) ~= "table" then ProjectRebirthNameplateSettings = {} end
    ProjectRebirthNameplateSettings[key] = P[key]
    P.settingsRevision = P.settingsRevision + 1
    for _, s in ipairs(P.plates) do P.Refresh(s, true) end
    if P.UpdateOptions then P.UpdateOptions() end
    return true
end

function P.SetScale(value) return P.SetOption("scale", value) end

function P.ResetOptions()
    for _, option in ipairs(P.OPTIONS) do P.SetOption(option.key, option.default) end
end

local function Active() return GetRealmName and GetRealmName() == "Rebirth" end

-- A small stock-style dialog. Changes apply immediately; no reload or gameplay command.
function P.UpdateOptions()
    if not P.options then return end
    P.options.syncing = true
    for _, slider in ipairs(P.options.sliders) do
        slider:SetValue(P[slider.option.key] * 100)
        slider.valueText:SetText(string.format("%d%%", math.floor(P[slider.option.key] * 100 + .5)))
    end
    P.options.syncing = false
end

function P.OpenOptions()
    if not Active() then return end
    if not P.options then
        local f = CreateFrame("Frame", "ProjectRebirthNameplateOptions", UIParent)
        P.options = f
        f:SetWidth(390); f:SetHeight(350)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        f:SetFrameStrata("DIALOG"); f:SetToplevel(true)
        f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f:SetBackdrop({bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32,
            edgeSize = 32, insets = {left = 11, right = 12, top = 12, bottom = 11}})
        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        f.title:SetPoint("TOP", f, "TOP", 0, -22); f.title:SetText("Rebirth Nameplates")
        f.note = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f.note:SetPoint("TOPLEFT", f, "TOPLEFT", 26, -53); f.note:SetWidth(338)
        f.note:SetText("Changes apply immediately and save automatically.")
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
        close:SetScript("OnClick", function() f:Hide() end)
        f.sliders = {}
        for i, option in ipairs(P.OPTIONS) do
            local slider = CreateFrame("Slider", "ProjectRebirthPlateOption" .. i, f, "OptionsSliderTemplate")
            slider.option = option
            slider:SetWidth(275); slider:SetHeight(16)
            slider:SetPoint("TOPLEFT", f, "TOPLEFT", 30, -100 - (i - 1) * 52)
            slider:SetMinMaxValues(option.min * 100, option.max * 100); slider:SetValueStep(5)
            _G[slider:GetName() .. "Text"]:SetText(option.label)
            _G[slider:GetName() .. "Low"]:SetText(string.format("%d%%", option.min * 100))
            _G[slider:GetName() .. "High"]:SetText(string.format("%d%%", option.max * 100))
            slider.valueText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            slider.valueText:SetPoint("LEFT", slider, "RIGHT", 10, 0)
            slider:SetScript("OnValueChanged", function(self, value)
                if not f.syncing then P.SetOption(self.option.key, math.floor(value / 5 + .5) * .05) end
            end)
            f.sliders[i] = slider
        end
        local reset = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        reset:SetWidth(145); reset:SetHeight(24); reset:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 26, 22)
        reset:SetText("Reset defaults"); reset:SetScript("OnClick", P.ResetOptions)
        local done = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        done:SetWidth(100); done:SetHeight(24); done:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -26, 22)
        done:SetText("Close"); done:SetScript("OnClick", function() f:Hide() end)
        table.insert(UISpecialFrames, f:GetName())
    end
    P.UpdateOptions()
    P.options:Show()
end

P.driver = CreateFrame("Frame", "ProjectRebirthNameplateDriver")
P.driver:RegisterEvent("VARIABLES_LOADED")
P.driver:RegisterEvent("PLAYER_ENTERING_WORLD")
P.driver:SetScript("OnEvent", function(self, event)
    if event == "VARIABLES_LOADED" and type(ProjectRebirthNameplateSettings) == "table" then
        for _, option in ipairs(P.OPTIONS) do
            local saved = ProjectRebirthNameplateSettings[option.key]
            if saved ~= nil then P.SetOption(option.key, saved) end
        end
    end
    -- Only on the Rebirth realm, as the rest of this addon.
    if Active() then self:SetScript("OnUpdate", P.Scan) else
        self:SetScript("OnUpdate", nil)
        if P.options then P.options:Hide() end
    end
end)

local function Say(text) DEFAULT_CHAT_FRAME:AddMessage("Reverie nameplates: " .. text) end

SLASH_PROJECTREBIRTHPLATES1 = "/rplates"
SLASH_PROJECTREBIRTHPLATES2 = "/splates"
SlashCmdList["PROJECTREBIRTHPLATES"] = function(msg)
    if not Active() then return end
    msg = string.lower(string.match(msg or "", "^%s*(.-)%s*$"))
    if msg == "" or msg == "options" then P.OpenOptions(); return end
    if msg == "reset" then P.ResetOptions(); Say("default sizes restored."); return end
    local value = string.match(msg, "^scale%s*(.*)$")
    if value and value ~= "" and P.SetScale(value) then
        Say("plate size " .. P.scale .. "x the client's (" .. P.MIN_SCALE .. " to " .. P.MAX_SCALE .. ").")
    elseif value then
        Say("plate size is " .. P.scale .. "x. Use /rplates scale 1.5 (" .. P.MIN_SCALE .. " to " .. P.MAX_SCALE .. ").")
    elseif msg == "dump" then
        -- Diagnostics: the first visible plate's parts as recognised, for checking a client build.
        for _, s in ipairs(P.plates) do
            if s.plate:IsShown() then
                for _, key in ipairs({"name", "level", "threat", "border", "castBorder", "shield", "icon",
                    "highlight", "skull", "raid", "elite", "health", "cast"}) do
                    Say(key .. ": " .. (s[key] and "found" or "missing"))
                end
                return
            end
        end
        Say("no plate is showing. Press V to show enemy nameplates.")
    else
        Say("/splates opens settings; /splates scale 1.5 sets size; /splates reset restores defaults.")
    end
end
