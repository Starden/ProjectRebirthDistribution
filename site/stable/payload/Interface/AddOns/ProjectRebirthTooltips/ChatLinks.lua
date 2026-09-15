-- Plain, readable wire tokens; hyperlinks are created only on the receiving UI.
-- Reserved Skill card IDs are NOT native spells. No server link checks are relaxed.
ProjectRebirthChatLinks = {}
local L = ProjectRebirthChatLinks
local function Active() return GetRealmName and GetRealmName() == "Rebirth" end
local function Integer(value, low, high)
    return type(value) == "number" and value == math.floor(value) and value >= low and value <= high
end
local function Lookup(kind, id, rank)
    if not Integer(id, 1, 9999999) or not Integer(rank, 0, 5) then return end
    if kind == "Skill" then
        local entry = ProjectRebirthSkillData and ProjectRebirthSkillData[id]
        if entry and (rank == 0 or entry.ranks[rank]) then return entry end
    elseif kind == "Talent" then
        for _, tree in ipairs(ProjectRebirthFourthSpecData and ProjectRebirthFourthSpecData.trees or {}) do
            for _, node in ipairs(tree.nodes) do
                if node.talentId == id and rank <= node.maxRank then return node, tree end
            end
        end
    end
end
local function SafeName(name)
    return type(name) == "string" and #name > 0 and #name <= 100 and not name:find("[%c|%[%]]")
end
function L.Token(kind, id, rank)
    local entry = Lookup(kind, id, rank)
    if not entry or not SafeName(entry.name) then return end
    return string.format("[Rebirth %s #%d R%d: %s]", kind, id, rank, entry.name)
end
function L.Try(kind, id, rank)
    if not Active() or not IsModifiedClick or not IsModifiedClick("CHATLINK") then return false end
    local token = L.Token(kind, id, rank or 0)
    if token and ChatEdit_InsertLink then ChatEdit_InsertLink(token) end
    -- Even a missing catalog/edit box consumes the modifier; never learn on failure.
    return true
end
local function ConvertPlain(text)
    return text:gsub("%[Rebirth (%a+) #(%d+) R(%d): ([^%[%]\r\n]+)%]", function(kind, id, rank, name)
        id, rank = tonumber(id), tonumber(rank)
        local entry = Lookup(kind, id, rank)
        if not entry or entry.name ~= name or not SafeName(name) then return end
        local label = name .. (rank == 0 and " (Catalog)" or (" (Rank " .. rank .. ")"))
        return string.format("|cff88ddff|Hrebirthcard:%s:%d:%d|h[%s]|h|r", kind, id, rank, label)
    end)
end
function L.Transform(text)
    if type(text) ~= "string" or #text > 4096 then return text end
    -- Never rewrite text inside an existing native hyperlink.
    local parts, start = {}, 1
    while true do
        local first, last = text:find("|H.-|h.-|h", start)
        if not first then parts[#parts + 1] = ConvertPlain(text:sub(start)); break end
        parts[#parts + 1] = ConvertPlain(text:sub(start, first - 1))
        parts[#parts + 1] = text:sub(first, last)
        start = last + 1
    end
    return table.concat(parts)
end
function L.Show(link)
    if type(link) ~= "string" or #link > 80 then return false end
    local kind, id, rank = link:match("^rebirthcard:(%a+):(%d+):(%d)$")
    local entry, tree = Lookup(kind, tonumber(id), tonumber(rank))
    if not entry or not ItemRefTooltip then return false end
    rank = tonumber(rank)
    local tip = ItemRefTooltip
    tip:SetOwner(UIParent, "ANCHOR_PRESERVE")
    tip:ClearLines()
    tip:AddLine(entry.name, 0.53, 0.87, 1)
    tip:AddLine(rank == 0 and "Catalog entry (not an ownership claim)" or ("Linked Rank " .. rank), 1, 1, 1)
    local card = entry.ranks[math.max(1, rank)]
    if tree then
        tip:AddLine(tree.name .. " Talents", 1, 0.82, 0)
        local alpha = ProjectRebirthFourthSpecAlpha and ProjectRebirthFourthSpecAlpha[tonumber(id)]
        tip:AddLine(alpha and alpha[math.max(1, rank)] or card.preview, 1, 0.82, 0, true)
        tip:AddLine("Alpha defaults; server configuration may differ.", 0.65, 0.65, 0.65, true)
        tip:AddLine("WiP / alpha testing: this card does not verify runtime activation.", 0.65, 0.65, 0.65, true)
    else
        local glossary = ProjectRebirthSkillPresentation and ProjectRebirthSkillPresentation.Entry(tonumber(id))
        tip:AddLine("Tier " .. entry.tier .. (glossary and (" - " .. glossary.rarity) or ""), 1, 1, 1)
        tip:AddLine(card.text, 1, 0.82, 0, true)
        tip:AddLine("Catalog values; conditional effects and server configuration may differ.", 0.65, 0.65, 0.65, true)
        if entry.auditStatus == "prototype" or entry.auditStatus == "runtime_not_implemented" or
            entry.auditStatus == "deferred_runtime" then
            tip:AddLine("WiP: effect not active; values are a design preview.", 1, 0.82, 0, true)
        elseif entry.auditStatus == "adapter_requires_verification" then
            tip:AddLine("Alpha testing: live effect verification is still required.", 0.65, 0.65, 0.65, true)
        end
    end
    tip:AddLine("Shared reference only; use Inspect to verify a player's current build.", 0.65, 0.65, 0.65, true)
    tip:Show()
    return true
end
if ChatFrame_AddMessageEventFilter then
    local function Filter(_, _, message, ...)
        if not Active() then return false, message, ... end
        return false, L.Transform(message), ...
    end
    for _, event in ipairs({"CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
        "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
        "CHAT_MSG_RAID_WARNING", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_CHANNEL",
        "CHAT_MSG_BATTLEGROUND", "CHAT_MSG_BATTLEGROUND_LEADER"}) do
        ChatFrame_AddMessageEventFilter(event, Filter)
    end
end
if SetItemRef then
    local nativeSetItemRef = SetItemRef
    SetItemRef = function(link, text, button, chatFrame)
        if type(link) == "string" and link:match("^rebirthcard:") then
            if Active() then
                local kind, id, rank = link:match("^rebirthcard:(%a+):(%d+):(%d)$")
                if not L.Try(kind, tonumber(id), tonumber(rank)) then L.Show(link) end
            end
            return -- Malformed local card links are inert, never sent to native spell lookup.
        end
        return nativeSetItemRef(link, text, button, chatFrame)
    end
end
