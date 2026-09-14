-- HLC1 presentation only. Generated data and server curves must share a release.
-- No XP/combat authority, addon messages, chat output, or persistent state.
local source = ProjectRebirthHeirloomTooltipData
local function Number(value, low, high, integer)
    return type(value) == "number" and value == value and value >= low and value <= high and
        (not integer or value == math.floor(value))
end

local function Catalog()
    if type(source) ~= "table" or source.version ~= 1 or
        not Number(source.revision, 1, 4294967295, true) or type(source.entries) ~= "table" then return end
    local result, count = {}, 0
    for id, entry in pairs(source.entries) do
        if not Number(id, 1, 16777215, true) or type(entry) ~= "table" or
            type(entry.levels) ~= "table" then return end
        count = count + 1
        if count > 942 then return end
        local levels, actual = {}, 0
        for level, row in pairs(entry.levels) do
            if not Number(level, 1, 80, true) or type(row) ~= "table" then return end
            actual = actual + 1
            local copy = {}
            for _, key in ipairs({"armor", "nativeArmor", "feralAp", "nativeFeralAp"}) do
                if row[key] ~= nil then
                    if not Number(row[key], 0, (key:find("Armor") or key == "armor") and 100000 or 1000000, true) then
                        return
                    end
                    copy[key] = row[key]
                end
            end
            if (row.armor ~= nil and row.nativeArmor == nil) or
                (row.feralAp ~= nil and row.nativeFeralAp == nil) then return end
            local hasDamage = row.minDamage ~= nil or row.maxDamage ~= nil or row.dps ~= nil
            if hasDamage then
                if not Number(entry.delay, 1, 65535, true) then return end
                for _, key in ipairs({"minDamage", "maxDamage", "dps", "nativeDps",
                    "nativeMinDamage", "nativeMaxDamage"}) do
                    if not Number(row[key], 0, key:find("Damage") and 1000000 or 10000) then return end
                    copy[key] = row[key]
                end
                if copy.minDamage > copy.maxDamage or copy.nativeMinDamage > copy.nativeMaxDamage then return end
            elseif row.nativeMinDamage ~= nil or row.nativeMaxDamage ~= nil or row.nativeDps ~= nil then
                return
            end
            levels[level] = copy
        end
        if actual ~= 80 then return end
        result[id] = levels
    end
    if count == 0 then return end
    return result
end

local data = Catalog()
if not data then return end
source = nil -- retain only the checked, private copy
local api = {version = 1, revision = ProjectRebirthHeirloomTooltipData.revision}
ProjectRebirthHeirloomTooltips = api
local active, refreshPending = false, false
local frames, states = {}, setmetatable({}, {__mode = "k"})
local unpack = unpack

-- Authored r9/r10 on-use curves, not random ranges. EffectDieSides=0 is valid on
-- the server, but the 3.3.5a item renderer prints BasePoints+1 to BasePoints.
-- Keep this presentation adapter tied to the exact catalog revision and owned
-- six-rank families. Native/server values, duration and cooldown are unchanged.
local useProfiles = {
    {first = 2000019, last = 2000024, spell = 960011, base = 8, perLevel = 8.375,
        lead = "Increases attack power by ", tail = " for "},
    {first = 2000835, last = 2000840, spell = 960012, base = 4, perLevel = 4.375,
        lead = "Increases spell power by ", tail = " for "},
    {first = 2000841, last = 2000846, spell = 960013, base = 4, perLevel = 4.5,
        lead = "Absorbs ", tail = " damage. Lasts "},
    {first = 2000847, last = 2000852, spell = 960014, base = 7, perLevel = 7.5,
        lead = "Restores ", between = " mana and increases spell power by ",
        secondBase = 2, secondPerLevel = 2.625, tail = " for "},
}

-- Native globals are printf templates. Support positional translations without
-- passing unsupported %1$d formats to Lua 5.1's string.format.
local function Format(template, ...)
    if type(template) ~= "string" then return end
    local args, result, cursor, implicit = {...}, {}, 1, 1
    while cursor <= #template do
        local first = template:find("%", cursor, true)
        if not first then result[#result + 1] = template:sub(cursor); break end
        result[#result + 1] = template:sub(cursor, first - 1)
        local tail = template:sub(first)
        if tail:sub(1, 2) == "%%" then result[#result + 1] = "%"; cursor = first + 2
        else
            local token, index, precision, kind = tail:match("^(%%(%d+)%$([%.%d]*)([dfg]))")
            if not token then
                token, precision, kind = tail:match("^(%%([%.%d]*)([dfg]))")
                index = implicit; implicit = implicit + 1
            end
            index = tonumber(index)
            if not token or not index or not args[index] then return end
            local ok, text = pcall(string.format, "%" .. precision .. kind, args[index])
            if not ok then return end
            result[#result + 1] = text; cursor = first + #token
        end
    end
    return table.concat(result)
end

local function Plain(text)
    if type(text) ~= "string" then return end
    local prefix, suffix = "", ""
    while text:match("^|c%x%x%x%x%x%x%x%x") do
        prefix = prefix .. text:sub(1, 10); text = text:sub(11)
    end
    while text:sub(-2) == "|r" do suffix = "|r" .. suffix; text = text:sub(1, -3) end
    -- Never rewrite texture, hyperlink, embedded-color or unknown escape layouts.
    if text:find("|", 1, true) then return end
    return text, prefix, suffix
end

local function Link(link)
    if type(link) ~= "string" then return end
    local body = link:match("|Hitem:([^|]+)|h") or link:match("^item:([^|]+)$")
    if not body then return end
    local fields = {}
    for value in (body .. ":"):gmatch("(.-):") do fields[#fields + 1] = value end
    if #fields > 9 or not fields[1] or not fields[1]:match("^%d+$") then return end
    local id = tonumber(fields[1])
    if not Number(id, 1, 16777215, true) then return end
    local level
    if fields[9] and fields[9] ~= "" then
        if not fields[9]:match("^%d+$") then return end
        level = tonumber(fields[9])
        if not Number(level, 0, 255, true) then return end
        if level == 0 then level = nil end
    end
    return id, level
end

local function Point(link, levelOverride)
    local id, level = Link(link)
    if not id or not data[id] then return end
    level = levelOverride or level or (UnitLevel and UnitLevel("player"))
    if not Number(level, 1, 255, true) then return end
    level = math.min(level, 80)
    return data[id][level], level, id
end

local function Font(tooltip, side, line)
    local name = tooltip.GetName and tooltip:GetName()
    return name and _G[name .. "Text" .. side .. line]
end

local function Original(state, font)
    local current = font and font:GetText()
    local previous = font and state.writes[font]
    if previous and current == previous.replacement then return previous.original end
    if font then state.writes[font] = nil end
    return current
end

local function Write(state, font, text)
    if not font or text == nil then return false end
    local original = Original(state, font)
    if original == nil or font:GetText() == text then return false end
    state.writes[font] = {original = original, replacement = text}
    font:SetText(text)
    return true
end

local function Restore(state)
    for font, value in pairs(state.writes) do
        if font:GetText() == value.replacement then font:SetText(value.original) end
    end
    state.writes = {}
end

local function Replace(state, font, expected, replacement)
    if not expected or not replacement or expected == replacement then return false end
    local plain, prefix, suffix = Plain(Original(state, font))
    if plain ~= expected then return false end
    return Write(state, font, prefix .. replacement .. suffix)
end

local function FeralText(value)
    return Format(ITEM_MOD_FERAL_ATTACK_POWER, value)
end

local function TriggerText(template, text)
    if not text or type(template) ~= "string" then return end
    -- This one native wrapper is a string placeholder, unlike numeric templates.
    if template:find("%%s") and not template:gsub("%%s", ""):find("%%") then
        return (template:gsub("%%s", function() return text end))
    elseif not template:find("%%") and not template:find("|", 1, true) then
        -- 3.3.5a GlobalStrings supplies the literal localized "Equip:" prefix.
        return template .. " " .. text
    end
end

local function EquipText(text) return TriggerText(ITEM_SPELL_TRIGGER_ONEQUIP, text) end

local function RewriteUse(tooltip, state, id, level, endLine)
    if (api.revision ~= 9 and api.revision ~= 10) or not id or not level then return false end
    local profile
    for _, candidate in ipairs(useProfiles) do
        if id >= candidate.first and id <= candidate.last then profile = candidate; break end
    end
    if not profile then return false end
    local function amount(base, slope) return base + math.floor((level - 1) * slope) end
    local function range(value) return (value + 1) .. " to " .. value end
    local value = amount(profile.base, profile.perLevel)
    local expected = profile.lead .. range(profile.base)
    local scaled = profile.lead .. range(value)
    local replacement = profile.lead .. value
    if profile.secondBase then
        local second = amount(profile.secondBase, profile.secondPerLevel)
        expected = expected .. profile.between .. range(profile.secondBase)
        scaled = scaled .. profile.between .. range(second)
        replacement = replacement .. profile.between .. second
    end
    expected = TriggerText(ITEM_SPELL_TRIGGER_ONUSE, expected .. profile.tail)
    scaled = TriggerText(ITEM_SPELL_TRIGGER_ONUSE, scaled .. profile.tail)
    replacement = TriggerText(ITEM_SPELL_TRIGGER_ONUSE, replacement .. profile.tail)
    if not expected or not scaled or not replacement then return false end
    local changed = false
    for line = 2, endLine do
        local font = Font(tooltip, "Left", line)
        local plain, prefix, suffix = Plain(Original(state, font))
        local matched = plain and (plain:sub(1, #expected) == expected and expected or
            plain:sub(1, #scaled) == scaled and scaled)
        if matched then
            -- Preserve the native duration/cooldown suffix and green font/markup.
            changed = Write(state, font, prefix .. replacement .. plain:sub(#matched + 1) .. suffix) or changed
        end
    end
    return changed
end

local function RewriteBase(tooltip, state, row, endLine)
    if not row then return false end
    local changed = false
    for line = 2, endLine do
        local font = Font(tooltip, "Left", line)
        if row.armor ~= nil then
            changed = Replace(state, font, Format(ARMOR_TEMPLATE, row.nativeArmor),
                Format(ARMOR_TEMPLATE, row.armor)) or changed
        end
        if row.dps ~= nil then
            changed = Replace(state, font, Format(DAMAGE_TEMPLATE,
                math.floor(row.nativeMinDamage), math.ceil(row.nativeMaxDamage)),
                Format(DAMAGE_TEMPLATE, math.floor(row.minDamage), math.ceil(row.maxDamage))) or changed
            changed = Replace(state, font, Format(DPS_TEMPLATE, row.nativeDps),
                Format(DPS_TEMPLATE, row.dps)) or changed
        end
        if row.feralAp ~= nil then
            local old, new = FeralText(row.nativeFeralAp), FeralText(row.feralAp)
            changed = Replace(state, font, old, new) or changed
            changed = Replace(state, font, EquipText(old), EquipText(new)) or changed
        end
    end
    return changed
end

local function AddMissingFeral(tooltip, state, row, summary)
    if not row or row.nativeFeralAp ~= 0 or not row.feralAp or row.feralAp <= 0 or summary or
        not tooltip.AddLine or not tooltip.GetName or not tooltip:GetName() then return false end
    local _, class = UnitClass("player")
    if class ~= "DRUID" then return false end
    local text = EquipText(FeralText(row.feralAp))
    if not text then return false end
    local added = state.addedFeral
    if added and added.font:GetText() == added.text then
        local changed = Write(state, added.font, text)
        added.text = text
        return changed
    end
    state.addedFeral = nil
    local old, new = FeralText(0), FeralText(row.feralAp)
    for line = 2, tooltip:NumLines() do
        local original = Plain(Original(state, Font(tooltip, "Left", line)))
        if original == old or original == new or original == EquipText(old) or original == text then
            return false
        end
    end
    -- Only the native zero-to-positive Druid component may need a new row.
    -- Append through the native API: never rebuild rows or move money anchors.
    -- Delta-bearing comparison layouts need a verified insertion boundary first.
    tooltip:AddLine(text, 0, 1, 0, true)
    local font = Font(tooltip, "Left", tooltip:NumLines())
    state.writes[font] = {original = "", replacement = text}
    state.addedFeral = {font = font, text = text}
    return true
end

local function Escape(text)
    return text:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
end

local function IsDelta(text, label)
    if not text or type(label) ~= "string" or label == "" then return false end
    local escaped = Escape(label)
    return text:match("^[%+%-]?%d[%d%.,]*%s+" .. escaped .. "$") or
        text:match("^" .. escaped .. ":?%s+[%+%-]?%d[%d%.,]*$")
end

local function SuppressUnknownDeltas(tooltip, state, startLine, first, second)
    local changed, labels = false, {}
    if (first and first.armor ~= nil) or (second and second.armor ~= nil) then
        labels[#labels + 1] = ARMOR or RESISTANCE0_NAME
    end
    if (first and first.dps ~= nil) or (second and second.dps ~= nil) then
        labels[#labels + 1] = ITEM_MOD_DAMAGE_PER_SECOND_SHORT
    end
    if (first and first.feralAp ~= nil) or (second and second.feralAp ~= nil) then
        labels[#labels + 1] = ITEM_MOD_FERAL_ATTACK_POWER_SHORT
    end
    for line = startLine + 1, tooltip:NumLines() do
        local left, right = Font(tooltip, "Left", line), Font(tooltip, "Right", line)
        local ltext, rtext = Plain(Original(state, left)), Plain(Original(state, right))
        for _, label in ipairs(labels) do
            if IsDelta(ltext, label) then changed = Write(state, left, "") or changed
            elseif IsDelta(rtext, label) then changed = Write(state, right, "") or changed
            elseif ltext == label and rtext and rtext:match("^[%+%-]?%d[%d%.,]*$") then
                changed = Write(state, left, "") or changed
                changed = Write(state, right, "") or changed
            end
        end
    end
    return changed
end

local function Refresh(tooltip)
    local state = states[tooltip]
    if not active or not state or state.busy or not tooltip.GetItem then return end
    state.busy = true
    local _, link = tooltip:GetItem()
    local row, level, id = Point(link)
    local context = state.context
    local candidate = context and context.compareLink and Point(context.compareLink)
    local summary, count = nil, tooltip:NumLines() or 0
    for line = 2, count do
        local text = Plain(Original(state, Font(tooltip, "Left", line)))
        if ITEM_DELTA_DESCRIPTION and text == ITEM_DELTA_DESCRIPTION then summary = line; break end
    end
    local changed = RewriteBase(tooltip, state, row, (summary or count + 1) - 1)
    changed = RewriteUse(tooltip, state, id, level, (summary or count + 1) - 1) or changed
    changed = AddMissingFeral(tooltip, state, row, summary) or changed
    if summary then changed = SuppressUnknownDeltas(tooltip, state, summary, row, candidate) or changed end
    if changed and tooltip:IsShown() then tooltip:Show() end
    state.busy = false
end

function api.Attach(tooltip)
    if not tooltip or states[tooltip] then return end
    local state = {writes = {}}
    states[tooltip] = state; frames[#frames + 1] = tooltip
    tooltip:HookScript("OnTooltipCleared", function()
        state.writes = {}; state.context = nil; state.lastLink = nil; state.addedFeral = nil
    end)
    tooltip:HookScript("OnTooltipSetItem", function(self)
        local _, link = self:GetItem()
        if state.lastLink ~= link then state.writes = {}; state.context = nil; state.addedFeral = nil end
        state.lastLink = link
        Refresh(self)
    end)
    for _, method in ipairs({"SetBagItem", "SetInventoryItem", "SetMerchantItem", "SetBuybackItem",
        "SetQuestItem", "SetQuestLogItem", "SetLootItem", "SetTradePlayerItem", "SetTradeTargetItem",
        "SetInboxItem", "SetSendMailItem", "SetAuctionItem", "SetHyperlink", "SetHyperlinkCompareItem"}) do
        if tooltip[method] then
            local setter = method
            hooksecurefunc(tooltip, setter, function(self, ...)
                local args = {...}
                state.context = {method = setter, args = args, count = select("#", ...),
                    compareLink = setter == "SetHyperlinkCompareItem" and args[1] or nil}
                Refresh(self)
            end)
        end
    end
end

for _, name in ipairs({"GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "ShoppingTooltip3",
    "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2", "ItemRefShoppingTooltip3"}) do api.Attach(_G[name]) end

local eventFrame = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_LEVEL_UP",
    "GET_ITEM_INFO_RECEIVED", "PLAYER_EQUIPMENT_CHANGED", "UNIT_INVENTORY_CHANGED"}) do eventFrame:RegisterEvent(event) end
eventFrame:SetScript("OnEvent", function(self, event, unit)
    if event == "UNIT_INVENTORY_CHANGED" and unit ~= "player" then return end
    active = GetRealmName and GetRealmName() == "Rebirth"
    if not active then
        for _, state in pairs(states) do Restore(state) end
        refreshPending = false
        return
    end
    refreshPending = true -- native player level/cache must settle before rerender
end)
eventFrame:SetScript("OnUpdate", function()
    if not refreshPending or not active then return end
    refreshPending = false
    for _, tooltip in ipairs(frames) do
        if tooltip:IsShown() then
            local state, context = states[tooltip], states[tooltip].context
            if context and not state.busy then
                -- Repopulate through the captured native setter, rather than
                -- recomputing SSD stats, proc text, money or comparison operands.
                tooltip[context.method](tooltip, unpack(context.args, 1, context.count))
            else Refresh(tooltip) end
        end
    end
end)
