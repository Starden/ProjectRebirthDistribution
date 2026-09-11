-- Bundled Rebirth QA tools. No public chat, third-party service or SavedVariables report storage.
local PREFIX, VERSION = "PRBR", "1"
local active = false
local sequence = 0
local reference, referenceAt = "none", 0
local objectSequence, objectName, objectRequestedAt
local lastText, lastKey, lastHint
local readParts, readId
local window, editor
local markers = setmetatable({}, {__mode = "k"})

local function Notice(text)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff73e6ffRebirth:|r " .. text) end
end

local function Send(body)
    if not active or not UnitName("player") or not SendAddonMessage then return end
    local message = VERSION .. "\t" .. body
    if #PREFIX + #message + 1 > 255 then Notice("That request is too long."); return end
    SendAddonMessage(PREFIX, message, "WHISPER", UnitName("player"))
end

local function Plain(text)
    text = (text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", "")
    return text:gsub("[|%c]", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

local function AddId(tooltip, label, id, hint)
    if not active or not tooltip or not id or id <= 0 then return end
    if hint then reference, referenceAt = hint .. ":" .. tostring(id), GetTime() end
    local key = label .. tostring(id)
    if markers[tooltip] == key then return end
    markers[tooltip] = key
    tooltip:AddDoubleLine(label, tostring(id), 0.65, 0.65, 0.65, 1, 1, 1)
    if tooltip:IsShown() then tooltip:Show() end
end

local function Item(tooltip)
    if not active or not tooltip.GetItem then return end
    local _, link = tooltip:GetItem()
    AddId(tooltip, "Item ID", tonumber((link or ""):match("item:(%d+)")), "item")
end

local function Unit(tooltip)
    if not active or not tooltip.GetUnit then return end
    local _, token = tooltip:GetUnit()
    local guid = token and UnitGUID(token)
    if not guid or #guid ~= 18 then return end
    local kind = guid:sub(3, 6):upper()
    if kind == "F130" or kind == "F150" then
        AddId(tooltip, "NPC ID", tonumber(guid:sub(7, 12), 16), "npc")
    end
end

local function Spell(tooltip)
    if not active or not tooltip.GetSpell then return end
    local _, _, id = tooltip:GetSpell()
    AddId(tooltip, "Spell ID", tonumber(id), "spell")
end

local function Hook(tooltip)
    if not tooltip then return end
    tooltip:HookScript("OnTooltipCleared", function(self) markers[self] = nil end)
    tooltip:HookScript("OnTooltipSetItem", Item)
    tooltip:HookScript("OnTooltipSetUnit", Unit)
    tooltip:HookScript("OnTooltipSetSpell", Spell)
end
for _, tooltip in ipairs({GameTooltip, ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2}) do Hook(tooltip) end

local function CopyWindow(title, content)
    if not window then
        window = CreateFrame("Frame", "ProjectRebirthBugInbox", UIParent)
        window:SetSize(580, 430)
        window:SetPoint("CENTER")
        window:SetFrameStrata("DIALOG")
        window:SetClampedToScreen(true)
        window:SetMovable(true)
        window:EnableMouse(true)
        window:RegisterForDrag("LeftButton")
        window:SetScript("OnDragStart", window.StartMoving)
        window:SetScript("OnDragStop", window.StopMovingOrSizing)
        window:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", tile=true, tileSize=32, edgeSize=32,
            insets={left=11,right=12,top=12,bottom=11}})
        local heading = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        heading:SetPoint("TOP", 0, -20)
        window.heading = heading
        local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -4, -4)
        local scroll = CreateFrame("ScrollFrame", "ProjectRebirthBugInboxScroll", window, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 22, -52)
        scroll:SetPoint("BOTTOMRIGHT", -42, 44)
        editor = CreateFrame("EditBox", nil, scroll)
        editor:SetMultiLine(true)
        editor:SetAutoFocus(false)
        editor:SetFontObject(ChatFontNormal)
        editor:SetWidth(506)
        editor:SetHeight(310)
        editor:SetScript("OnEscapePressed", function() window:Hide() end)
        editor:SetScript("OnTextChanged", function(self) scroll:UpdateScrollChildRect() end)
        scroll:SetScrollChild(editor)
        local help = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        help:SetPoint("BOTTOM", 0, 22)
        help:SetText("Click the text, then Ctrl+A and Ctrl+C to copy. /br read <number> opens a report.")
        tinsert(UISpecialFrames, "ProjectRebirthBugInbox")
    end
    window.heading:SetText(title)
    editor:SetText(content)
    editor:SetCursorPosition(0)
    window:Show()
end

local function Submit(text)
    text = Plain(text)
    if text == "" or #text > 180 then
        Notice("Use /br followed by a short description (up to 180 bytes). Please do not include passwords or personal contact details.")
        return
    end
    -- A retry of the same pending text uses the same key and tooltip hint, even after moving.
    if text ~= lastText or not lastKey then
        sequence = sequence + 1
        lastKey = string.format("%x-%x-%x", time(), math.random(1, 0xFFFFFF), sequence)
        lastText = text
        lastHint = GetTime() - referenceAt <= 30 and reference or "none"
    end
    Send("REPORT\t" .. lastKey .. "\t" .. lastHint .. "\t" .. lastText)
end

SLASH_PROJECTREBIRTHBUGS1 = "/br"
SlashCmdList.PROJECTREBIRTHBUGS = function(text)
    active = GetRealmName() == "Rebirth"
    if not active then Notice("Bug reporting is available on the Rebirth realm only."); return end
    text = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if text == "inbox" then Send("LIST\t0"); return end
    local command, id = text:match("^(read)%s+(%d+)$")
    if not command then command, id = text:match("^(close)%s+(%d+)$") end
    if not command then command, id = text:match("^(reopen)%s+(%d+)$") end
    if not command then command, id = text:match("^(older)%s+(%d+)$") end
    if command then Send((command == "older" and "LIST" or command:upper()) .. "\t" .. id); return end
    if text == "" or text == "help" then
        Notice("/br <description> sends Admin a private report with your location and recent tooltip ID. Admin: /br inbox, /br read <number>, /br close <number>, /br reopen <number>, /br older <number>.")
        return
    end
    Submit(text)
end

local rows
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:SetScript("OnEvent", function(_, event, prefix, message, channel, sender)
    if event ~= "CHAT_MSG_ADDON" then
        active = GetRealmName() == "Rebirth"
        if not active and window then window:Hide() end
        return
    end
    if not active or prefix ~= PREFIX or channel ~= "WHISPER" or sender ~= UnitName("player") then return end
    local version, action, body = message:match("^([^\t]+)\t([^\t]+)\t?(.*)$")
    if version ~= VERSION then return end
    if action == "ACK" then
        Notice("Bug report #" .. body .. " saved privately for Admin. Thank you!")
        lastText, lastKey, lastHint = nil, nil, nil
    elseif action == "ERROR" or action == "NOTICE" then Notice(body)
    elseif action == "LISTBEGIN" then rows = {}
    elseif action == "ROW" and rows then
        local id, status, text = body:match("^(%d+)\t([^\t]+)\t(.*)$")
        if id then rows[#rows+1] = "#" .. id .. " [" .. status .. "] " .. text end
    elseif action == "LISTEND" and rows then
        CopyWindow("Private Bug Reports", #rows > 0 and table.concat(rows, "\n\n") ..
            "\n\nUse /br older <lowest number above> for the next page." or "No reports yet.")
        rows = nil
    elseif action == "READBEGIN" then readParts, readId = {}, body
    elseif action == "READPART" and readParts then readParts[#readParts+1] = body
    elseif action == "READEND" and readParts and body == readId then
        CopyWindow("Bug Report #" .. body, table.concat(readParts)); readParts, readId = nil, nil
    elseif action == "OBJECT" or action == "AMBIGUOUS" then
        local seq, id = body:match("^(%d+)\t?(%d*)$")
        if seq ~= objectSequence or not GameTooltip:IsShown() or
            not GameTooltipTextLeft1 or Plain(GameTooltipTextLeft1:GetText()) ~= objectName then return end
        local _, unit = GameTooltip:GetUnit()
        local _, item = GameTooltip:GetItem()
        if unit or item then return end
        if action == "OBJECT" then AddId(GameTooltip, "Object ID (nearby name match)", tonumber(id), "object")
        elseif not markers[GameTooltip] then
            markers[GameTooltip] = "ambiguous"
            GameTooltip:AddLine("Multiple nearby objects share this name; ID is ambiguous.", 0.8, 0.8, 0.8, true)
        end
    end
end)

local elapsed = 0
frame:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed < 1 then return end
    elapsed = 0
    if not active or not GameTooltip or not GameTooltip:IsShown() or not GameTooltipTextLeft1 then return end
    local _, unit = GameTooltip:GetUnit()
    local _, item = GameTooltip:GetItem()
    local _, _, spell = GameTooltip:GetSpell()
    if unit or item or spell then return end
    -- Only world-owned tooltips, never unrelated menu/help text.
    if GameTooltip:GetOwner() ~= UIParent and GameTooltip:GetOwner() ~= WorldFrame then return end
    local name = Plain(GameTooltipTextLeft1:GetText())
    if name == "" or #name > 96 then return end
    if objectName == name and objectRequestedAt and GetTime() - objectRequestedAt < 5 then return end
    sequence = sequence + 1
    objectSequence, objectName, objectRequestedAt = tostring(sequence), name, GetTime()
    Send("ID\t" .. objectSequence .. "\t" .. objectName)
end)
