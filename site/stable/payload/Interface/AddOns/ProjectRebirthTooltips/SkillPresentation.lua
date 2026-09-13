-- Player-facing copy only. Protocol identities, tuning and audit fields stay intact.
ProjectRebirthSkillPresentation = {}
local P = ProjectRebirthSkillPresentation
local catalog, catalogSource
function P.Entry(id)
    if catalogSource ~= ProjectRebirthGlossaryData or not catalog then
        catalog, catalogSource = {}, ProjectRebirthGlossaryData
        for _, entry in ipairs(catalogSource or {}) do catalog[entry.id] = entry end
    end
    return catalog[tonumber(id)]
end

function P.Name(id, fallback)
    local entry = P.Entry(id)
    -- Restore names shortened by the wire field, without overriding a renamed server Skill.
    if entry and (not fallback or fallback == "" or entry.name:sub(1, #fallback) == fallback) then return entry.name end
    return fallback or "Unknown Skill"
end

function P.Clean(text)
    text = tostring(text or ""):gsub("\r", "")
    text = text:gsub("%[Closed Alpha:[^%]]*%]", "")
    text = text:gsub("^Gain:%s*", ""):gsub("\nGain:%s*", "\n")
    text = text:gsub("\nScaling:%s*", "\n"):gsub("\nReset:%s*", "\n")
    text = text:gsub("%f[%a]ICD%f[%A]", "cooldown")
    text = text:gsub("percentage_points", "percentage points")
    text = text:gsub("Rank I: ([%d%.]+) ([%a ]+)%. Rank V: ([%d%.]+) ([%a ]+)%.", function(low, unit, high, highUnit)
        if unit ~= highUnit then return "Rank I: " .. low .. " " .. unit .. ". Rank V: " .. high .. " " .. highUnit .. "." end
        return low .. "–" .. high .. (unit == "percent" and "%" or " " .. unit) .. ", improving with Skill rank."
    end)
    return text:gsub("^%s+", ""):gsub("%s+$", "")
end

function P.Effect(id)
    local entry = P.Entry(id)
    if entry and entry.description and entry.description ~= "" then return P.Clean(entry.description) end
    local skill = ProjectRebirthSkillData and ProjectRebirthSkillData[tonumber(id)]
    if skill and skill.ranks and skill.ranks[1] then return P.Clean(skill.ranks[1].text) end
    -- The protocol's 64-byte preview is not a complete effect. Never present it as one.
    return "The full description is unavailable. Update your client before choosing this Skill."
end

function P.Meta(rarity, tier)
    return tostring(rarity) .. "  •  " .. (tonumber(tier) and tonumber(tier) > 0 and "Tier " .. tier or "Tier unknown")
end

-- Retain a small diagnostic ring for support, but keep legacy acquisition dumps
-- out of normal chat. Never filter player chat, payouts, quest rewards or errors.
P.Diagnostics = {}
local diagnosticUntil, diagnosticId = 0, nil
function P.ChatFilter(_, _, message)
    if not GetRealmName or GetRealmName() ~= "Rebirth" then return false end
    local plain = tostring(message or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local now = GetTime and GetTime() or 0
    local id = plain:match("^Manifestation choice %d+: .+ %(ID (%d+), rarity %d+%)%.$")
    local hide = plain:match("^Rebirth Skill status: [%w_]+; slots %d+/%d+%.$") ~= nil
    if id then diagnosticId, diagnosticUntil, hide = tonumber(id), now + 3, true end
    if plain:find("Use the Rebirth choice popup to claim one Skill,", 1, true) == 1 then hide = true end
    if now <= diagnosticUntil and diagnosticId then
        local entry = P.Entry(diagnosticId)
        local first = entry and entry.description:match("^[^\n]+")
        if plain:match("^Gain:") or plain:match("^Scaling:") or plain:match("^Reset:")
            or plain:match("^Rank [I1] test value:") or plain:match("^%[Closed Alpha:")
            or (first and plain == first) then hide = true end
    end
    if hide then
        if P.Diagnostics[#P.Diagnostics] ~= message then
            P.Diagnostics[#P.Diagnostics+1] = message
            if #P.Diagnostics > 50 then table.remove(P.Diagnostics, 1) end
        end
        return true
    end
    return false
end
if ChatFrame_AddMessageEventFilter then ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", P.ChatFilter) end
