local addonName, PS = ...
PS = PS or {}
ProjectSkillful = PS
PS.version = "0.12.1"
PS.protocolVersion = 3
PS.debug = false
PS.state = PS.state or { skills = {} }
PS.state.resources = PS.state.resources or {
    mana = { current = 0, max = 0 },
    rage = { current = 0, max = 0 },
    energy = { current = 0, max = 0 },
}
if PS.state.resourceSnapshotReceived == nil then PS.state.resourceSnapshotReceived = false end
if PS.state.heroResourcesEnabled == nil then PS.state.heroResourcesEnabled = false end

local PREFIX = "PSKILL"
local ICONS = "Interface\\Icons\\"
local POWER_MANA = 0
local POWER_RAGE = 1
local POWER_ENERGY = 3
local SERVER_SKILL_COUNT = 22

-- The skills window portrait and its menu bar button share one identity icon.
local SKILLS_ICON = "INV_Misc_Book_11"

-- The client's own words and colours. SKILLS is read from _G explicitly because this file's
-- local SKILLS table (the catalog) shadows the global string.
local SKILLS_TITLE = type(_G.SKILLS) == "string" and _G.SKILLS or "Skills"
local GOLD = NORMAL_FONT_COLOR and { NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b } or { 1, 0.82, 0 }

-- One column per catalog family, which is more readable than interleaving them and mirrors
-- foundation specification 1.2. Display order is deliberately not ID order.
-- Icons are stock WoW art: the Trade_* set is what WoW itself uses for these professions.
local FAMILIES = {
    {
        title = "Combat",
        skills = {
            { 1, "Attack", "Ability_MeleeDamage" },
            { 2, "Strength", "Spell_Nature_Strength" },
            { 3, "Defence", "Ability_Warrior_DefensiveStance" },
            { 4, "Vitality", "INV_Misc_Organ_01" },
            { 5, "Ranged", "Ability_Marksmanship" },
            { 6, "Magic", "Spell_Holy_MagicalSentry" },
            { 7, "Devotion", "Spell_Holy_HolyGuidance" },
        },
    },
    {
        title = "Gathering",
        skills = {
            { 100, "Mining", "Trade_Mining" },
            { 101, "Herbalism", "Trade_Herbalism" },
            { 102, "Skinning", "INV_Misc_Pelt_Wolf_01" },
            { 103, "Fishing", "Trade_Fishing" },
            { 104, "Lumbering", "INV_Axe_11" },
        },
    },
    {
        title = "Artisan",
        skills = {
            { 200, "Blacksmithing", "Trade_BlackSmithing" },
            { 201, "Cooking", "INV_Misc_Food_15" },
            { 202, "Alchemy", "Trade_Alchemy" },
            { 203, "Tailoring", "Trade_Tailoring" },
            { 204, "Leatherworking", "Trade_LeatherWorking" },
            { 205, "Enchanting", "Trade_Engraving" },
            { 206, "Engineering", "Trade_Engineering" },
            { 207, "Inscription", "INV_Inscription_Tradeskill01" },
            { 208, "Jewelcrafting", "INV_Misc_Gem_01" },
            { 209, "First Aid", "INV_Misc_Bandage_08" },
            { 210, "Fletching", "INV_Weapon_Bow_07", true },
            { 211, "Runecraft", "INV_Misc_Rune_06", true },
            { 212, "Construction", "INV_Hammer_15", true },
            { 213, "Firemaking", "INV_Torch_Lit", true },
        },
    },
    {
        title = "Activity",
        skills = {
            { 300, "Thieving", "Ability_Rogue_Disguise", true },
            { 301, "Slayer", "Ability_Hunter_SniperShot", true },
            { 302, "Dungeoneering", "INV_Misc_Key_04", true },
            { 303, "Summoning", "Spell_Nature_SpiritWolf", true },
        },
    },
}

-- Flat list preserved for lookups and refresh; existing code indexes [1] and [2] unchanged.
local SKILLS = {}
for _, family in ipairs(FAMILIES) do
    for _, definition in ipairs(family.skills) do
        table.insert(SKILLS, definition)
    end
end
local TRAINING_BY_STYLE = {
    melee = {
        { 1, "Attack", "Interface\\Icons\\Ability_MeleeDamage" },
        { 2, "Strength", "Interface\\Icons\\Spell_Nature_Strength" },
        { 4, "Defence", "Interface\\Icons\\Ability_Warrior_DefensiveStance" },
    },
    ranged = {
        { 1, "Ranged", "Interface\\Icons\\Ability_Marksmanship" },
        { 2, "Defence", "Interface\\Icons\\Ability_Warrior_DefensiveStance" },
    },
    magic = {
        { 1, "Magic", "Interface\\Icons\\Spell_Holy_MagicalSentry" },
        { 2, "Defence", "Interface\\Icons\\Ability_Warrior_DefensiveStance" },
    },
}

-- The equipped weapon decides the style; these name and picture it on the Combat tab.
local STYLE_PRESENTATION = {
    melee = { "Melee", "INV_Sword_04" },
    ranged = { "Ranged", "INV_Weapon_Bow_05" },
    magic = { "Magic", "INV_Wand_07" },
}

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cffd8b45aProject Skillful|r: " .. tostring(message))
end

local function Comma(value)
    local formatted = tostring(math.floor(tonumber(value) or 0))
    while true do
        local changed
        formatted, changed = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
        if changed == 0 then return formatted end
    end
end

local function SkillName(skillId)
    for _, definition in ipairs(SKILLS) do
        if definition[1] == skillId then return definition[2] end
    end
    return "Skill " .. tostring(skillId)
end

local function SkillDefinition(skillId)
    for _, definition in ipairs(SKILLS) do
        if definition[1] == skillId then return definition end
    end
end

local function SkillIdByName(name)
    for _, definition in ipairs(SKILLS) do
        if definition[2] == name then return definition[1] end
    end
end

local PROFESSION_ACTIONS = {
    [100] = "Smelting", [101] = "Herbalism", [102] = "Skinning", [103] = "Fishing",
    [200] = "Blacksmithing", [201] = "Cooking", [202] = "Alchemy", [203] = "Tailoring",
    [204] = "Leatherworking", [205] = "Enchanting", [206] = "Engineering",
    [207] = "Inscription", [208] = "Jewelcrafting", [209] = "First Aid",
}

local function SelectionIncludes(selection, bit)
    return math.fmod(math.floor((tonumber(selection) or 0) / bit), 2) >= 1
end

local function SelectionNames(style, selection)
    local names = {}
    local training = TRAINING_BY_STYLE[style or "melee"] or TRAINING_BY_STYLE.melee
    for _, definition in ipairs(training) do
        if SelectionIncludes(selection, definition[1]) then table.insert(names, definition[2]) end
    end
    return names
end

local function SelectionText(style, selection)
    return table.concat(SelectionNames(style, selection), " / ")
end

-- "Attack", "Attack and Strength", "Attack, Strength and Defence" — how the game itself
-- phrases a list in a sentence.
local function NaturalList(names)
    local count = table.getn(names)
    if count <= 1 then return names[1] or "" end
    return table.concat(names, ", ", 1, count - 1) .. " and " .. names[count]
end

local function ActiveSelection()
    local style = PS.state.equippedStyle or "melee"
    local selections = PS.state.selections or {}
    return tonumber(selections[style]) or (style == "melee" and tonumber(PS.state.selection)) or 1
end

local function LastGainText()
    if not PS.state.lastGains then return "Last XP gain: none this session" end
    local gains = {}
    for _, definition in ipairs(SKILLS) do
        local amount = PS.state.lastGains[definition[1]]
        if amount and amount > 0 then
            table.insert(gains, definition[2] .. " +" .. Comma(amount))
        end
    end
    if table.getn(gains) == 0 then return "Last XP gain: none this session" end
    return "Last XP gain: " .. table.concat(gains, "   •   ")
end

local function KnownLevel(skillId, fallback)
    local skill = PS.state.skills and PS.state.skills[skillId]
    return (skill and tonumber(skill.level)) or fallback or 1
end

local function TotalLevel()
    local total, known = 0, 0
    for _, definition in ipairs(SKILLS) do
        local skill = PS.state.skills[definition[1]]
        if skill then
            total = total + (tonumber(skill.level) or 0)
            known = known + 1
        end
    end
    return total, known
end

-- Calls a stock UI function only when this client defines it. Every Blizzard global the addon
-- leans on goes through here or an explicit check, so a missing one degrades instead of erroring.
local function CallGlobal(name, ...)
    local fn = _G[name]
    if type(fn) == "function" then return fn(...) end
end

local function HookGlobal(name, hook)
    if type(_G[name]) == "function" and hooksecurefunc then hooksecurefunc(name, hook) end
end

---------------------------------------------------------------------------------------------------
-- Chat and on-screen messages, worded and coloured the way the stock client words its own.
---------------------------------------------------------------------------------------------------

local CHAT_FALLBACK_COLORS = {
    COMBAT_XP_GAIN = { 0.44, 0.44, 1.00 },
    SKILL = { 0.33, 0.33, 1.00 },
    SYSTEM = { 1.00, 1.00, 0.00 },
}

-- Routes a message to every chat window showing that message group, in the player's configured
-- colour for it — so experience lines land wherever the player reads "You gain 120 experience."
-- If the player has turned a group off everywhere, the message stays off, as it would natively.
local function AddGameMessage(group, text)
    local fallback = CHAT_FALLBACK_COLORS[group] or { 1, 1, 1 }
    local red, green, blue = fallback[1], fallback[2], fallback[3]
    local info = ChatTypeInfo and ChatTypeInfo[group]
    if info and info.r then red, green, blue = info.r, info.g, info.b end

    local routed = false
    for index = 1, (tonumber(NUM_CHAT_WINDOWS) or 0) do
        local chatFrame = _G["ChatFrame" .. index]
        if chatFrame and chatFrame.messageTypeList then
            routed = true
            for _, messageType in ipairs(chatFrame.messageTypeList) do
                if messageType == group then
                    chatFrame:AddMessage(text, red, green, blue)
                    break
                end
            end
        end
    end
    if not routed and DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(text, red, green, blue) end
end

local function ShowErrorMessage(text)
    if UIErrorsFrame then
        UIErrorsFrame:AddMessage(text, 1.0, 0.1, 0.1, 1.0)
    else
        Print(text)
    end
end

local function PlayUISound(sound)
    if PlaySound then PlaySound(sound) end
end

---------------------------------------------------------------------------------------------------
-- Hero resource bars. Mana takes the stock power bar's exact slot in the player frame; Rage and
-- Energy hang beneath it in the art WoW uses for a druid's mana bar while shapeshifted.
---------------------------------------------------------------------------------------------------

local RESOURCE_DEFINITIONS = {
    { "mana", "Mana", 0.00, 0.00, 1.00, POWER_MANA, 1, "MANA" },
    -- UnitPower(player, 1) is the client-facing Rage point value. The server
    -- converts Wrath's internal units when it builds the R row; the addon
    -- must not divide indexed native values a second time.
    { "rage", "Rage", 1.00, 0.00, 0.00, POWER_RAGE, 1, "RAGE" },
    { "energy", "Energy", 1.00, 1.00, 0.00, POWER_ENERGY, 1, "ENERGY" },
}

local function ResourceText(key)
    local resource = PS.state.resources and PS.state.resources[key]
    local maximum = resource and tonumber(resource.max) or 0
    if maximum > 0 then
        return tostring(math.floor(tonumber(resource.current) or 0)) .. " / " .. tostring(math.floor(maximum))
    end
    return "—"
end

local function ReadNativePower(power, scale)
    local current, maximum
    if UnitPower then current = UnitPower("player", power) end
    if UnitPowerMax then maximum = UnitPowerMax("player", power) end

    -- These fallbacks keep the dock usable on clients that expose the older
    -- named power functions but not the indexed UnitPower API.
    if current == nil then
        if power == POWER_MANA and UnitMana then current = UnitMana("player") end
        if power == POWER_RAGE and UnitRage then current = UnitRage("player") end
        if power == POWER_ENERGY and UnitEnergy then current = UnitEnergy("player") end
    end
    if maximum == nil then
        if power == POWER_MANA and UnitManaMax then maximum = UnitManaMax("player") end
        if power == POWER_RAGE and UnitRageMax then maximum = UnitRageMax("player") end
        if power == POWER_ENERGY and UnitEnergyMax then maximum = UnitEnergyMax("player") end
    end
    if current == nil or maximum == nil then return nil end

    scale = scale or 1
    return {
        current = math.floor((tonumber(current) or 0) / scale),
        max = math.floor((tonumber(maximum) or 0) / scale),
    }
end

local function RefreshNativeResources()
    -- Native fields are only a short-lived fallback while login waits for the
    -- authoritative R row. Deferred native Warrior Rage/Energy mechanics must
    -- not overwrite the Project Skillful resource contract afterward.
    if PS.state.resourceSnapshotReceived then return end
    for _, definition in ipairs(RESOURCE_DEFINITIONS) do
        local key, _, _, _, _, power, scale = unpack(definition)
        local native = ReadNativePower(power, scale)
        if native and native.max > 0 then
            PS.state.resources[key] = native
        end
    end
end

local function SuppressNativePowerBar()
    -- Technical class 1 makes the stock PlayerFrame power bar a single Rage
    -- bar. The Hero bars replace it; the health bar remains untouched.
    local native = PlayerFrameManaBar
    if native then
        native.projectSkillfulHiddenByAddon = true
        native:Hide()
        if not native.projectSkillfulSuppressed then
            native:HookScript("OnShow", function(self)
                if PS.state.heroResourcesEnabled then self:Hide() end
            end)
            native.projectSkillfulSuppressed = true
        end
    end
    -- The stock text for that bar lives on the frame's border art, not on the bar, so it has to
    -- be hidden separately or it would print Rage numbers over the Hero Mana bar.
    if PlayerFrameManaBarText then PlayerFrameManaBarText:SetAlpha(0) end
end

local function RestoreNativePowerBar()
    local native = PlayerFrameManaBar
    if native and native.projectSkillfulHiddenByAddon then
        native.projectSkillfulHiddenByAddon = false
        native:Show()
    end
    if PlayerFrameManaBarText then PlayerFrameManaBarText:SetAlpha(1) end
end

local function CreateResourceBar(dock, definition)
    local key, label, red, green, blue = definition[1], definition[2], definition[3], definition[4], definition[5]
    local token = definition[8]
    local color = PowerBarColor and PowerBarColor[token]
    if color then red, green, blue = color.r, color.g, color.b end

    -- Inheriting TextStatusBar gives the stock behaviour for free: numbers on hover, or always
    -- when "Status Text" is enabled in Interface Options, and a percentage when that is chosen.
    local bar = CreateFrame("StatusBar", "ProjectSkillful" .. label .. "Bar", dock, "TextStatusBar")
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(red, green, blue)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)

    local text = bar:CreateFontString("ProjectSkillful" .. label .. "BarText", "OVERLAY", "TextStatusBarText")
    text:SetPoint("CENTER", bar, "CENTER", 0, 0)
    bar.TextString = text
    bar.textLockable = 1
    bar.cvar = "playerStatusText"
    bar.cvarLabel = "STATUS_TEXT_PLAYER"
    bar.lockShow = bar.lockShow or 0
    bar.alwaysShow = 1
    bar.tooltipTitle = _G[token] or label
    bar.resourceKey = key
    return bar
end

local function AddAlternateBarArt(bar)
    -- Same dimensions and art as PlayerFrameAlternateManaBar (AlternatePowerBar.xml).
    bar:SetWidth(78)
    bar:SetHeight(12)
    local background = bar:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(bar)
    background:SetTexture(0, 0, 0, 0.5)
    local border = bar:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\CharacterFrame\\UI-CharacterFrame-GroupIndicator")
    border:SetWidth(97)
    border:SetHeight(16)
    border:SetPoint("TOPLEFT", bar, "TOPLEFT", -10, 0)
    border:SetTexCoord(0.0234375, 0.6875, 1.0, 0.0)
    -- Hovering shows the numbers, as it does on the stock druid bar this art comes from.
    bar:EnableMouse(true)
end

local function ShowResourceText(show)
    local dock = PS.resourceDock
    if not dock or not dock:IsShown() then return end
    for _, bar in pairs(dock.resourceBars) do
        if show then CallGlobal("ShowTextStatusBarText", bar) else CallGlobal("HideTextStatusBarText", bar) end
    end
end

local function AnchorResourceDock()
    local dock = PS.resourceDock
    if not dock then return end
    local bars = dock.resourceBars
    local parent = PlayerFrame or UIParent
    if dock:GetParent() ~= parent then dock:SetParent(parent) end
    dock:ClearAllPoints()
    dock:SetAllPoints(parent)
    -- Sit exactly where the stock power bar sits: same level, so the frame's border art stays on top.
    -- Set each bar directly; a child's level does not reliably follow a later change to its parent's.
    if PlayerFrameManaBar and PlayerFrameManaBar.GetFrameLevel then
        local level = PlayerFrameManaBar:GetFrameLevel()
        dock:SetFrameLevel(math.max(0, level - 1))
        for _, bar in pairs(bars) do bar:SetFrameLevel(level) end
    end

    bars.mana:ClearAllPoints()
    bars.rage:ClearAllPoints()
    bars.energy:ClearAllPoints()
    if PlayerFrame then
        bars.mana:SetPoint("TOPLEFT", PlayerFrame, "TOPLEFT", 106, -52)
        bars.rage:SetPoint("BOTTOMLEFT", PlayerFrame, "BOTTOMLEFT", 114, 23)
    else
        bars.mana:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 87, -56)
        bars.rage:SetPoint("TOPLEFT", bars.mana, "BOTTOMLEFT", 8, -8)
    end
    bars.energy:SetPoint("TOPLEFT", bars.rage, "BOTTOMLEFT", 0, -5)
end

local function CreateResourceDock()
    if PS.resourceDock then
        AnchorResourceDock()
        return PS.resourceDock
    end

    local dock = CreateFrame("Frame", "ProjectSkillfulResourceDock", PlayerFrame or UIParent)
    dock.resourceBars = {}
    for _, definition in ipairs(RESOURCE_DEFINITIONS) do
        dock.resourceBars[definition[1]] = CreateResourceBar(dock, definition)
    end

    -- Mana replaces the stock bar in place: same size, and it lets clicks through to the player
    -- frame as the original does, so clicking it still targets yourself.
    local mana = dock.resourceBars.mana
    mana:SetWidth(119)
    mana:SetHeight(12)
    mana:EnableMouse(false)
    AddAlternateBarArt(dock.resourceBars.rage)
    AddAlternateBarArt(dock.resourceBars.energy)

    -- Hovering the player frame reveals every bar's numbers together, as it does for the stock bars.
    if PlayerFrame and PlayerFrame.HookScript then
        PlayerFrame:HookScript("OnEnter", function() ShowResourceText(true) end)
        PlayerFrame:HookScript("OnLeave", function() ShowResourceText(false) end)
    end

    dock:Hide()
    PS.resourceDock = dock
    AnchorResourceDock()
    return dock
end

local function RefreshResourceDock()
    local dock = CreateResourceDock()
    for _, definition in ipairs(RESOURCE_DEFINITIONS) do
        local key = definition[1]
        local resource = PS.state.resources and PS.state.resources[key]
        local current = math.floor(tonumber(resource and resource.current) or 0)
        local maximum = math.floor(tonumber(resource and resource.max) or 0)
        local bar = dock.resourceBars[key]
        if maximum > 0 then
            bar:SetMinMaxValues(0, maximum)
            bar:SetValue(math.min(current, maximum))
        else
            bar:SetMinMaxValues(0, 1)
            bar:SetValue(0)
        end
        CallGlobal("TextStatusBar_UpdateTextString", bar)
    end
    if PS.state.heroResourcesEnabled then
        dock:Show()
        SuppressNativePowerBar()
    else
        dock:Hide()
        RestoreNativePowerBar()
    end
end

---------------------------------------------------------------------------------------------------
-- Character sheet. The stock attribute panel stays — its two stat columns, their backing art, and
-- their tooltips — and carries Hero values instead of the class stats a Hero does not use.
---------------------------------------------------------------------------------------------------

local function SkillTooltipLines(tooltip, skillId, planned)
    local skill = PS.state.skills[skillId]
    if skill then
        tooltip:AddLine("Level " .. skill.level, 1, 1, 1)
        tooltip:AddLine(Comma(skill.xp) .. " experience", GOLD[1], GOLD[2], GOLD[3])
        if skill.level < 100 and skill.nextXp and skill.nextXp > skill.xp then
            tooltip:AddLine(Comma(skill.nextXp - skill.xp) .. " experience to level " .. (skill.level + 1), 1, 1, 1)
        end
    elseif planned then
        tooltip:AddLine("Not yet available", 0.5, 0.5, 0.5)
    else
        tooltip:AddLine("Waiting for the server", 0.5, 0.5, 0.5)
    end
end

local HERO_STAT_ROWS = {
    left = {
        { skill = 1 }, { skill = 2 }, { skill = 3 },
        { skill = 5 }, { skill = 6 }, { skill = 7 },
    },
    right = {
        { skill = 4 },
        { label = "Health", value = function()
            return UnitHealthMax and tostring(UnitHealthMax("player") or 0) or "—"
        end, tooltip = "Maximum health" },
        { label = "Mana", value = function() return ResourceText("mana") end, tooltip = "Mana" },
        { label = "Rage", value = function() return ResourceText("rage") end, tooltip = "Rage" },
        { label = "Energy", value = function() return ResourceText("energy") end, tooltip = "Energy" },
        { label = "Style", value = function()
            local presentation = STYLE_PRESENTATION[PS.state.equippedStyle or "melee"]
            return presentation and presentation[1] or "—"
        end, tooltip = "Combat style" },
    },
}

local COMBAT_SKILL_HELP = {
    [1] = "Attack works with equipment Accuracy to improve your melee hit chance.",
    [2] = "Strength works with equipment Power to increase your melee damage potential.",
    [3] = "Defence works with the matching equipment defense bonus to make enemy attacks less likely to hit. It does not subtract damage from a successful hit.",
    [5] = "Ranged works with equipment Accuracy and Power for ranged hit chance and damage potential.",
}

local EQUIPMENT_BONUS_ROWS = {
    {key="accuracy",label="Accuracy",top=99,
        help="Improves hit chance for your equipped combat style. These are bonus points, not a hit percentage."},
    {key="power",label="Power",top=121,
        help="Increases damage potential with Strength for melee or Ranged for ranged attacks. These points are not damage added to each hit."},
    {index=1,label="Pierce",top=175,
        help="Works with Defence to make piercing attacks less likely to hit. Northshire wolves and mine spiders use this style."},
    {index=2,label="Slash",top=197,
        help="Works with Defence to make slashing attacks less likely to hit. Defias Thugs and Garrick Padfoot use this style."},
    {index=3,label="Crush",top=219,
        help="Works with Defence to make crushing attacks less likely to hit. Northshire kobolds use this style."},
    {index=4,label="Ranged",top=241,
        help="Defense bonus for ranged attacks. The current Northshire test enemies use melee, so this bonus has no effect against them."},
    {index=5,label="Magic",top=263,
        help="Defense bonus for magic attacks. The current Northshire test enemies use melee; this does not provide general WoW spell resistance."},
}

local function BonusScopeTooltip()
    GameTooltip:AddLine("Northshire test creatures only.",GOLD[1],GOLD[2],GOLD[3],true)
    local loadout = PS.ItemBalanceLoadout and PS.ItemBalanceLoadout()
    if not loadout then
        GameTooltip:AddLine("Waiting for confirmed equipment totals from the server.",0.7,0.7,0.7,true)
    elseif not loadout.active then
        GameTooltip:AddLine("This loadout cannot use the Northshire item rebalance. Unsupported equipment, enchants or combat styles can cause this. Existing combat rules apply.",1,0.65,0.2,true)
    else
        GameTooltip:AddLine("Equipped bonuses are added, capped and rounded by the server. These are the effective whole-point totals; an item's small decimal bonus may not change a total on its own.",1,1,1,true)
    end
end

PS.RefreshEquipmentBonuses = function()
    local panel = PS.equipmentBonusPanel
    if not panel then return end
    local loadout = PS.ItemBalanceLoadout and PS.ItemBalanceLoadout()
    local style = PS.state.equippedStyle or "melee"
    local styleName = ({melee="Melee",ranged="Ranged",magic="Magic"})[style] or "Current style"
    panel.offense:SetText(styleName .. " offense")
    if not loadout then
        panel.status:SetText("Waiting for server")
        panel.status:SetTextColor(0.7,0.7,0.7)
    elseif not loadout.active then
        panel.status:SetText("Inactive for this loadout")
        panel.status:SetTextColor(1,0.65,0.2)
    else
        panel.status:SetText("Active: " .. styleName)
        panel.status:SetTextColor(0.2,1,0.2)
    end
    for index, definition in ipairs(EQUIPMENT_BONUS_ROWS) do
        local amount = loadout and loadout.active and
            (definition.key and loadout[definition.key] or loadout.defence[definition.index])
        panel.rows[index].value:SetText(amount and ("+" .. amount) or "—")
    end
end

local function CreateEquipmentBonusPanel()
    if PS.equipmentBonusPanel or not CharacterFrame then return end
    local parent = PaperDollFrame or CharacterFrame
    local panel = CreateFrame("Frame","ProjectSkillfulEquipmentBonuses",parent)
    panel:SetWidth(256); panel:SetHeight(340)
    panel:SetPoint("TOPLEFT",CharacterFrame,"TOPRIGHT",8,-36)
    panel:SetFrameLevel(parent:GetFrameLevel()+1)
    panel:SetBackdrop({edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=16,
        insets={left=4,right=4,top=4,bottom=4}})
    panel:SetBackdropBorderColor(0.6,0.6,0.66,1)
    local fill = panel:CreateTexture(nil,"BACKGROUND")
    fill:SetPoint("TOPLEFT",panel,"TOPLEFT",4,-4)
    fill:SetPoint("BOTTOMRIGHT",panel,"BOTTOMRIGHT",-4,4)
    fill:SetTexture(0.025,0.03,0.09,1)
    local function Text(name,template,x,y,text)
        local font = panel:CreateFontString(name,"OVERLAY",template)
        font:SetPoint("TOPLEFT",panel,"TOPLEFT",x,y)
        font:SetText(text); return font
    end
    Text(nil,"GameFontNormal",14,-14,"Equipment Bonuses")
    panel.status = Text("ProjectSkillfulEquipmentBonusStatus","GameFontHighlightSmall",14,-36,"")
    Text(nil,"GameFontDisableSmall",14,-54,"Northshire test creatures only")
    panel.offense = Text(nil,"GameFontNormalSmall",14,-79,"")
    Text(nil,"GameFontNormalSmall",14,-155,"Defense bonuses")
    local summary = CreateFrame("Frame",nil,panel)
    summary:SetPoint("TOPLEFT",panel,"TOPLEFT",10,-32)
    summary:SetWidth(236); summary:SetHeight(36); summary:EnableMouse(true)
    summary:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
        GameTooltip:SetText("Equipment bonuses",1,1,1)
        BonusScopeTooltip(); GameTooltip:Show()
    end)
    summary:SetScript("OnLeave",function() GameTooltip:Hide() end)
    summary:Show()
    panel.rows = {}
    for index, definition in ipairs(EQUIPMENT_BONUS_ROWS) do
        local row = CreateFrame("Frame","ProjectSkillfulEquipmentBonus" .. definition.label,panel)
        row:SetPoint("TOPLEFT",panel,"TOPLEFT",14,-definition.top)
        row:SetWidth(228); row:SetHeight(18); row:EnableMouse(true)
        row.label = row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        row.label:SetPoint("LEFT",row,"LEFT",0,0); row.label:SetText(definition.label)
        row.value = row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        row.value:SetPoint("RIGHT",row,"RIGHT",0,0)
        row:SetScript("OnEnter",function(self)
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
            GameTooltip:SetText(definition.label .. (definition.index and " Defense" or ""),1,1,1)
            GameTooltip:AddLine(definition.help,1,1,1,true)
            if definition.index then
                GameTooltip:AddLine("Defense changes hit chance, not damage taken per successful hit.",1,1,1,true)
            elseif PS.state.equippedStyle == "magic" then
                GameTooltip:AddLine("Magic equipment totals are not supported in this slice.",0.7,0.7,0.7,true)
            else
                local skillId = PS.state.equippedStyle == "ranged" and 5 or (definition.key == "accuracy" and 1 or 2)
                local skill = PS.state.skills[skillId]
                GameTooltip:AddLine("Uses " .. SkillName(skillId) .. " level " ..
                    (skill and skill.level or "—"),GOLD[1],GOLD[2],GOLD[3])
            end
            BonusScopeTooltip(); GameTooltip:Show()
        end)
        row:SetScript("OnLeave",function() GameTooltip:Hide() end)
        row:Show()
        panel.rows[index] = row
    end
    local footer = panel:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
    footer:SetPoint("BOTTOMLEFT",panel,"BOTTOMLEFT",14,15)
    footer:SetWidth(228); footer:SetHeight(36); footer:SetJustifyH("LEFT")
    footer:SetText("Rounded equipment points.\nHover a stat to learn its effect.")
    PS.equipmentBonusPanel = panel
    panel:SetScript("OnHide",function()
        local owner = GameTooltip:GetOwner()
        if owner and owner:GetParent() == panel then GameTooltip:Hide() end
    end)
    parent:HookScript("OnShow",PS.RefreshEquipmentBonuses)
    PS.RefreshEquipmentBonuses(); panel:Show()
end

local function HeroStatTooltip(self)
    local row = self.projectSkillfulRow
    if not row then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if row.skill then
        GameTooltip:SetText(SkillName(row.skill), 1, 1, 1)
        SkillTooltipLines(GameTooltip, row.skill)
        if COMBAT_SKILL_HELP[row.skill] then
            GameTooltip:AddLine(COMBAT_SKILL_HELP[row.skill],1,1,1,true)
        end
    else
        GameTooltip:SetText(row.tooltip or row.label, 1, 1, 1)
        if row.label == "Style" then
            local names = SelectionNames(PS.state.equippedStyle, ActiveSelection())
            if table.getn(names) > 0 then
                GameTooltip:AddLine("Training " .. NaturalList(names), GOLD[1], GOLD[2], GOLD[3])
            end
            GameTooltip:AddLine("Set by your equipped weapon.", 1, 1, 1, true)
        end
    end
    GameTooltip:Show()
end

local function FillHeroStatColumn(prefix, rows)
    for index, row in ipairs(rows) do
        local statFrame = _G[prefix .. index]
        local label = _G[prefix .. index .. "Label"]
        local value = _G[prefix .. index .. "StatText"]
        if statFrame and label and value then
            if row.skill then
                label:SetText(SkillName(row.skill) .. ":")
                local skill = PS.state.skills[row.skill]
                value:SetText(skill and tostring(skill.level) or "—")
            else
                label:SetText(row.label .. ":")
                value:SetText(row.value())
            end
            statFrame.projectSkillfulRow = row
            statFrame:SetScript("OnEnter", HeroStatTooltip)
            statFrame:Show()
        end
    end
end

local function ApplyHeroCharacterSheet()
    PS.RefreshEquipmentBonuses()
    if not PlayerStatFrameLeft1 then return end
    FillHeroStatColumn("PlayerStatFrameLeft", HERO_STAT_ROWS.left)
    FillHeroStatColumn("PlayerStatFrameRight", HERO_STAT_ROWS.right)

    if CharacterLevelText then
        local raceName = UnitRace and UnitRace("player") or nil
        CharacterLevelText:SetText("Level " .. (tonumber(PS.state.combatLevel) or 3) ..
            (raceName and raceName ~= "" and (" " .. raceName) or "") .. " Hero")
    end
end

local function RefreshHeroPaperDoll()
    PS.RefreshEquipmentBonuses()
    if CharacterFrame and CharacterFrame:IsShown() then ApplyHeroCharacterSheet() end
end

local function CustomizeHeroPaperDoll()
    if PS.paperDollCustomized or not CharacterAttributesFrame then return end
    PS.paperDollCustomized = true
    CreateEquipmentBonusPanel()

    -- The stat-category dropdowns choose between class stat pages a Hero does not have. Each
    -- column gets a fixed heading in the dropdown's place instead.
    local headings = {
        { "PlayerStatFrameLeftDropDown", "PlayerStatLeftTop", "Combat Skills" },
        { "PlayerStatFrameRightDropDown", "PlayerStatRightTop", "Hero" },
    }
    for _, heading in ipairs(headings) do
        local dropDown = _G[heading[1]]
        if dropDown then
            dropDown:Hide()
            dropDown:HookScript("OnShow", function(self) self:Hide() end)
        end
        local anchor = _G[heading[2]]
        if anchor then
            local text = CharacterAttributesFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            text:SetPoint("BOTTOM", anchor, "TOP", 0, 3)
            text:SetText(heading[3])
        end
    end

    -- Blizzard rewrites these rows whenever stats or equipment change; re-apply straight after.
    HookGlobal("UpdatePaperdollStats", ApplyHeroCharacterSheet)
    HookGlobal("PaperDollFrame_SetLevel", ApplyHeroCharacterSheet)
    ApplyHeroCharacterSheet()
end

---------------------------------------------------------------------------------------------------
-- The Skills window: a standard left-docked panel in the character frame's own art, with a Skills
-- tab (every skill, spellbook-style) and a Combat tab (style and experience training).
---------------------------------------------------------------------------------------------------

local PANEL_ART = "Interface\\PaperDollInfoFrame\\"
-- OSRS-style skill tiles: three columns of recessed tiles, icon left, level as two stacked numbers.
local GRID_COLUMNS = 3
local GRID_LEFT = 25
local GRID_TOP = -80
local GRID_COLUMN_WIDTH = 107
local GRID_ROW_HEIGHT = 32
local TILE_WIDTH = 103
local TILE_HEIGHT = 30
local SKILL_ICON_SIZE = 26
-- OSRS level yellow.
local LEVEL_YELLOW = { 1.0, 0.92, 0.0 }

-- Footer: total level, combat level, quests completed — the OSRS skills tab's bottom row.
local TOTAL_LEVEL_ICON = SKILLS_ICON
local COMBAT_LEVEL_ICON = "Ability_DualWield"
local QUESTS_ICON = "Achievement_Quests_Completed_06"

local function RequestTrainingSelection(panel, clickedButton)
    local selection = 0
    local style = PS.state.equippedStyle or "melee"
    local training = TRAINING_BY_STYLE[style] or TRAINING_BY_STYLE.melee
    for _, definition in ipairs(training) do
        local button = panel.trainingButtons[definition[1]]
        if button and button:GetChecked() then selection = selection + definition[1] end
    end

    if selection == 0 then
        clickedButton:SetChecked(true)
        ShowErrorMessage("You must train at least one combat skill.")
        return
    end
    if selection == ActiveSelection() then return end
    if not SendAddonMessage then
        Print("this client cannot send the training request")
        return
    end

    local styleKey = style == "ranged" and "R" or (style == "magic" and "G" or "M")
    SendAddonMessage(PREFIX, "T|" .. styleKey .. "|" .. selection, "WHISPER", UnitName("player"))
end

-- An icon in the spellbook's own slot: stone plate behind, quickslot border around, square glow
-- on hover. Sized from the spellbook's 37px button so the proportions carry over at any size.
local function AddSpellSlot(parent, button, size)
    local scale = size / 37
    local plate = parent:CreateTexture(nil, "BACKGROUND")
    plate:SetTexture("Interface\\Spellbook\\UI-Spellbook-SpellBackground")
    plate:SetWidth(64 * scale)
    plate:SetHeight(64 * scale)
    plate:SetPoint("TOPLEFT", button, "TOPLEFT", -3 * scale, 3 * scale)

    local icon = parent:CreateTexture(nil, "BORDER")
    icon:SetAllPoints(button)

    local border = parent:CreateTexture(nil, "ARTWORK")
    border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    border:SetWidth(64 * scale)
    border:SetHeight(64 * scale)
    border:SetPoint("CENTER", button, "CENTER", 0, 0)

    local highlight = parent:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    highlight:SetBlendMode("ADD")
    highlight:SetAllPoints(button)
    return icon, border
end

local function SetSkillIcon(texture, path, planned)
    texture:SetTexture(ICONS .. path)
    -- A missing texture renders as an empty square rather than failing loudly, so fall back to a
    -- path every 3.3.5a client ships.
    if not texture:GetTexture() then texture:SetTexture(ICONS .. "INV_Misc_QuestionMark") end
    if texture.SetDesaturated then texture:SetDesaturated(planned and 1 or nil) end
end

-- A recessed tile: dark well with a one-pixel bevel, dark above and left, lit below and right.
local function AddRecess(frame)
    local well = frame:CreateTexture(nil, "BACKGROUND")
    well:SetAllPoints(frame)
    well:SetTexture(0, 0, 0, 0.45)
    local function Edge(r, g, b, a, point1, point2, horizontal)
        local edge = frame:CreateTexture(nil, "BACKGROUND")
        edge:SetTexture(r, g, b, a)
        edge:SetPoint(point1, frame, point1, 0, 0)
        edge:SetPoint(point2, frame, point2, 0, 0)
        if horizontal then edge:SetHeight(1) else edge:SetWidth(1) end
    end
    Edge(0, 0, 0, 0.9, "TOPLEFT", "TOPRIGHT", true)
    Edge(0, 0, 0, 0.9, "TOPLEFT", "BOTTOMLEFT", false)
    Edge(1, 1, 1, 0.14, "BOTTOMLEFT", "BOTTOMRIGHT", true)
    Edge(1, 1, 1, 0.14, "TOPRIGHT", "BOTTOMRIGHT", false)
end

local function LevelText(parent)
    local text = parent:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    text:SetTextColor(LEVEL_YELLOW[1], LEVEL_YELLOW[2], LEVEL_YELLOW[3])
    return text
end

local function CreateFooterStat(page, iconName, x, title, description)
    local stat = CreateFrame("Frame", nil, page)
    stat:SetWidth(64)
    stat:SetHeight(20)
    stat:SetPoint("LEFT", page, "TOPLEFT", x, -422)
    stat:EnableMouse(true)
    local icon = stat:CreateTexture(nil, "ARTWORK")
    icon:SetWidth(18)
    icon:SetHeight(18)
    icon:SetPoint("LEFT", stat, "LEFT", 0, 0)
    icon:SetTexture(ICONS .. iconName)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    stat.value = LevelText(stat)
    stat.value:SetPoint("LEFT", icon, "RIGHT", 5, 0)
    stat.value:SetText("—")
    stat:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(title, 1, 1, 1)
        GameTooltip:AddLine(description, GOLD[1], GOLD[2], GOLD[3], true)
        GameTooltip:Show()
    end)
    stat:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return stat
end

-- Quests completed comes from the client's own query of the character's rewarded quests, so no
-- server change is involved. Throttled: the reply lists every completed quest ID.
local QUEST_QUERY_INTERVAL = 5
local function RequestQuestTotal()
    if not QueryQuestsCompleted then return end
    local now = GetTime and GetTime() or 0
    if PS.questQueryAt and now - PS.questQueryAt < QUEST_QUERY_INTERVAL then return end
    PS.questQueryAt = now
    QueryQuestsCompleted()
end

local function ReadQuestTotal()
    if not GetQuestsCompleted then return end
    local completed = GetQuestsCompleted({})
    if type(completed) ~= "table" then return end
    local count = 0
    for _ in pairs(completed) do count = count + 1 end
    PS.state.questsCompleted = count
end

local function CreatePanelChrome(panel)
    -- The art sits on its own child frame so that it draws over the portrait, which shows through
    -- the ring's transparent centre exactly as the character frame's portrait does.
    local chrome = CreateFrame("Frame", nil, panel)
    chrome:SetAllPoints(panel)
    chrome:SetFrameLevel(panel:GetFrameLevel() + 1)

    local function Piece(file, width, height, point)
        local texture = chrome:CreateTexture(nil, "BACKGROUND")
        texture:SetTexture(PANEL_ART .. file)
        texture:SetWidth(width)
        texture:SetHeight(height)
        texture:SetPoint(point, panel, point, 2, -1)
    end
    Piece("UI-Character-General-TopLeft", 256, 256, "TOPLEFT")
    Piece("UI-Character-General-TopRight", 128, 256, "TOPRIGHT")
    Piece("SkillFrame-BotLeft", 256, 256, "BOTTOMLEFT")
    Piece("SkillFrame-BotRight", 128, 256, "BOTTOMRIGHT")

    panel.portrait = panel:CreateTexture("ProjectSkillfulPanelPortrait", "ARTWORK")
    panel.portrait:SetWidth(60)
    panel.portrait:SetHeight(60)
    panel.portrait:SetPoint("TOPLEFT", panel, "TOPLEFT", 7, -6)
    if SetPortraitToTexture then
        SetPortraitToTexture(panel.portrait, ICONS .. SKILLS_ICON)
    else
        panel.portrait:SetTexture(ICONS .. SKILLS_ICON)
    end

    panel.title = chrome:CreateFontString("ProjectSkillfulPanelTitleText", "OVERLAY", "GameFontNormal")
    panel.title:SetPoint("CENTER", panel, "CENTER", 6, 232)
    panel.title:SetText(SKILLS_TITLE)

    panel.subtitle = chrome:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.subtitle:SetPoint("TOP", panel.title, "BOTTOM", 0, -8)

    local close = CreateFrame("Button", "ProjectSkillfulPanelCloseButton", panel, "UIPanelCloseButton")
    close:SetPoint("CENTER", panel, "TOPRIGHT", -44, -25)
    close:SetFrameLevel(panel:GetFrameLevel() + 5)
    return chrome
end

local function CreateSkillsPage(panel)
    local page = CreateFrame("Frame", nil, panel)
    page:SetAllPoints(panel)
    page:SetFrameLevel(panel:GetFrameLevel() + 2)

    panel.rows = {}
    for index, definition in ipairs(SKILLS) do
        local column = math.fmod(index - 1, GRID_COLUMNS)
        local row = math.floor((index - 1) / GRID_COLUMNS)

        local cell = CreateFrame("Button", nil, page)
        cell:SetWidth(TILE_WIDTH)
        cell:SetHeight(TILE_HEIGHT)
        cell:SetPoint("TOPLEFT", page, "TOPLEFT",
            GRID_LEFT + column * GRID_COLUMN_WIDTH, GRID_TOP - row * GRID_ROW_HEIGHT)
        AddRecess(cell)

        local frame = cell:CreateTexture(nil, "BORDER")
        frame:SetTexture(0, 0, 0, 0.9)
        frame:SetWidth(SKILL_ICON_SIZE + 2)
        frame:SetHeight(SKILL_ICON_SIZE + 2)
        frame:SetPoint("LEFT", cell, "LEFT", 3, 0)
        local icon = cell:CreateTexture(nil, "ARTWORK")
        icon:SetWidth(SKILL_ICON_SIZE)
        icon:SetHeight(SKILL_ICON_SIZE)
        icon:SetPoint("CENTER", frame, "CENTER", 0, 0)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        SetSkillIcon(icon, definition[3], definition[4])
        if definition[4] then icon:SetAlpha(0.55) end

        -- Two stacked numbers split by a slash, as in OSRS: current level above, base level below.
        -- With no temporary boosts yet the two are always equal.
        local numbers = SKILL_ICON_SIZE + 8 + (TILE_WIDTH - SKILL_ICON_SIZE - 8) / 2 - 6
        local current = LevelText(cell)
        current:SetPoint("RIGHT", cell, "LEFT", numbers + 1, 6)
        current:SetJustifyH("RIGHT")
        local slash = LevelText(cell)
        slash:SetPoint("CENTER", cell, "LEFT", numbers + 6, 0)
        slash:SetText("/")
        local base = LevelText(cell)
        base:SetPoint("LEFT", cell, "LEFT", numbers + 11, -7)
        base:SetJustifyH("LEFT")
        if definition[4] then slash:Hide() end

        cell:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

        cell.skillId = definition[1]
        cell.skillName = definition[2]
        cell.planned = definition[4]
        cell:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.skillName, 1, 1, 1)
            SkillTooltipLines(GameTooltip, self.skillId, self.planned)
            if not self.planned then
                GameTooltip:AddLine("<Click for details>", 0, 1, 0)
            end
            GameTooltip:Show()
        end)
        cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
        cell:SetScript("OnClick", function(self)
            if PS.OpenSkillDetail then PS.OpenSkillDetail(self.skillId) end
        end)

        panel.rows[definition[1]] = { current = current, base = base, icon = icon, tile = cell }
    end

    -- Bottom strip of SkillFrame-Bot art: total level at the left of the long well, combat level at
    -- the panel's centre, quests completed in the short well on the right.
    panel.footerTotal = CreateFooterStat(page, TOTAL_LEVEL_ICON, 30, "Total Level",
        "The sum of all your skill levels.")
    panel.footerCombat = CreateFooterStat(page, COMBAT_LEVEL_ICON, 160, "Combat Level",
        "Calculated from your combat skills.")
    panel.footerQuests = CreateFooterStat(page, QUESTS_ICON, 278, "Quests Completed",
        "Every quest this character has turned in.")
    return page
end

local function CreateCombatPage(panel)
    local page = CreateFrame("Frame", nil, panel)
    page:SetAllPoints(panel)
    page:SetFrameLevel(panel:GetFrameLevel() + 2)

    local styleSlot = CreateFrame("Frame", nil, page)
    styleSlot:SetWidth(37)
    styleSlot:SetHeight(37)
    styleSlot:SetPoint("TOPLEFT", page, "TOPLEFT", 32, -88)
    page.styleIcon = AddSpellSlot(page, styleSlot, 37)

    page.styleName = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    page.styleName:SetPoint("TOPLEFT", styleSlot, "TOPRIGHT", 8, -4)
    page.styleNote = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    page.styleNote:SetPoint("TOPLEFT", page.styleName, "BOTTOMLEFT", 0, -4)
    page.styleNote:SetText("Set by your equipped weapon")

    -- The same divider the stock Skills tab draws between its list and its detail pane.
    local dividerLeft = page:CreateTexture(nil, "ARTWORK")
    dividerLeft:SetTexture("Interface\\ClassTrainerFrame\\UI-ClassTrainer-HorizontalBar")
    dividerLeft:SetWidth(256)
    dividerLeft:SetHeight(16)
    dividerLeft:SetPoint("TOPLEFT", page, "TOPLEFT", 15, -138)
    dividerLeft:SetTexCoord(0, 1, 0, 0.25)
    local dividerRight = page:CreateTexture(nil, "ARTWORK")
    dividerRight:SetTexture("Interface\\ClassTrainerFrame\\UI-ClassTrainer-HorizontalBar")
    dividerRight:SetWidth(75)
    dividerRight:SetHeight(16)
    dividerRight:SetPoint("LEFT", dividerLeft, "RIGHT", 0, 0)
    dividerRight:SetTexCoord(0, 0.29296875, 0.25, 0.5)

    page.trainingTitle = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    page.trainingTitle:SetPoint("TOPLEFT", page, "TOPLEFT", 32, -162)
    page.trainingTitle:SetText("Experience Training")

    local help = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    help:SetPoint("TOPLEFT", page.trainingTitle, "BOTTOMLEFT", 0, -6)
    help:SetWidth(300)
    help:SetJustifyH("LEFT")
    help:SetText("Experience from each kill is shared between the checked skills.")

    panel.trainingButtons = {}
    for index, definition in ipairs(TRAINING_BY_STYLE.melee) do
        local bit = definition[1]
        local button = CreateFrame("CheckButton", "ProjectSkillfulTrainingButton" .. index, page)
        button:SetWidth(37)
        button:SetHeight(37)
        button:SetPoint("TOPLEFT", page, "TOPLEFT", 32, -208 - (index - 1) * 50)
        local icon = AddSpellSlot(button, button, 37)
        icon:SetTexture(definition[3])
        button:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight")
        local checked = button:GetCheckedTexture()
        if checked and checked.SetBlendMode then checked:SetBlendMode("ADD") end

        local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", button, "TOPRIGHT", 8, -4)
        label:SetText(definition[2])
        local state = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        state:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)

        button.trainingBit = bit
        button.trainingLabel = definition[2]
        button:SetScript("OnClick", function(self)
            PlayUISound(self:GetChecked() and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff")
            RequestTrainingSelection(panel, self)
        end)
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.trainingLabel, 1, 1, 1)
            SkillTooltipLines(GameTooltip, SkillIdByName(self.trainingLabel))
            GameTooltip:AddLine(self:GetChecked() and "Receiving experience from kills." or
                "Click to receive experience from kills.", 0, 1, 0, true)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)

        panel.trainingButtons[bit] = button
        button.icon = icon
        button.label = label
        button.state = state
    end

    local close = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    close:SetWidth(80)
    close:SetHeight(22)
    close:SetPoint("CENTER", page, "TOPLEFT", 305, -422)
    close:SetText(CLOSE or "Close")
    close:SetScript("OnClick", function() PS.HidePanel() end)

    page:Hide()
    return page
end

local function ShowPanelPage(panel, id)
    panel.selectedTab = id
    CallGlobal("PanelTemplates_SetTab", panel, id)
    if panel.detail then panel.detail:Hide() end
    if id == 2 then
        panel.skillsPage:Hide()
        panel.combatPage:Show()
    else
        panel.combatPage:Hide()
        panel.skillsPage:Show()
    end
    if PS.RefreshPanel then PS.RefreshPanel() end
end

local function CreatePanelTabs(panel)
    local labels = { SKILLS_TITLE, "Combat" }
    for index, text in ipairs(labels) do
        local tab = CreateFrame("Button", "ProjectSkillfulPanelTab" .. index, panel, "CharacterFrameTabButtonTemplate")
        tab:SetID(index)
        tab:SetText(text)
        if index == 1 then
            tab:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 11, 46)
        else
            tab:SetPoint("LEFT", _G["ProjectSkillfulPanelTab" .. (index - 1)], "RIGHT", -15, 0)
        end
        -- The template's own handler switches the character frame's tabs; replace it.
        tab:SetScript("OnClick", function(self)
            PlayUISound("igCharacterInfoTab")
            ShowPanelPage(panel, self:GetID())
        end)
        CallGlobal("PanelTemplates_TabResize", tab, 0)
    end
    CallGlobal("PanelTemplates_SetNumTabs", panel, table.getn(labels))
end

local function CreatePanel()
    if PS.panel then return PS.panel end

    local panel = CreateFrame("Frame", "ProjectSkillfulPanel", UIParent)
    panel:SetWidth(384)
    panel:SetHeight(512)
    panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -104)
    panel:SetToplevel(true)
    panel:EnableMouse(true)
    panel:SetHitRectInsets(0, 30, 0, 45)
    panel:Hide()

    -- Registering as a UI panel is what makes it behave like the Spellbook or Talents: it docks to
    -- the left edge, shifts over when another panel opens, and closes with Escape.
    if UIPanelWindows then
        UIPanelWindows["ProjectSkillfulPanel"] = { area = "left", pushable = 1, whileDead = 1 }
    elseif UISpecialFrames then
        table.insert(UISpecialFrames, "ProjectSkillfulPanel")
    end

    CreatePanelChrome(panel)
    panel.skillsPage = CreateSkillsPage(panel)
    panel.combatPage = CreateCombatPage(panel)
    CreatePanelTabs(panel)

    panel:SetScript("OnShow", function(self)
        PlayUISound("igCharacterInfoOpen")
        RequestQuestTotal()
        ShowPanelPage(self, self.selectedTab or 1)
        CallGlobal("UpdateMicroButtons")
    end)
    panel:SetScript("OnHide", function()
        PlayUISound("igCharacterInfoClose")
        CallGlobal("UpdateMicroButtons")
    end)

    PS.panel = panel
    return panel
end

PS.HidePanel = function()
    local panel = PS.panel
    if not panel then return end
    if HideUIPanel and UIPanelWindows and UIPanelWindows["ProjectSkillfulPanel"] then
        HideUIPanel(panel)
    else
        panel:Hide()
    end
end

local function CreateSkillDetail(panel)
    if panel.detail then return panel.detail end
    local detail = CreateFrame("Frame", nil, panel)
    detail:SetAllPoints(panel)
    detail:SetFrameLevel(panel:GetFrameLevel() + 3)
    detail:EnableMouse(true)

    local slot = CreateFrame("Frame", nil, detail)
    slot:SetWidth(37)
    slot:SetHeight(37)
    slot:SetPoint("TOPLEFT", detail, "TOPLEFT", 32, -88)
    detail.icon = AddSpellSlot(detail, slot, 37)

    detail.title = detail:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    detail.title:SetPoint("TOPLEFT", slot, "TOPRIGHT", 8, -2)
    detail.status = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detail.status:SetPoint("TOPLEFT", detail.title, "BOTTOMLEFT", 0, -5)

    -- The stock Skills tab's bar: blue fill, bevelled border, label left and value right.
    detail.progress = CreateFrame("StatusBar", nil, detail)
    detail.progress:SetWidth(271)
    detail.progress:SetHeight(15)
    detail.progress:SetPoint("TOPLEFT", detail, "TOPLEFT", 50, -146)
    detail.progress:SetStatusBarTexture(PANEL_ART .. "UI-Character-Skills-Bar")
    detail.progress:SetStatusBarColor(0.25, 0.25, 0.75)
    local barBackground = detail.progress:CreateTexture(nil, "BACKGROUND")
    barBackground:SetAllPoints(detail.progress)
    barBackground:SetTexture(1, 1, 1, 0.2)
    local barBorder = detail.progress:CreateTexture(nil, "OVERLAY")
    barBorder:SetTexture(PANEL_ART .. "UI-Character-Skills-BarBorder")
    barBorder:SetWidth(281)
    barBorder:SetHeight(32)
    barBorder:SetPoint("LEFT", detail.progress, "LEFT", -5, 0)
    detail.progressLabel = detail.progress:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    detail.progressLabel:SetPoint("LEFT", detail.progress, "LEFT", 6, 1)
    detail.progressLabel:SetText(COMBAT_XP_GAIN or "Experience")
    detail.progressText = detail.progress:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detail.progressText:SetPoint("RIGHT", detail.progress, "RIGHT", -6, 1)

    detail.remaining = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detail.remaining:SetPoint("TOP", detail.progress, "BOTTOM", 0, -10)

    local dividerLeft = detail:CreateTexture(nil, "ARTWORK")
    dividerLeft:SetTexture("Interface\\ClassTrainerFrame\\UI-ClassTrainer-HorizontalBar")
    dividerLeft:SetWidth(256)
    dividerLeft:SetHeight(16)
    dividerLeft:SetPoint("TOPLEFT", detail, "TOPLEFT", 15, -196)
    dividerLeft:SetTexCoord(0, 1, 0, 0.25)
    local dividerRight = detail:CreateTexture(nil, "ARTWORK")
    dividerRight:SetTexture("Interface\\ClassTrainerFrame\\UI-ClassTrainer-HorizontalBar")
    dividerRight:SetWidth(75)
    dividerRight:SetHeight(16)
    dividerRight:SetPoint("LEFT", dividerLeft, "RIGHT", 0, 0)
    dividerRight:SetTexCoord(0, 0.29296875, 0.25, 0.5)

    detail.milestonesTitle = detail:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    detail.milestonesTitle:SetPoint("TOPLEFT", detail, "TOPLEFT", 32, -220)
    detail.milestonesTitle:SetText("Milestones")
    detail.milestones = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detail.milestones:SetPoint("TOPLEFT", detail.milestonesTitle, "BOTTOMLEFT", 0, -8)
    detail.milestones:SetWidth(300)
    detail.milestones:SetJustifyH("LEFT")
    if detail.milestones.SetSpacing then detail.milestones:SetSpacing(4) end
    detail.milestones:SetText(
        "Level 1 — foundation\nLevel 25 — early specialization\nLevel 50 — established craft\n" ..
        "Level 75 — advanced mastery\nLevel 100 — skill cap")

    -- Opening a profession casts its spell, which only secure code may do; a secure action
    -- button is the sanctioned way for an addon to put that on a click.
    detail.openProfession = CreateFrame("Button", "ProjectSkillfulOpenProfessionButton", detail,
        "UIPanelButtonTemplate,SecureActionButtonTemplate")
    detail.openProfession:SetWidth(150)
    detail.openProfession:SetHeight(22)
    detail.openProfession:SetPoint("CENTER", detail, "TOPLEFT", 186, -422)
    detail.openProfession:SetAttribute("type", "spell")
    detail.openProfession:RegisterForClicks("LeftButtonUp")

    local back = CreateFrame("Button", nil, detail, "UIPanelButtonTemplate")
    back:SetWidth(80)
    back:SetHeight(22)
    back:SetPoint("CENTER", detail, "TOPLEFT", 305, -422)
    back:SetText(BACK or "Back")
    back:SetScript("OnClick", function()
        PlayUISound("igMainMenuOptionCheckBoxOn")
        detail:Hide()
        if panel.skillsPage then panel.skillsPage:Show() end
    end)
    detail:Hide()
    panel.detail = detail
    return detail
end

PS.OpenSkillDetail = function(skillId)
    local panel = CreatePanel()
    local detail = CreateSkillDetail(panel)
    local definition = SkillDefinition(skillId)
    if not definition then return end
    local skill = PS.state.skills[skillId]
    SetSkillIcon(detail.icon, definition[3], definition[4])
    detail.title:SetText(definition[2])
    detail.remaining:SetText("")
    -- No bar at all without data: an empty bar reads as zero progress, which is not the same thing.
    detail.progress:Hide()
    if definition[4] then
        detail.status:SetText("|cff808080Not yet available|r")
    elseif skill then
        detail.progress:Show()
        detail.status:SetText("Level " .. skill.level)
        -- The protocol carries total experience and the next level's threshold, not the current
        -- level's floor, so the bar shows progress toward the next threshold from zero.
        detail.progress:SetMinMaxValues(0, math.max(skill.nextXp, 1))
        detail.progress:SetValue(math.min(skill.xp, skill.nextXp))
        detail.progressText:SetText(Comma(skill.xp) .. " / " .. Comma(skill.nextXp))
        if skill.level < 100 and skill.nextXp > skill.xp then
            detail.remaining:SetText(Comma(skill.nextXp - skill.xp) .. " experience to level " .. (skill.level + 1))
        elseif skill.level >= 100 then
            detail.remaining:SetText("Maximum level reached")
        end
    else
        detail.status:SetText("|cff808080Waiting for the server|r")
    end

    local profession = PROFESSION_ACTIONS[skillId]
    local open = detail.openProfession
    if profession and skill and not (InCombatLockdown and InCombatLockdown()) then
        open:SetAttribute("spell", profession)
        open:SetText("Open " .. profession)
        open:Show()
    elseif not (InCombatLockdown and InCombatLockdown()) then
        open:Hide()
    end

    PlayUISound("igMainMenuOptionCheckBoxOn")
    if panel.skillsPage then panel.skillsPage:Hide() end
    detail:Show()
end

local function RefreshPanel()
    local panel = CreatePanel()
    local total, known = TotalLevel()
    local combat = tonumber(PS.state.combatLevel)
    if PS.state.revision and combat then
        panel.subtitle:SetText(UnitName and UnitName("player") or "")
    else
        panel.subtitle:SetText("Waiting for the server")
    end
    panel.footerTotal.value:SetText(known > 0 and tostring(total) or "—")
    panel.footerCombat.value:SetText(PS.state.revision and combat and tostring(combat) or "—")
    panel.footerQuests.value:SetText(PS.state.questsCompleted and tostring(PS.state.questsCompleted) or "—")
    RefreshHeroPaperDoll()

    local combatPage = panel.combatPage
    if combatPage and panel.trainingButtons then
        local style = PS.state.equippedStyle or "melee"
        local presentation = STYLE_PRESENTATION[style] or STYLE_PRESENTATION.melee
        combatPage.styleName:SetText(presentation[1] .. " Style")
        combatPage.styleIcon:SetTexture(ICONS .. presentation[2])
        local training = TRAINING_BY_STYLE[style] or TRAINING_BY_STYLE.melee
        for index = 1, 3 do
            local definition = training[index]
            local button = panel.trainingButtons[index == 3 and 4 or index]
            if button and definition then
                local selected = SelectionIncludes(ActiveSelection(), definition[1])
                button.trainingBit = definition[1]
                button.trainingLabel = definition[2]
                button.icon:SetTexture(definition[3])
                button.label:SetText(definition[2])
                button.state:SetText(selected and "|cff20ff20Training|r" or "|cff808080Not training|r")
                button:SetChecked(selected)
                button:Show()
            elseif button then
                button:Hide()
            end
        end
    end

    -- The grid shows levels only; each tooltip carries the name, experience and the remainder.
    for _, definition in ipairs(SKILLS) do
        local skill = PS.state.skills[definition[1]]
        local row = panel.rows[definition[1]]
        if row then
            local level = skill and tostring(skill.level) or (definition[4] and "" or "–")
            row.current:SetText(level)
            row.base:SetText(level)
        end
    end
end
PS.RefreshPanel = RefreshPanel

local function CreateDebugPanel()
    if PS.debugPanel then return PS.debugPanel end

    local panel = CreateFrame("Frame", "ProjectSkillfulDebugPanel", UIParent)
    panel:SetWidth(420)
    panel:SetHeight(310)
    panel:SetPoint("CENTER", UIParent, "CENTER", 410, 20)
    panel:SetFrameStrata("DIALOG")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:SetClampedToScreen(true)
    panel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -18)
    title:SetText("Project Skillful — Diagnostics")

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)

    panel.lines = {}
    local definitions = {
        { "build", "Client", -52 },
        { "snapshot", "Snapshot", -76 },
        { "revision", "Revision", -100 },
        { "combat", "Combat", -124 },
        { "training", "Training", -148 },
        { "resources", "Resources", -172 },
        { "skills", "Skill rows", -196 },
        { "logging", "Trace logging", -220 },
    }
    for _, definition in ipairs(definitions) do
        local label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("TOPLEFT", 24, definition[3])
        label:SetWidth(94)
        label:SetJustifyH("LEFT")
        label:SetText(definition[2])

        local value = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        value:SetPoint("TOPLEFT", 120, definition[3])
        value:SetPoint("TOPRIGHT", -24, definition[3])
        value:SetJustifyH("LEFT")
        value:SetText("—")
        panel.lines[definition[1]] = value
    end

    panel.lastGain = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.lastGain:SetPoint("TOPLEFT", 24, -248)
    panel.lastGain:SetPoint("TOPRIGHT", -24, -248)
    panel.lastGain:SetHeight(38)
    panel.lastGain:SetJustifyH("LEFT")
    panel.lastGain:SetJustifyV("TOP")
    panel.lastGain:SetText("Last XP gain: none this session")

    local footer = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    footer:SetPoint("BOTTOM", 0, 15)
    footer:SetText("/skillful debug   •   /skillful trace")

    panel:Hide()
    PS.debugPanel = panel
    return panel
end

local function RefreshDebugPanel()
    local panel = CreateDebugPanel()
    local known = 0
    for _, definition in ipairs(SKILLS) do
        if PS.state.skills[definition[1]] then known = known + 1 end
    end

    local serverProtocol = PS.state.serverProtocolVersion and tostring(PS.state.serverProtocolVersion) or "—"
    panel.lines.build:SetText("Addon " .. PS.version .. "   •   expects v" .. PS.protocolVersion .. "   •   server v" .. serverProtocol)
    local rowCount = PS.state.snapshotRowCount or 0
    local snapshotStatus
    if PS.state.protocolMismatch then
        snapshotStatus = "|cffff4040Protocol mismatch|r"
    elseif not PS.state.snapshotHeaderReceived then
        snapshotStatus = "|cffffd100Waiting for header|r"
    elseif rowCount < SERVER_SKILL_COUNT then
        snapshotStatus = "Header received   •   rows " .. rowCount .. "/" .. SERVER_SKILL_COUNT
    elseif not PS.state.snapshotResourceReceived then
        snapshotStatus = "Rows complete   •   waiting for resources"
    else
        snapshotStatus = "|cff00ff00Ready|r   •   rows " .. rowCount .. "/" .. SERVER_SKILL_COUNT
    end
    if PS.state.lastPacketType then snapshotStatus = snapshotStatus .. "   •   last " .. PS.state.lastPacketType end
    panel.lines.snapshot:SetText(snapshotStatus)
    panel.lines.revision:SetText(PS.state.revision and tostring(PS.state.revision) or "—")
    panel.lines.combat:SetText("Level " .. tostring(PS.state.combatLevel or "—"))
    local selectionText = SelectionText(PS.state.equippedStyle, ActiveSelection())
    panel.lines.training:SetText((PS.state.equippedStyle or "melee") .. " mask " ..
        tostring(ActiveSelection()) .. "   •   " .. (selectionText ~= "" and selectionText or "None"))

    local resources = PS.state.resources or {}
    local mana = resources.mana or { current = 0, max = 0 }
    local rage = resources.rage or { current = 0, max = 0 }
    local energy = resources.energy or { current = 0, max = 0 }
    panel.lines.resources:SetText(string.format(
        "Mana %d/%d   Rage %d/%d   Energy %d/%d",
        mana.current or 0, mana.max or 0,
        rage.current or 0, rage.max or 0,
        energy.current or 0, energy.max or 0))
    panel.lines.skills:SetText(known .. "/" .. SERVER_SKILL_COUNT .. " active cached   •   prefix " .. PREFIX)
    panel.lines.logging:SetText(PS.debug and "Enabled" or "Disabled")
    panel.lastGain:SetText(LastGainText())
end

local function HandleAddonMessage(prefix, message)
    if prefix ~= PREFIX or type(message) ~= "string" then return end

    -- Read the version before parsing the full header: a newer protocol may
    -- change its shape and XP units. Its subsequent rows must not enter this cache.
    local announcedVersion = tonumber(string.match(message, "^H|(%d+)|"))
    if announcedVersion and announcedVersion ~= PS.protocolVersion then
        PS.state.serverProtocolVersion = announcedVersion
        PS.state.protocolMismatch = true
        PS.state.snapshotHeaderReceived = false
        if PS.ClearEquipmentCatalog then PS.ClearEquipmentCatalog() end
        if PS.ClearQuestReward then PS.ClearQuestReward() end
        PS.state.lastPacketType = "H"
        RefreshDebugPanel()
        Print("unsupported server protocol " .. tostring(announcedVersion))
        return
    end

    local version, revision, meleeSelection, rangedSelection, magicSelection, combatLevel, equippedStyle =
        string.match(message, "^H|(%d+)|(%d+)|(%d+)|(%d+)|(%d+)|(%d+)|([a-z]+)$")
    if version then
        version = tonumber(version)
        PS.state.serverProtocolVersion = version
        PS.state.lastPacketType = "H"
        if version ~= PS.protocolVersion then
            PS.state.protocolMismatch = true
            RefreshDebugPanel()
            Print("unsupported server protocol " .. tostring(version))
            return
        end
        PS.state.protocolMismatch = false
        PS.state.snapshotHeaderReceived = true
        PS.state.snapshotResourceReceived = false
        PS.state.snapshotRows = {}
        PS.state.snapshotRowCount = 0
        local firstSnapshot = not PS.state.revision
        local previousStyle = PS.state.equippedStyle
        local previousSelection = not firstSnapshot and ActiveSelection() or nil
        PS.state.revision = tonumber(revision)
        PS.state.selections = {
            melee = tonumber(meleeSelection),
            ranged = tonumber(rangedSelection),
            magic = tonumber(magicSelection),
        }
        PS.state.selection = PS.state.selections.melee
        PS.state.equippedStyle = equippedStyle
        PS.state.combatLevel = tonumber(combatLevel)
        -- Confirm a training change once the server has accepted it, not when it was requested.
        -- A weapon swap changes the active selection too, but the player did not ask for that.
        if previousSelection and previousStyle == equippedStyle and previousSelection ~= ActiveSelection() then
            AddGameMessage("SYSTEM", "You are now training " ..
                NaturalList(SelectionNames(equippedStyle, ActiveSelection())) .. ".")
        end
        RefreshPanel()
        RefreshDebugPanel()
        if firstSnapshot and PS.debug then Print("skill data ready — use /skillful to view it") end
        return
    end

    if PS.state.protocolMismatch or not PS.state.snapshotHeaderReceived then return end

    if PS.HandleEquipmentMessage and PS.HandleEquipmentMessage(message) then return end
    if PS.HandleQuestRewardMessage and PS.HandleQuestRewardMessage(message) then return end

    local manaCurrent, manaMaximum, rageCurrent, rageMaximum, energyCurrent, energyMaximum =
        string.match(message, "^R|(%d+)|(%d+)|(%d+)|(%d+)|(%d+)|(%d+)$")
    if manaCurrent then
        PS.state.lastPacketType = "R"
        PS.state.snapshotResourceReceived = true
        local numericManaMaximum = tonumber(manaMaximum) or 0
        local numericRageMaximum = tonumber(rageMaximum) or 0
        local numericEnergyMaximum = tonumber(energyMaximum) or 0
        PS.state.resources = {
            mana = { current = tonumber(manaCurrent), max = numericManaMaximum },
            rage = { current = tonumber(rageCurrent), max = numericRageMaximum },
            energy = { current = tonumber(energyCurrent), max = numericEnergyMaximum },
        }
        PS.state.resourceSnapshotReceived = true
        PS.state.heroResourcesEnabled = numericManaMaximum > 0 and
            numericRageMaximum > 0 and numericEnergyMaximum > 0
        RefreshResourceDock()
        RefreshHeroPaperDoll()
        RefreshDebugPanel()
        return
    end

    local skillId, xp, level, nextXp =
        string.match(message, "^K|(%d+)|(%d+)|(%d+)|(%d+)$")
    if skillId then
        local numericSkillId = tonumber(skillId)
        local numericXp = tonumber(xp)
        local numericLevel = tonumber(level)
        PS.state.lastPacketType = "K"
        if PS.state.snapshotRows and not PS.state.snapshotRows[numericSkillId] then
            PS.state.snapshotRows[numericSkillId] = true
            PS.state.snapshotRowCount = (PS.state.snapshotRowCount or 0) + 1
        end
        local previous = PS.state.skills[numericSkillId]
        if previous and numericXp > previous.xp then
            if PS.state.lastGainRevision ~= PS.state.revision then
                PS.state.lastGains = {}
                PS.state.lastGainRevision = PS.state.revision
            end
            local gain = numericXp - previous.xp
            PS.state.lastGains[numericSkillId] = gain
            AddGameMessage("COMBAT_XP_GAIN",
                "You gain " .. Comma(gain) .. " " .. SkillName(numericSkillId) .. " experience.")
        end
        if previous and numericLevel and previous.level and numericLevel > previous.level then
            AddGameMessage("SKILL", string.format(SKILL_RANK_UP or "Your skill in %s has increased to %d.",
                SkillName(numericSkillId), numericLevel))
        end
        PS.state.skills[numericSkillId] = {
            xp = numericXp, level = numericLevel, nextXp = tonumber(nextXp),
        }
        RefreshPanel()
        RefreshDebugPanel()
        if PS.RefreshEquipmentTooltips then PS.RefreshEquipmentTooltips() end
    elseif PS.debug then
        Print("ignored malformed payload: " .. message)
    end
end

local function TogglePanel()
    local panel = CreatePanel()
    RefreshPanel()
    if panel:IsShown() then
        PS.HidePanel()
    elseif ShowUIPanel and UIPanelWindows and UIPanelWindows["ProjectSkillfulPanel"] then
        ShowUIPanel(panel)
    else
        panel:Show()
    end
end

local function ToggleDebugPanel()
    local panel = CreateDebugPanel()
    RefreshDebugPanel()
    if panel:IsShown() then panel:Hide() else panel:Show() end
end

---------------------------------------------------------------------------------------------------
-- Menu bar button, slotted between Talents and Achievements. Built the way the stock Character
-- and PvP buttons are: the blank "character" button face with a picture set into its window.
---------------------------------------------------------------------------------------------------

local MICRO_ICON_NORMAL = { 0.2, 0.8, 0.0833, 0.9167 }
local MICRO_ICON_PUSHED = { 0.2666, 0.8666, 0.0, 0.8333 }

local function SetMicroButtonPushed(button, pushed)
    local coords = pushed and MICRO_ICON_PUSHED or MICRO_ICON_NORMAL
    button.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    button.icon:SetAlpha(pushed and 0.5 or 1.0)
end

local function AnchorMicroButton(button)
    if not TalentMicroButton then return false end

    -- Insert into the chain: Talents -> us -> Achievements. The stock bar anchors each button to
    -- the previous one's right edge, so re-anchoring Achievements shifts everything after it.
    if button:GetParent() ~= TalentMicroButton:GetParent() then
        button:SetParent(TalentMicroButton:GetParent())
        button:SetFrameLevel(TalentMicroButton:GetFrameLevel() + 1)
    end
    button:ClearAllPoints()
    button:SetPoint("BOTTOMLEFT", TalentMicroButton, "BOTTOMRIGHT", -2, 0)
    if AchievementMicroButton then
        AchievementMicroButton:ClearAllPoints()
        AchievementMicroButton:SetPoint("BOTTOMLEFT", button, "BOTTOMRIGHT", -2, 0)
    end
    return true
end

local function UpdateMicroButtonState()
    local button = PS.microButton
    if not button then return end
    local pushed = PS.panel and PS.panel:IsShown()
    if pushed then button:SetButtonState("PUSHED", 1) else button:SetButtonState("NORMAL") end
    SetMicroButtonPushed(button, pushed)
end

local function CreateMicroButton()
    if PS.microButton then return PS.microButton end

    local parent = MainMenuBarArtFrame or UIParent
    -- MainMenuBarMicroButton is the stock template (MainMenuBarMicroButtons.xml): size, hit rect,
    -- the enable/disable fade, and the tooltip with its grey explanatory line.
    local template = MainMenuBarArtFrame and "MainMenuBarMicroButton" or nil
    local button = CreateFrame("Button", "ProjectSkillfulMicroButton", parent, template)
    button:SetWidth(28)
    button:SetHeight(58)
    button:SetNormalTexture("Interface\\Buttons\\UI-MicroButtonCharacter-Up")
    button:SetPushedTexture("Interface\\Buttons\\UI-MicroButtonCharacter-Down")
    button:SetHighlightTexture("Interface\\Buttons\\UI-MicroButton-Hilight")

    button.icon = button:CreateTexture("ProjectSkillfulMicroButtonIcon", "OVERLAY")
    button.icon:SetWidth(18)
    button.icon:SetHeight(25)
    button.icon:SetPoint("TOP", button, "TOP", 0, -28)
    button.icon:SetTexture(ICONS .. SKILLS_ICON)
    SetMicroButtonPushed(button, false)

    -- Sit one level above the neighbouring stock buttons, as the earlier working button did, so the
    -- few pixels where the chain overlaps go to this button rather than swallowing its clicks.
    button:SetFrameLevel((parent.GetFrameLevel and parent:GetFrameLevel() or 0) + 2)
    button:RegisterForClicks("LeftButtonUp")

    button.tooltipText = SKILLS_TITLE
    button.newbieText = "Your skill levels, and which combat skills your kills train."
    -- Mouse handlers only move the icon. Changing the button state here (SetButtonState) runs before
    -- the client decides a click happened and cancels it, which is how v0.10.0 broke the button.
    button:SetScript("OnMouseDown", function(self) SetMicroButtonPushed(self, true) end)
    button:SetScript("OnMouseUp", function(self) SetMicroButtonPushed(self, PS.panel and PS.panel:IsShown()) end)
    button:SetScript("OnClick", function() TogglePanel() end)
    if not template then
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.tooltipText, 1, 1, 1)
            GameTooltip:AddLine(self.newbieText, GOLD[1], GOLD[2], GOLD[3], true)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    -- Stock code pushes and releases its own buttons as panels open and close, and moves the whole
    -- row onto the vehicle bar and back. Follow both.
    HookGlobal("UpdateMicroButtons", UpdateMicroButtonState)
    HookGlobal("VehicleMenuBar_MoveMicroButtons", function()
        AnchorMicroButton(button)
        if PS.db and PS.db.hideButton then button:Hide() else button:Show() end
    end)

    AnchorMicroButton(button)
    PS.microButton = button
    PS.AnchorMicroButton = AnchorMicroButton
    return button
end

SLASH_PROJECTSKILLFUL1 = "/skillful"
SlashCmdList.PROJECTSKILLFUL = function(message)
    local command = string.lower(string.match(message or "", "^%s*(.-)%s*$"))
    if command == "debug" then
        ToggleDebugPanel()
        return
    end
    if command == "trace" then
        PS.debug = not PS.debug
        RefreshDebugPanel()
        Print("diagnostic trace logging " .. (PS.debug and "enabled" or "disabled"))
        return
    end
    if command == "button" then
        PS.db = PS.db or {}
        PS.db.hideButton = not PS.db.hideButton
        local button = CreateMicroButton()
        if PS.db.hideButton then button:Hide() else button:Show() end
        Print("menu bar button " .. (PS.db.hideButton and "hidden" or "shown"))
        return
    end

    TogglePanel()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("CHAT_MSG_ADDON")
-- The stock UI re-lays out the micro bar on some transitions, and other bar addons re-anchor it
-- outright. Re-applying on world entry is cheap and keeps the button in its slot.
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("UNIT_MANA")
frame:RegisterEvent("UNIT_MAXMANA")
frame:RegisterEvent("UNIT_RAGE")
frame:RegisterEvent("UNIT_MAXRAGE")
frame:RegisterEvent("UNIT_ENERGY")
frame:RegisterEvent("UNIT_MAXENERGY")
frame:RegisterEvent("UNIT_DISPLAYPOWER")
frame:RegisterEvent("QUEST_QUERY_COMPLETE")
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loadedName = ...
        if loadedName == addonName then
            if RegisterAddonMessagePrefix then RegisterAddonMessagePrefix(PREFIX) end

            -- SavedVariables only exists once ADDON_LOADED has fired for this addon.
            ProjectSkillfulDB = ProjectSkillfulDB or {}
            PS.db = ProjectSkillfulDB

            local button = CreateMicroButton()
            if PS.db.hideButton then button:Hide() end

            CustomizeHeroPaperDoll()
            RefreshNativeResources()
            RefreshResourceDock()

            if PS.debug then Print("loaded") end
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        local button = CreateMicroButton()
        AnchorMicroButton(button)
        if PS.db and PS.db.hideButton then button:Hide() else button:Show() end
        CustomizeHeroPaperDoll()
        RefreshNativeResources()
        RefreshResourceDock()
        RequestQuestTotal()
    elseif event == "QUEST_QUERY_COMPLETE" then
        ReadQuestTotal()
        if PS.panel and PS.panel:IsShown() then RefreshPanel() end
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        if sender and sender ~= UnitName("player") then return end
        HandleAddonMessage(prefix, message)
    elseif event == "UNIT_MANA" or event == "UNIT_MAXMANA" or
        event == "UNIT_RAGE" or event == "UNIT_MAXRAGE" or
        event == "UNIT_ENERGY" or event == "UNIT_MAXENERGY" or
        event == "UNIT_DISPLAYPOWER" then
        local unit = ...
        if unit == "player" then
            RefreshNativeResources()
            RefreshResourceDock()
            RefreshHeroPaperDoll()
        end
    end
end)
