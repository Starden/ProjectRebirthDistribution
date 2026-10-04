-- Rebirth Bot Manager
--
-- A click-driven front end for mod-playerbots. It sends only the commands a
-- player could already type: whispers to a bot ("follow", "talents spec prot pve")
-- and the ".playerbots bot" chat command. Every permission check therefore stays on
-- the server (PlayerbotSecurity), and this addon needs no server bridge or protocol.
--
-- Specification: docs/design/party-bot-manager-v1.md

local ADDON_NAME = "RebirthBotManager"
local VERSION = "0.3.0"

local SEND_INTERVAL = 0.25       -- seconds between queued chat lines
local QUIET_SECONDS = 4          -- bot replies hidden from chat after an addon request
local ROSTER_THROTTLE = 2        -- minimum seconds between automatic roster queries
local MAX_QUEUED_COMMANDS = 40
local PARTY_TIMEOUT = 30
local ROSTER_MAX_AGE = 10
local REPAIR_REPLY_TIMEOUT = 5
local REPAIR_QUEUE_TIMEOUT = 15
local ROW_HEIGHT = 22
local VISIBLE_ROWS = 13

local ROLE_TANK, ROLE_HEALER, ROLE_DAMAGER = "TANK", "HEALER", "DAMAGER"
local ROLE_ORDER = { ROLE_TANK, ROLE_HEALER, ROLE_DAMAGER }
local ROLE_LABEL = { TANK = "Tank", HEALER = "Healer", DAMAGER = "Damage" }

-- Roles each class can fill with a stock PlayerBots premade spec.
local CLASS_ROLES = {
    WARRIOR = { TANK = true, DAMAGER = true },
    PALADIN = { TANK = true, HEALER = true, DAMAGER = true },
    HUNTER = { DAMAGER = true },
    ROGUE = { DAMAGER = true },
    PRIEST = { HEALER = true, DAMAGER = true },
    DEATHKNIGHT = { TANK = true, DAMAGER = true },
    SHAMAN = { HEALER = true, DAMAGER = true },
    MAGE = { DAMAGER = true },
    WARLOCK = { DAMAGER = true },
    DRUID = { TANK = true, HEALER = true, DAMAGER = true },
}

-- Class names as ".playerbots bot list" prints them, and as "addclass" accepts them.
local ROSTER_CLASS = {
    Warrior = "WARRIOR", Paladin = "PALADIN", Hunter = "HUNTER", Rogue = "ROGUE",
    Priest = "PRIEST", Shaman = "SHAMAN", Mage = "MAGE", Warlock = "WARLOCK",
    Druid = "DRUID", DeathKnight = "DEATHKNIGHT",
}
local ADDCLASS_ORDER = {
    { "WARRIOR", "warrior" }, { "PALADIN", "paladin" }, { "DEATHKNIGHT", "dk" },
    { "HUNTER", "hunter" }, { "ROGUE", "rogue" }, { "SHAMAN", "shaman" },
    { "DRUID", "druid" }, { "PRIEST", "priest" }, { "MAGE", "mage" },
    { "WARLOCK", "warlock" },
}

local ROLE_TEXTURE = "Interface\\LFGFrame\\UI-LFG-ICON-ROLES"
local CLASS_TEXTURE = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
local MINIMAP_ICON = "Interface\\Icons\\INV_Misc_GroupNeedMore"

local roster = {}         -- name -> { online = bool, class = token }
local rosterOrder = {}    -- sorted names
local specs = {}          -- name -> { "prot pve", ... } once a spec list completes
local specsPending = {}   -- name -> list being collected
local currentSpec = {}    -- name -> spec name or description
local currentRole = {}    -- name -> role token
local pendingRole = {}    -- name -> role waiting on a spec list
local quietUntil = {}     -- lower(name) -> time
local echoUntil = {}      -- lower(target) .. "\n" .. msg -> time
local rosterRequestedAt = 0
local rosterHideUntil = 0
local rosterUpdatedAt = nil
local selected = nil      -- nil means every bot in your group

local queue = {}
local queuedKeys = {}
local partyOperation = nil
local repairRequests = {} -- bounded by the command queue, one pending request per bot
local Manager, Refresh
local UpdatePartyOperation

-- ── helpers ──────────────────────────────────────────────────────────────

local function Now() return GetTime() end

-- 3.3.5 has no Region:SetShown.
local function ShowIf(region, shown)
    if shown then region:Show() else region:Hide() end
end

local function ClassColor(token)
    local c = token and RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
    if c then return c.r, c.g, c.b end
    return 1, 0.82, 0
end

local function RoleCoords(role)
    if GetTexCoordsForRole then return GetTexCoordsForRole(role) end
    if role == ROLE_TANK then return 0, 19/64, 22/64, 41/64 end
    if role == ROLE_HEALER then return 20/64, 39/64, 1/64, 20/64 end
    return 20/64, 39/64, 22/64, 41/64
end

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffd9a441Bot Manager:|r " .. msg)
end

local function Log(msg)
    if Manager and Manager.log then Manager.log:AddMessage(msg) end
end

local function StripCodes(text)
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|h", ""):gsub("|H.-|h", "")
    return text
end

-- Role of a premade spec name or a "current spec" description.
local function SpecRole(text)
    local n = text:lower()
    if n:find("prot") or n:find("blood") or n:find("bear") or n:find("tank") then return ROLE_TANK end
    if n:find("holy") or n:find("disc") or n:find("resto") or n:find("heal") then return ROLE_HEALER end
    return ROLE_DAMAGER
end

local function GroupNames()
    local names = {}
    if GetNumRaidMembers() > 0 then
        for i = 1, GetNumRaidMembers() do
            local n = UnitName("raid" .. i)
            if n then names[n] = "raid" .. i end
        end
    else
        for i = 1, GetNumPartyMembers() do
            local n = UnitName("party" .. i)
            if n then names[n] = "party" .. i end
        end
    end
    return names
end

local function IsControllable(name)
    local bot = roster[name]
    return bot and bot.online
end

-- Bots an order goes to: the selected bot, or every online bot in your group.
local function Targets()
    if selected then
        return IsControllable(selected) and { selected } or {}
    end
    local inGroup, list = GroupNames(), {}
    for _, name in ipairs(rosterOrder) do
        if IsControllable(name) and inGroup[name] then table.insert(list, name) end
    end
    return list
end

-- ── outgoing chat ────────────────────────────────────────────────────────

local function Enqueue(item)
    local key = (item.target or "SAY") .. "\n" .. item.msg
    if queuedKeys[key] then return false end
    if #queue >= MAX_QUEUED_COMMANDS then
        Print("Too many pending commands. Please wait for them to finish.")
        return false
    end
    item.key = key
    queuedKeys[key] = true
    table.insert(queue, item)
    return true
end

local function Whisper(name, msg)
    return Enqueue({ target = name, msg = msg })
end

local function ServerCommand(msg, onSend, guard)
    return Enqueue({ msg = msg, onSend = onSend, guard = guard })
end

local function Order(msg, label)
    local list = Targets()
    if #list == 0 then
        Print(selected and (selected .. " is not online.") or "No bots in your group. Add one under Party, or refresh.")
        return
    end
    for _, name in ipairs(list) do Whisper(name, msg) end
    Log(string.format("|cffffd100%s|r -> %s", label or msg, selected or ("all " .. #list .. " bots")))
end

local function RepairTargetStillValid(name, request)
    return IsControllable(name) and (not request.groupTarget or GroupNames()[name] ~= nil)
end

local function BlockRepair(name, reason)
    repairRequests[name] = nil
    Print("Repair not sent to " .. name .. ": " .. reason)
end

-- Native CheatAction::ListCheats emits concatenated [name]/[conf:name] tokens.
-- Query only: no + or - command, and never infer no cheats from silence.
-- A real empty whisper is its zero-flags reply; absence of an event is not.
local function GoldInCheatReply(msg)
    if msg == "" then return false end
    local text = StripCodes(msg):match("^%s*(.-)%s*$")
    if text == "" then return nil end
    local known = { none = true, taxi = true, gold = true, health = true,
                    mana = true, power = true, raid = true }
    local gold, offset = false, 1
    while offset <= #text do
        local token = text:sub(offset):match("^%[([^%]]+)%]")
        if not token then return nil end
        local name = token:match("^conf:(%a+)$") or token:match("^(%a+)$")
        if not name or not known[name] then return nil end
        if name == "gold" then gold = true end
        offset = offset + #token + 2
    end
    return gold
end

local function RequestVendorRepair()
    local list = Targets()
    if #list == 0 then
        Print(selected and (selected .. " is not online.") or "No bots in your group. Add one under Party, or refresh.")
        return
    end
    for _, name in ipairs(list) do
        if not repairRequests[name] then
            local request = { queuedAt = Now(), groupTarget = not selected }
            local queued = Enqueue({ target = name, msg = "cheat ?",
                guard = function()
                    if repairRequests[name] ~= request then return false end
                    if not RepairTargetStillValid(name, request) then
                        BlockRepair(name, "the bot is no longer an online target.")
                        return false
                    end
                    return true
                end,
                onSend = function()
                    request.sentAt = Now()
                    request.expiresAt = Now() + REPAIR_REPLY_TIMEOUT
                end })
            if queued then
                repairRequests[name] = request
                Log("|cffffd100Repair vendor|r -> " .. name .. " (checking payment; no repair sent yet)")
            end
        end
    end
end

local function HandleRepairReply(sender, msg)
    local request = repairRequests[sender]
    if not request or not request.sentAt or request.approvedAt then return end
    if Now() > request.expiresAt then
        BlockRepair(sender, "payment check timed out. Retry when the bot responds.")
        return
    end
    local gold = GoldInCheatReply(msg)
    if gold == nil then
        local text = StripCodes(msg):match("^%s*(.-)%s*$")
        -- Inventory warnings and other pending status replies are not the
        -- payment response. Keep them visible without granting or cancelling.
        if not text:match("^%[") and not text:lower():find("not allowed", 1, true)
            and not text:lower():find("permission", 1, true) then return end
        BlockRepair(sender, "payment could not be confirmed. Check the visible reply, then retry.")
        return
    end
    if gold then
        BlockRepair(sender, "the bot's gold-cheat flag would waive vendor costs.")
        return
    end
    request.approvedAt = Now()
    if not Enqueue({ target = sender, msg = "repair",
        guard = function()
            if repairRequests[sender] ~= request then return false end
            if Now() > request.expiresAt or not RepairTargetStillValid(sender, request) then
                BlockRepair(sender, "payment check expired or the bot is no longer an online target. Retry.")
                return false
            end
            return true
        end,
        onSend = function()
            repairRequests[sender] = nil
            Log("|cffffd100Repair vendor|r -> " .. sender .. " (requested; vendor and money checks remain on the server)")
        end }) then
        BlockRepair(sender, "the command queue is busy. Retry after pending commands finish.")
    end
end

local function UpdateRepairRequests()
    for name, request in pairs(repairRequests) do
        if (request.expiresAt and Now() > request.expiresAt)
            or (not request.sentAt and Now() - request.queuedAt > REPAIR_QUEUE_TIMEOUT) then
            BlockRepair(name, "payment check timed out. No repair was sent; retry when the bot responds.")
        end
    end
end

local function RequestRoster(force)
    if not force and Now() - rosterRequestedAt < ROSTER_THROTTLE then return end
    rosterRequestedAt = Now()
    ServerCommand(".playerbots bot list", function() rosterHideUntil = Now() + 5 end)
end

local function RequestSpecs(name)
    specsPending[name] = {}
    Whisper(name, "talents spec list")
end

local function AssignRole(name, role)
    local bot = roster[name]
    if not bot then return end
    if bot.class and CLASS_ROLES[bot.class] and not CLASS_ROLES[bot.class][role] then
        Print(name .. " cannot fill the " .. ROLE_LABEL[role] .. " role.")
        return
    end
    local list = specs[name]
    if not list then
        pendingRole[name] = role
        RequestSpecs(name)
        Log(string.format("|cffffd100%s|r -> %s (reading specs)", ROLE_LABEL[role], name))
        return
    end
    local pick
    for _, spec in ipairs(list) do
        if SpecRole(spec) == role then
            if spec:lower():find("pve") then pick = spec break end
            pick = pick or spec
        end
    end
    if not pick then
        Print(name .. " has no " .. ROLE_LABEL[role] .. " spec on this realm.")
        return
    end
    Whisper(name, "talents spec " .. pick)
    Log(string.format("|cffffd100%s|r -> %s (%s)", ROLE_LABEL[role], name, pick))
end

-- ── incoming chat ────────────────────────────────────────────────────────

local function ParseRoster(body)
    local seen = {}
    for entry in (body .. ", "):gmatch("(.-), ") do
        local flag, name, cls = entry:match("^([%+%-])(%S+) (%S+)$")
        if name then
            roster[name] = roster[name] or {}
            roster[name].online = (flag == "+")
            roster[name].class = ROSTER_CLASS[cls] or roster[name].class
            seen[name] = true
        end
    end
    for name in pairs(roster) do
        if not seen[name] then roster[name] = nil end
    end
    rosterUpdatedAt = Now()
    if selected and not roster[selected] then selected = nil end
    rosterOrder = {}
    for name in pairs(roster) do table.insert(rosterOrder, name) end
    table.sort(rosterOrder, function(a, b)
        if roster[a].online ~= roster[b].online then return roster[a].online end
        return a < b
    end)
    -- Learn the spec of any online bot we have not asked yet.
    for _, name in ipairs(rosterOrder) do
        if roster[name].online and not currentSpec[name] then
            currentSpec[name] = "?"
            quietUntil[name:lower()] = Now() + QUIET_SECONDS
            Whisper(name, "talents")
        end
    end
    if Refresh then Refresh() end
end

local function OnBotLine(sender, msg)
    -- One reply can carry several lines.
    if msg:find("\n") then
        for line in msg:gmatch("[^\n]+") do OnBotLine(sender, line) end
        return
    end
    local text = StripCodes(msg)
    local spec, a, b, c = text:match("^%d+%. (.+) %((%d+)%-(%d+)%-(%d+)%)$")
    if spec then
        specsPending[sender] = specsPending[sender] or {}
        table.insert(specsPending[sender], spec)
        return
    end
    if text:match("^Total %d+ specs found") then
        specs[sender] = specsPending[sender] or {}
        specsPending[sender] = nil
        if pendingRole[sender] then
            local role = pendingRole[sender]
            pendingRole[sender] = nil
            AssignRole(sender, role)
        end
        if Refresh then Refresh() end
        return
    end
    local picked = text:match("^Picking (.+)$")
    if picked then
        currentSpec[sender] = picked
        currentRole[sender] = SpecRole(picked)
        Log(string.format("%s: now %s", sender, picked))
        if Refresh then Refresh() end
        return
    end
    local now = text:match("^My current talent spec is: (.-)%s*$")
    if now then
        currentSpec[sender] = now
        currentRole[sender] = SpecRole(now)
        if Refresh then Refresh() end
        return
    end
    if text:match("^Talents usage:") then return end
    Log(string.format("|cff9d9d9d%s:|r %s", sender, msg))
end

-- Hide only recognized status replies, never refusals or gameplay warnings.
local function IsStatusReply(msg)
    local any = false
    for line in msg:gmatch("[^\n]+") do
        local text = StripCodes(line)
        if not (text:match("^%d+%. .+ %(%d+%-%d+%-%d+%)$")
            or text:match("^Total %d+ specs found")
            or text:match("^Picking .+$")
            or text:match("^My current talent spec is: ")
            or text:match("^Talents usage:")) then return false end
        any = true
    end
    return any
end

local function FilterIncoming(self, event, msg, sender)
    if repairRequests[sender] then return false end
    if roster[sender] and (quietUntil[sender:lower()] or 0) > Now() and IsStatusReply(msg) then return true end
    return false
end

local function FilterOutgoing(self, event, msg, target)
    local key = (target or ""):lower() .. "\n" .. msg
    if (echoUntil[key] or 0) > Now() then return true end
    return false
end

local function FilterSystem(self, event, msg)
    if msg:match("^Bot roster: ") and rosterHideUntil > Now() then return true end
    return false
end

-- ── queue pump ───────────────────────────────────────────────────────────

local pump = CreateFrame("Frame")
local elapsedSinceSend = 0
pump:SetScript("OnUpdate", function(self, elapsed)
    if UpdatePartyOperation then UpdatePartyOperation() end
    UpdateRepairRequests()
    elapsedSinceSend = elapsedSinceSend + elapsed
    if elapsedSinceSend < SEND_INTERVAL or #queue == 0 then return end
    elapsedSinceSend = 0
    local item = table.remove(queue, 1)
    queuedKeys[item.key] = nil
    if item.guard and not item.guard() then return end
    if item.target then
        if item.onSend then item.onSend() end
        quietUntil[item.target:lower()] = Now() + QUIET_SECONDS
        echoUntil[item.target:lower() .. "\n" .. item.msg] = Now() + 3
        SendChatMessage(item.msg, "WHISPER", nil, item.target)
    else
        if item.onSend then item.onSend() end
        SendChatMessage(item.msg, "SAY")
    end
end)

-- A saved party contains names only. No class creation, talents, gear or level changes.
local function ReadPartyNames()
    local names, seen = {}, {}
    local master = (UnitName("player") or ""):lower()
    for i = 1, 4 do
        local text = Manager.party.fields[i]:GetText() or ""
        local name = text:match("^%s*(.-)%s*$")
        if #name < 2 or #name > 12 or not name:match("^%a+$") then
            return nil, "Enter four character names (2-12 letters each)."
        end
        local key = name:lower()
        if key == master or seen[key] then return nil, "Use four different companions, excluding yourself." end
        seen[key] = true
        names[i] = name:sub(1, 1):upper() .. name:sub(2):lower()
    end
    return names
end

local function PartyContextError(names)
    if InCombatLockdown and InCombatLockdown() then return "Form your party outside combat." end
    if GetNumRaidMembers() > 0 then return "Leave the raid before forming a five-person party." end
    if GetNumPartyMembers() > 0 and (not IsPartyLeader or not IsPartyLeader()) then
        return "You must lead the party to invite your companions."
    end
    local allowed = {}
    for _, name in ipairs(names) do allowed[name] = true end
    for name in pairs(GroupNames()) do
        if not allowed[name] then return "Your party contains another player. Make space before forming this party." end
    end
end

local function PartyStatus(text)
    Manager.party.status:SetText(text)
    Log(text)
end

local function SavePartyNames()
    local names, err = ReadPartyNames()
    if not names then PartyStatus(err) return nil end
    RebirthBotManagerDB.partyNames = names
    return names
end

local function JoinedParty(names)
    local grouped, joined, missing = GroupNames(), 0, {}
    for _, name in ipairs(names) do
        if grouped[name] then joined = joined + 1 else table.insert(missing, name) end
    end
    return joined, missing
end

local function FormParty()
    if partyOperation then PartyStatus("Party request already pending. Please wait.") return end
    local names = SavePartyNames()
    if not names then return end
    local err = PartyContextError(names)
    if err then PartyStatus(err) return end
    if not rosterUpdatedAt or Now() - rosterUpdatedAt > ROSTER_MAX_AGE then
        RequestRoster(false)
        PartyStatus("Refreshing your roster. Click Form party again once it arrives.")
        return
    end
    for _, name in ipairs(names) do
        if not roster[name] then PartyStatus(name .. " is not in your server-reported bot roster.") return end
    end
    local joined = JoinedParty(names)
    if joined == 4 then PartyStatus("All four companions are already in your party.") return end
    local grouped = GroupNames()
    for _, name in ipairs(names) do
        if roster[name].online and not grouped[name] then
            if not InviteUnit then PartyStatus("This client cannot invite an online companion.") return end
            InviteUnit(name) -- only here, in the explicit user click; cold logins group on the server.
        end
    end
    partyOperation = { names = names }
    local queued = ServerCommand(".playerbots bot add " .. table.concat(names, ","), function()
        partyOperation.expiresAt = Now() + PARTY_TIMEOUT
        partyOperation.nextCheckAt = Now()
        partyOperation.nextRosterAt = Now()
        PartyStatus("Requested four companions; waiting for actual party membership.")
    end, function()
        local changed = PartyContextError(names)
        if changed then partyOperation = nil PartyStatus(changed) return false end
        return true
    end)
    if not queued then partyOperation = nil return end
    PartyStatus("Party request queued.")
end

UpdatePartyOperation = function()
    local op = partyOperation
    if not op or not op.expiresAt or Now() < op.nextCheckAt then return end
    op.nextCheckAt = Now() + 1
    local joined, missing = JoinedParty(op.names)
    if joined == 4 then
        partyOperation = nil
        PartyStatus("All four companions joined your party.")
        return
    end
    if Now() >= op.expiresAt then
        partyOperation = nil
        PartyStatus(string.format("%d/4 joined. Still missing: %s. Check visible server replies, then retry.",
            joined, table.concat(missing, ", ")))
        return
    end
    if Now() >= op.nextRosterAt then
        op.nextRosterAt = Now() + ROSTER_THROTTLE
        RequestRoster(false)
    end
end

-- ── UI ───────────────────────────────────────────────────────────────────

local function Label(parent, text, x, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(text)
    return fs
end

local function Button(parent, text, width, x, y, onClick, tip)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetWidth(width)
    b:SetHeight(22)
    b:SetPoint("TOPLEFT", x, y)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    if tip then
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(text, 1, 1, 1)
            GameTooltip:AddLine(tip, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", GameTooltip_Hide)
    end
    return b
end

local function Inset(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0, 0, 0, 0.55)
    f:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.9)
    return f
end

local function BuildPartyMaker(parent)
    local f = CreateFrame("Frame", "RebirthBotManagerPartyFrame", UIParent)
    f:SetWidth(370)
    f:SetHeight(284)
    f:SetPoint("CENTER", parent, "CENTER", 0, 0)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 } })
    f:Hide()
    tinsert(UISpecialFrames, f:GetName())
    Label(f, "My four companions", 22, -22)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)
    f.fields = {}
    for i = 1, 4 do
        Label(f, "Companion " .. i, 22, -47 - (i - 1) * 29)
        local edit = CreateFrame("EditBox", "RebirthBotManagerPartyName" .. i, f, "InputBoxTemplate")
        edit:SetWidth(208)
        edit:SetHeight(24)
        edit:SetPoint("TOPLEFT", 128, -40 - (i - 1) * 29)
        edit:SetAutoFocus(false)
        edit:SetMaxLetters(12)
        edit:SetText(RebirthBotManagerDB.partyNames[i] or "")
        edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        f.fields[i] = edit
    end
    Button(f, "Save names", 108, 22, -164, function()
        if SavePartyNames() then PartyStatus("Companion names saved for this character.") end
    end, "Save these four existing characters. This does not log them in or change their builds.")
    Button(f, "Form party", 198, 140, -164, FormParty,
        "Log in your four saved companions with one native command. The server adds newly logged-in bots to your party.")
    f.status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.status:SetPoint("TOPLEFT", 22, -199)
    f.status:SetWidth(316)
    f.status:SetJustifyH("LEFT")
    f.status:SetText("Existing characters only. Roles, talents, equipment and levels stay as they are.")
    f:SetScript("OnShow", function() RequestRoster(false) end)
    return f
end

local function BuildRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 6, -6 - (index - 1) * ROW_HEIGHT)
    row:SetPoint("RIGHT", -24, 0)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row.selectedTex = row:CreateTexture(nil, "BACKGROUND")
    row.selectedTex:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row.selectedTex:SetBlendMode("ADD")
    row.selectedTex:SetVertexColor(1, 0.82, 0, 0.6)
    row.selectedTex:SetAllPoints()
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetWidth(18)
    row.icon:SetHeight(18)
    row.icon:SetPoint("LEFT", 2, 0)
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
    row.name:SetJustifyH("LEFT")
    row.role = row:CreateTexture(nil, "ARTWORK")
    row.role:SetTexture(ROLE_TEXTURE)
    row.role:SetWidth(16)
    row.role:SetHeight(16)
    row.role:SetPoint("RIGHT", -2, 0)
    row:SetScript("OnClick", function(self)
        selected = self.botName
        if selected and roster[selected] and roster[selected].online and not specs[selected] then
            RequestSpecs(selected)
        end
        Refresh()
    end)
    return row
end

local function BuildManager()
    local f = CreateFrame("Frame", "RebirthBotManagerFrame", UIParent)
    f:SetWidth(580)
    f:SetHeight(452)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    f:Hide()
    tinsert(UISpecialFrames, f:GetName())

    local header = f:CreateTexture(nil, "ARTWORK")
    header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    header:SetWidth(300)
    header:SetHeight(64)
    header:SetPoint("TOP", 0, 12)
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", header, "TOP", 0, -14)
    title:SetText("Bot Manager")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)

    -- Left: the bot list.
    local list = Inset(f)
    list:SetPoint("TOPLEFT", 18, -32)
    list:SetWidth(196)
    list:SetHeight(VISIBLE_ROWS * ROW_HEIGHT + 12)
    f.rows = {}
    for i = 1, VISIBLE_ROWS do f.rows[i] = BuildRow(list, i) end
    local scroll = CreateFrame("ScrollFrame", "RebirthBotManagerScroll", list, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -28, 6)
    scroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, Refresh)
    end)
    f.scroll = scroll
    f.empty = list:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.empty:SetPoint("CENTER")
    f.empty:SetWidth(170)
    f.empty:SetText("No bots yet.\nAdd one under Party.")

    Button(f, "Refresh", 96, 18, -(VISIBLE_ROWS * ROW_HEIGHT + 48), function() RequestRoster(true) end,
        "Ask the server for your bot roster again.")
    f.count = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.count:SetPoint("TOPLEFT", 122, -(VISIBLE_ROWS * ROW_HEIGHT + 53))
    Button(f, "My party", 196, 18, -362, function() f.party:Show() end,
        "Save four companions and form your party with one click.")
    f.party = BuildPartyMaker(f)

    -- Right: the controls for the selected bot (or the whole group).
    local R = 230
    f.who = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    f.who:SetPoint("TOPLEFT", R, -34)
    f.whoSub = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.whoSub:SetPoint("TOPLEFT", R, -56)

    Label(f, "ROLE", R, -78)
    f.roleButtons = {}
    for i, role in ipairs(ROLE_ORDER) do
        local b = CreateFrame("Button", nil, f)
        b:SetWidth(40)
        b:SetHeight(40)
        b:SetPoint("TOPLEFT", R + (i - 1) * 50, -92)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
        b.icon:SetTexture(ROLE_TEXTURE)
        b.icon:SetTexCoord(RoleCoords(role))
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        b.glow = b:CreateTexture(nil, "OVERLAY")
        b.glow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
        b.glow:SetBlendMode("ADD")
        b.glow:SetAllPoints()
        b.role = role
        b:SetScript("OnClick", function(self)
            if selected then AssignRole(selected, self.role) end
        end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(ROLE_LABEL[self.role], 1, 1, 1)
            GameTooltip:AddLine("Switch this bot to its premade " .. ROLE_LABEL[self.role]:lower()
                .. " spec. Its talents and rotation change.", nil, nil, nil, true)
            GameTooltip:AddLine("This can reset saved strategies. Rebirth fourth-tree mappings are unverified.",
                1, 0.82, 0, true)
            if not selected then
                GameTooltip:AddLine("Select a single bot first.", 1, 0.3, 0.3, true)
            end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", GameTooltip_Hide)
        f.roleButtons[i] = b
    end

    Label(f, "SPECIALISATION", R + 160, -78)
    local drop = CreateFrame("Frame", "RebirthBotManagerSpecDrop", f, "UIDropDownMenuTemplate")
    drop:SetPoint("TOPLEFT", R + 142, -94)
    UIDropDownMenu_SetWidth(drop, 140)
    UIDropDownMenu_Initialize(drop, function()
        local list = selected and specs[selected]
        if not list then
            local info = UIDropDownMenu_CreateInfo()
            info.text = selected and "Reading specs..." or "Select a bot"
            info.disabled = true
            UIDropDownMenu_AddButton(info)
            return
        end
        for _, spec in ipairs(list) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = spec
            info.checked = (currentSpec[selected] == spec)
            info.func = function()
                Whisper(selected, "talents spec " .. spec)
                Log(string.format("|cffffd100Spec|r -> %s (%s)", selected, spec))
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    f.specDrop = drop

    Label(f, "ORDERS", R, -146)
    local x = { R, R + 82, R + 164, R + 246 }
    Button(f, "Follow", 78, x[1], -160, function() Order("follow", "Follow") end, "Follow you.")
    Button(f, "Stay", 78, x[2], -160, function() Order("stay", "Stay") end, "Hold position here.")
    Button(f, "Attack", 78, x[3], -160, function() Order("attack", "Attack") end, "Attack your current target.")
    Button(f, "Flee", 78, x[4], -160, function() Order("flee", "Flee") end, "Break off combat and run back to you.")
    Button(f, "Summon", 78, x[1], -186, function() Order("summon", "Summon") end,
        "Bring the bot to you, if the realm allows bot summoning here.")
    Button(f, "Passive", 78, x[2], -186, function() Order("co +passive", "Passive") end,
        "Stop attacking on its own. Good for escorts and pulls.")
    Button(f, "Aggressive", 78, x[3], -186, function() Order("co -passive", "Aggressive") end,
        "Fight normally again.")
    Button(f, "Release", 78, x[4], -186, function() Order("release", "Release") end,
        "A dead bot releases its spirit.")

    Label(f, "UPKEEP", R, -218)
    Button(f, "Bag upgrades", 120, x[1], -232, function() Order("equip upgrade", "Bag upgrades") end,
        "Equip eligible upgrades already carried in bags. No items are created, bought or granted; this does not clear bag space.")
    Button(f, "Repair vendor", 120, x[1] + 124, -232, RequestVendorRepair,
        "Repair damaged gear at a nearby repair vendor using the bot's coins. No supplies, training or bag cleanup. The bot must confirm payment before a repair request is sent.")

    Label(f, "PARTY", R, -264)
    f.addClass = "warrior"
    local classDrop = CreateFrame("Frame", "RebirthBotManagerClassDrop", f, "UIDropDownMenuTemplate")
    classDrop:SetPoint("TOPLEFT", R - 16, -276)
    UIDropDownMenu_SetWidth(classDrop, 110)
    UIDropDownMenu_Initialize(classDrop, function()
        for _, entry in ipairs(ADDCLASS_ORDER) do
            local info = UIDropDownMenu_CreateInfo()
            local token, arg = entry[1], entry[2]
            local r, g, b = ClassColor(token)
            info.text = string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255,
                (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[token]) or token)
            info.checked = (f.addClass == arg)
            info.func = function()
                f.addClass = arg
                UIDropDownMenu_SetText(classDrop, info.text)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetText(classDrop, LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE.WARRIOR or "Warrior")
    Button(f, "Add class", 90, R + 138, -278, function()
        ServerCommand(".playerbots bot addclass " .. f.addClass)
        Log("|cffffd100Add class|r -> available " .. f.addClass .. " bot")
        RequestRoster(true)
    end, "Request an available realm class bot. This does not create one of your saved companions.")
    f.loginButton = Button(f, "Log in", 78, x[1], -306, function()
        if not selected then return end
        if roster[selected] and roster[selected].online then
            ServerCommand(".playerbots bot remove " .. selected)
            Log("|cffffd100Log out|r -> " .. selected)
        else
            ServerCommand(".playerbots bot add " .. selected)
            Log("|cffffd100Log in|r -> " .. selected)
        end
        RequestRoster(true)
    end)
    Button(f, "Leave group", 100, x[2], -306, function() Order("leave", "Leave group") end,
        "The bot leaves your group.")
    Button(f, "Status", 78, x[2] + 104, -306, function()
        for _, name in ipairs(Targets()) do
            quietUntil[name:lower()] = Now() + QUIET_SECONDS
            Whisper(name, "talents")
        end
    end, "Ask for each bot's current spec.")

    -- Bottom: what the bots said back.
    local logBox = Inset(f)
    logBox:SetPoint("TOPLEFT", R - 4, -336)
    logBox:SetPoint("BOTTOMRIGHT", -18, 18)
    local log = CreateFrame("ScrollingMessageFrame", nil, logBox)
    log:SetPoint("TOPLEFT", 8, -6)
    log:SetPoint("BOTTOMRIGHT", -8, 6)
    log:SetFontObject(GameFontHighlightSmall)
    log:SetJustifyH("LEFT")
    log:SetMaxLines(60)
    log:SetFading(false)
    log:EnableMouseWheel(true)
    log:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then self:ScrollUp() else self:ScrollDown() end
    end)
    f.log = log

    f:SetScript("OnShow", function() RequestRoster(false) Refresh() end)
    return f
end

function Refresh()
    local f = Manager
    if not f or not f:IsShown() then return end
    local inGroup = GroupNames()

    -- Row 1 is always "all bots in your group".
    local entries = { false }
    for _, name in ipairs(rosterOrder) do table.insert(entries, name) end
    FauxScrollFrame_Update(f.scroll, #entries, VISIBLE_ROWS, ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(f.scroll)
    for i = 1, VISIBLE_ROWS do
        local row, entry = f.rows[i], entries[i + offset]
        if entry == nil then
            row:Hide()
        else
            row:Show()
            row.botName = entry or nil
            if not entry then
                row.icon:SetTexture("Interface\\Icons\\INV_Misc_GroupNeedMore")
                row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                row.name:SetText("All bots in group")
                row.name:SetTextColor(1, 0.82, 0)
                row.icon:SetDesaturated(false)
                row.role:Hide()
                ShowIf(row.selectedTex, selected == nil)
            else
                local bot = roster[entry]
                local coords = bot.class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[bot.class]
                row.icon:SetTexture(CLASS_TEXTURE)
                if coords then row.icon:SetTexCoord(unpack(coords)) end
                row.icon:SetDesaturated(not bot.online)
                local label = entry
                if bot.online and not inGroup[entry] then label = entry .. " |cff9d9d9d(away)|r" end
                if not bot.online then label = entry .. " |cff9d9d9d(offline)|r" end
                row.name:SetText(label)
                if bot.online then row.name:SetTextColor(ClassColor(bot.class))
                else row.name:SetTextColor(0.5, 0.5, 0.5) end
                local role = currentRole[entry]
                if role and bot.online then
                    row.role:SetTexCoord(RoleCoords(role))
                    row.role:Show()
                else
                    row.role:Hide()
                end
                ShowIf(row.selectedTex, selected == entry)
            end
        end
    end
    ShowIf(f.empty, #rosterOrder == 0)

    local online, grouped = 0, 0
    for _, name in ipairs(rosterOrder) do
        if roster[name].online then
            online = online + 1
            if inGroup[name] then grouped = grouped + 1 end
        end
    end
    f.count:SetText(string.format("%d online, %d in group", online, grouped))

    -- Header and role buttons.
    local bot = selected and roster[selected]
    if bot then
        f.who:SetText(selected)
        f.who:SetTextColor(ClassColor(bot.class))
        local className = bot.class and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[bot.class] or "Bot"
        local spec = currentSpec[selected]
        if spec == "?" then spec = nil end
        f.whoSub:SetText(className .. (spec and (" - " .. spec) or "") .. (bot.online and "" or " - offline"))
        UIDropDownMenu_SetText(f.specDrop, (spec and specs[selected]) and spec or (specs[selected] and "Choose a spec" or "Reading specs..."))
        f.loginButton:SetText(bot.online and "Log out" or "Log in")
        f.loginButton:Enable()
    else
        f.who:SetText("All bots in group")
        f.who:SetTextColor(1, 0.82, 0)
        f.whoSub:SetText("Orders go to every bot in your group. Select a bot to set its role.")
        UIDropDownMenu_SetText(f.specDrop, "Select a bot")
        f.loginButton:SetText("Log in")
        f.loginButton:Disable()
    end
    for _, b in ipairs(f.roleButtons) do
        local allowed = bot and bot.online and (not bot.class or not CLASS_ROLES[bot.class] or CLASS_ROLES[bot.class][b.role])
        if allowed then b:Enable() b.icon:SetDesaturated(false) b.icon:SetAlpha(1)
        else b:Disable() b.icon:SetDesaturated(true) b.icon:SetAlpha(0.35) end
        ShowIf(b.glow, bot and currentRole[selected] == b.role or false)
    end
end

-- ── minimap button ───────────────────────────────────────────────────────

local function PlaceMinimapButton(button)
    local angle = math.rad(RebirthBotManagerDB.minimapAngle or 200)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * 80, math.sin(angle) * 80)
end

local function BuildMinimapButton()
    local b = CreateFrame("Button", "RebirthBotManagerMinimapButton", Minimap)
    b:SetWidth(31)
    b:SetHeight(31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetWidth(20)
    bg:SetHeight(20)
    bg:SetPoint("TOPLEFT", 7, -5)
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(MINIMAP_ICON)
    icon:SetWidth(20)
    icon:SetHeight(20)
    icon:SetPoint("TOPLEFT", 7, -5)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetWidth(53)
    border:SetHeight(53)
    border:SetPoint("TOPLEFT")
    b:SetScript("OnClick", function()
        if Manager:IsShown() then Manager:Hide() else Manager:Show() end
    end)
    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            RebirthBotManagerDB.minimapAngle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
            PlaceMinimapButton(self)
        end)
    end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Bot Manager", 1, 1, 1)
        GameTooltip:AddLine("Click to manage your bots. Drag to move.", nil, nil, nil, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    PlaceMinimapButton(b)
    ShowIf(b, not RebirthBotManagerDB.hideMinimap)
    return b
end

-- ── events ───────────────────────────────────────────────────────────────

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PARTY_MEMBERS_CHANGED")
events:RegisterEvent("RAID_ROSTER_UPDATE")
events:RegisterEvent("CHAT_MSG_SYSTEM")
events:RegisterEvent("CHAT_MSG_WHISPER")
events:RegisterEvent("CHAT_MSG_PARTY")
events:RegisterEvent("CHAT_MSG_PARTY_LEADER")
events:RegisterEvent("CHAT_MSG_RAID")
events:RegisterEvent("CHAT_MSG_RAID_LEADER")
events:SetScript("OnEvent", function(self, event, arg1, arg2)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON_NAME then return end
        if type(RebirthBotManagerDB) ~= "table" then RebirthBotManagerDB = {} end
        if type(RebirthBotManagerDB.partyNames) ~= "table" then
            RebirthBotManagerDB.partyNames = (UnitName("player") == "Thaladric")
                and { "Thalguard", "Thalgrace", "Thalspark", "Thalshade" } or {}
        end
        Manager = BuildManager()
        Manager.minimap = BuildMinimapButton()
        for _, e in ipairs({ "CHAT_MSG_WHISPER", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
                             "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER" }) do
            ChatFrame_AddMessageEventFilter(e, FilterIncoming)
        end
        ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", FilterOutgoing)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", FilterSystem)
    elseif event == "CHAT_MSG_SYSTEM" then
        local body = arg1:match("^Bot roster: (.*)$")
        if body then ParseRoster(body) end
    elseif event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
        if Manager and Manager:IsShown() then RequestRoster(false) Refresh() end
    elseif roster[arg2] then
        if event == "CHAT_MSG_WHISPER" then HandleRepairReply(arg2, arg1) end
        OnBotLine(arg2, arg1)
    end
end)

SLASH_REBIRTHBOTMANAGER1 = "/bots"
SLASH_REBIRTHBOTMANAGER2 = "/botmanager"
SlashCmdList.REBIRTHBOTMANAGER = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "minimap" then
        RebirthBotManagerDB.hideMinimap = not RebirthBotManagerDB.hideMinimap
        ShowIf(Manager.minimap, not RebirthBotManagerDB.hideMinimap)
        Print("minimap button " .. (RebirthBotManagerDB.hideMinimap and "hidden" or "shown") .. ".")
        return
    end
    if Manager:IsShown() then Manager:Hide() else Manager:Show() end
end
