-- Presentation only: confirmed Cat talent enhancements, never spellbook aliases.
ProjectRebirthFeralCat = {}
local C = ProjectRebirthFeralCat
local enabled, profile, hooked, lastRequest = false, nil, false, -10
local buttons = {}
local entries = {
    [1162] = {name="Survival Reflex", max=1, text=function() return "A successful Survival Instincts cast in Cat Form restores 20 Energy once. Learn Survival Instincts separately from a trainer at level 20." end},
    [804] = {name="Feline Pursuit", max=1, text=function() return "Feral Charge - Cat has a 5-second shorter cooldown, with a 15-second minimum. Naturally completing its charge restores 10 Energy. Learn Feral Charge separately at level 30." end},
    [2242] = {name="Fluid Strikes", max=3, text=function(r) return "Claw, Shred and Cat Mangle direct critical hits restore " .. r .. " Energy once per cast. 2-second internal cooldown. Fully absorbed landed critical hits count." end},
    [2241] = {name="Predator of the Pack", max=3, text=function(r) return "Rake and Rip applied in Cat Form deal " .. (2*r) .. "% more periodic damage. This does not increase direct damage." end},
    [1796] = {name="Rending Mangle", max=1, text=function() return "Cat Mangle deals 10% more direct damage. Its normal bleed vulnerability is unchanged. Learn Mangle separately from a trainer at level 50." end},
    [1927] = {name="Feline Berserker", max=1, text=function() return "While Berserk is active in Cat Form, your melee attack speed is increased by 15%. Learn Berserk separately from a trainer at level 60." end},
    [794] = {name="Supple Hide", max=3, text=function(r) return "Increases armor from equipped items by " .. ({4,7,10})[r] .. "% while in Cat Form." end},
    [1794] = {name="Feline Fortitude", max=3, text=function(r) return "In Cat Form, increases attributes by " .. (2*r) .. "% and reduces the chance to be critically hit by melee attacks by " .. (2*r) .. " percentage points. Does not grant Bear armor." end},
}

local function Active()
    local _, class = UnitClass("player")
    return GetRealmName() == "Rebirth" and class == "DRUID" and enabled and
        profile == (GetActiveTalentGroup and GetActiveTalentGroup() or 1)
end

-- Exposed pure presentation lookup also permits isolated Lua 5.1 regression tests.
function C.Description(talentId, rank)
    local entry = entries[talentId]
    if not entry or type(rank) ~= "number" or rank ~= math.floor(rank) or rank < 1 or rank > entry.max then return end
    return entry.name, entry.text(rank), entry.max
end

function C.Receive(prefix, message, channel, sender)
    if prefix ~= "ProjectRebirth" or channel ~= "WHISPER" or sender ~= UnitName("player") then return false end
    local revision, incomingProfile, state = string.match(message or "", "^3\tFERAL_CAT_STATE\t(%d+)\t([12])\t([01])$")
    if revision ~= "1" then return false end
    local _, class = UnitClass("player")
    enabled = GetRealmName() == "Rebirth" and class == "DRUID" and state == "1"
    profile = tonumber(incomingProfile)
    return true
end

local function Tooltip(button)
    local data = button.rebirthFeralCat
    if not Active() or not data or not GameTooltip:IsOwned(button) then return end
    local entry = entries[data.id]
    if not entry then return end
    GameTooltip:ClearLines()
    GameTooltip:AddLine(entry.name, 1, .82, 0)
    GameTooltip:AddLine("Rank " .. data.rank .. " / " .. entry.max, 1, 1, 1)
    GameTooltip:AddLine("Cat talent enhancement", .35, .85, 1)
    if data.rank > 0 then GameTooltip:AddLine(entry.text(data.rank), 1, .82, 0, true) end
    if data.rank < entry.max then
        GameTooltip:AddLine("Next rank", .35, .85, 1)
        GameTooltip:AddLine(entry.text(data.rank + 1), 1, 1, 1, true)
    end
    GameTooltip:AddLine("Alpha default values; server configuration may differ.", .65, .65, .65, true)
    GameTooltip:Show()
end

function C.Refresh(frame)
    if frame ~= PlayerTalentFrame then return end
    for _, button in pairs(buttons) do button.rebirthFeralCat = nil end
    if not Active() or frame.inspect or frame.pet or not GetTalentInfo or not GetTalentLink then return end
    local tab = PanelTemplates_GetSelectedTab(frame)
    if tab ~= 2 then return end -- Original Feral tab; never Guardian or another class.
    local group = frame.talentGroup or GetActiveTalentGroup()
    if group ~= profile then return end
    for index = 1, GetNumTalents(tab, false, false) do
        local button = _G["PlayerTalentFrameTalent" .. index]
        local link = GetTalentLink(tab, index, false, false, group)
        local id = link and tonumber(string.match(link, "talent:(%d+)"))
        if button and entries[id] then
            if not buttons[button] then button:HookScript("OnEnter", Tooltip); buttons[button] = button end
            local _, _, _, _, rank, maxRank = GetTalentInfo(tab, index, false, false, group)
            if type(rank) == "number" and rank == math.floor(rank) and rank >= 0 and rank <= entries[id].max and
                maxRank == entries[id].max then
                button.rebirthFeralCat = {id=id, rank=rank}
                if GameTooltip:IsOwned(button) then Tooltip(button) end
            end
        end
    end
end

local function Request()
    local _, class = UnitClass("player")
    if GetRealmName() ~= "Rebirth" or class ~= "DRUID" then return end
    local now = GetTime()
    if now - lastRequest < 2 then return end
    lastRequest = now
    SendAddonMessage("ProjectRebirth", "3\tFOURTH_STATE", "WHISPER", UnitName("player"))
end
local events = CreateFrame("Frame")
for _, event in ipairs({"ADDON_LOADED", "PLAYER_ENTERING_WORLD", "ACTIVE_TALENT_GROUP_CHANGED",
    "PLAYER_TALENT_UPDATE", "CHAT_MSG_ADDON"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent", function(_, event, ...)
    if event == "CHAT_MSG_ADDON" then
        if C.Receive(...) and PlayerTalentFrame then C.Refresh(PlayerTalentFrame) end
        return
    end
    if event == "PLAYER_ENTERING_WORLD" or event == "ACTIVE_TALENT_GROUP_CHANGED" then enabled, profile = false, nil end
    if not hooked and type(TalentFrame_Update) == "function" then
        hooksecurefunc("TalentFrame_Update", C.Refresh)
        hooked = true
    end
    if PlayerTalentFrame then C.Refresh(PlayerTalentFrame) end
    Request()
end)
