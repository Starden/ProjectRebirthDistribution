-- Presentation only. Never learns spells, awards ranks, or enables capstone effects.
ProjectRebirthCompletion = {}
local C = ProjectRebirthCompletion
-- Future approved capstones are keyed by TalentID. Intentionally empty today.
-- { HasCapstone=true, Enabled=true, RequiredRank=5, CapstoneSpellID=..., CapstoneTooltipText=... }
C.capstones = {}

function C.TalentComplete(rank, maxRank, rule)
    if type(rank) ~= "number" or type(maxRank) ~= "number" or
        rank < 0 or rank > maxRank or rank ~= math.floor(rank) then return false end
    if maxRank == 1 then return rank == 1 end
    return maxRank > 1 and rule ~= nil and rule.Enabled == true and rule.HasCapstone == true and
        type(rule.RequiredRank) == "number" and rule.RequiredRank >= 1 and
        rule.RequiredRank <= maxRank and rule.RequiredRank == math.floor(rule.RequiredRank) and
        rank >= rule.RequiredRank
end

function C.SkillComplete(rank)
    return rank == 5
end

local function Animate(self, elapsed)
    self.phase = (self.phase + elapsed) % 6
    -- A brief glint follows the top/left edges, away from the rank badge.
    local t = self.phase
    if t < 1.2 then
        local progress = t / 1.2
        self.glint:ClearAllPoints()
        if progress < 0.5 then
            self.glint:SetPoint("CENTER", self, "BOTTOMLEFT", 1, progress * 2 * self:GetHeight())
        else
            self.glint:SetPoint("CENTER", self, "TOPLEFT", (progress - 0.5) * 2 * self:GetWidth(), -1)
        end
        self.glint:SetAlpha(0.42 * math.sin(progress * math.pi))
    else
        self.glint:SetAlpha(0)
    end
end

function C.Set(button, enabled)
    if not button then return end
    local glow = button.rebirthCompletion
    if not enabled then
        if glow then glow:Hide(); glow:SetScript("OnUpdate", nil) end
        return
    end
    if not glow then
        glow = CreateFrame("Frame", nil, button)
        glow:SetAllPoints(button)
        glow:EnableMouse(false)
        glow.edge = glow:CreateTexture(nil, "OVERLAY")
        glow.edge:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        glow.edge:SetBlendMode("ADD")
        glow.edge:SetPoint("CENTER", glow, "CENTER", 0, 0)
        glow.edge:SetVertexColor(1, 0.72, 0.18, 0.36)
        glow.glint = glow:CreateTexture(nil, "OVERLAY")
        glow.glint:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        glow.glint:SetBlendMode("ADD")
        glow.glint:SetSize(12, 12)
        glow.glint:SetVertexColor(1, 0.86, 0.40)
        glow.glint:SetAlpha(0)
        glow.phase = 1.2
        glow:SetScript("OnHide", function(self) self.phase = 1.2; self.glint:SetAlpha(0) end)
        button.rebirthCompletion = glow
    end
    glow.edge:SetSize(button:GetWidth() * 1.55, button:GetHeight() * 1.55)
    glow:Show()
    glow:SetScript("OnUpdate", Animate)
end

function C.Skill(button, rank)
    C.Set(button, C.SkillComplete(rank))
end

function C.Talent(button, rank, maxRank, talentId)
    C.Set(button, C.TalentComplete(rank, maxRank, C.capstones[talentId]))
end

function C.Tooltip(tooltip, rank, maxRank, talentId)
    local rule = C.capstones[talentId]
    if not rule or not rule.Enabled or not rule.HasCapstone or not rule.CapstoneTooltipText then return end
    local active = C.TalentComplete(rank, maxRank, rule)
    tooltip:AddLine(" ")
    tooltip:AddLine("Capstone", active and 1 or 0.5, active and 0.82 or 0.5, active and 0.25 or 0.5)
    tooltip:AddLine(rule.CapstoneTooltipText, active and 1 or 0.5, active and 0.82 or 0.5,
        active and 0.25 or 0.5, true)
end

local nativeButtons = {}
local function NativeTooltip(button)
    local data = button.rebirthCapstone
    if data and GameTooltip:IsOwned(button) then
        C.Tooltip(GameTooltip, data.rank, data.maxRank, data.talentId)
        GameTooltip:Show()
    end
end

function C.RefreshNative(frame)
    if frame ~= PlayerTalentFrame then return end
    for _, button in pairs(nativeButtons) do C.Set(button, false); button.rebirthCapstone = nil end
    if GetRealmName() ~= "Rebirth" or frame.inspect or frame.pet or not GetNumTalents or not GetTalentInfo then return end
    local tab = PanelTemplates_GetSelectedTab(frame)
    if type(tab) ~= "number" or tab < 1 or tab > 3 then return end
    local group = frame.talentGroup or GetActiveTalentGroup()
    for index = 1, GetNumTalents(tab, false, false) do
        local button = _G["PlayerTalentFrameTalent" .. index]
        if button then
            if not nativeButtons[index] then button:HookScript("OnEnter", NativeTooltip) end
            nativeButtons[index] = button
            -- Fifth return is the learned rank, never the uncommitted preview rank.
            local name, _, _, _, rank, maxRank = GetTalentInfo(tab, index, false, false, group)
            local link = GetTalentLink and GetTalentLink(tab, index, false, false, group)
            local talentId = link and tonumber(string.match(link, "talent:(%d+)"))
            button.rebirthCapstone = name and {rank=rank, maxRank=maxRank, talentId=talentId} or nil
            C.Talent(button, name and rank or 0, name and maxRank or 0, talentId)
            if GameTooltip:IsOwned(button) and C.capstones[talentId] and button:GetScript("OnEnter") then
                button:GetScript("OnEnter")(button)
            end
        end
    end
end

local hooked = false
local function InstallNativeHook()
    if not hooked and type(TalentFrame_Update) == "function" then
        hooksecurefunc("TalentFrame_Update", C.RefreshNative)
        hooked = true
    end
end
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_TALENT_UPDATE")
events:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
events:SetScript("OnEvent", function()
    InstallNativeHook()
    if PlayerTalentFrame then C.RefreshNative(PlayerTalentFrame) end
end)
InstallNativeHook()
