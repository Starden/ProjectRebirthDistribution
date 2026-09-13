-- Enhancement Stones: the server wallet presented in Blizzard's native Currency UI.
-- Decimal strings are intentional: Lua 5.1 numbers cannot preserve a uint64 wallet.
local PREFIX, NAME = "PRSC", "Enhancement Stones"
local ICON = "Interface\\Icons\\INV_Misc_Gem_Bloodstone_02"
local active, installed, balance, revision, cursor, received
local serial, due, pending, batch = 0, 0, nil, nil
local settings, native = {}, {}
local frame = CreateFrame("Frame")
local MAX = "18446744073709551615"

local function Decimal(s)
    return type(s) == "string" and s:match("^%d+$") and #s <= 20 and
        (#s == 1 or s:sub(1, 1) ~= "0") and (#s < 20 or s <= MAX)
end
local function Compare(a, b)
    if #a ~= #b then return #a < #b and -1 or 1 end
    return a == b and 0 or (a < b and -1 or 1)
end
local function Format(s)
    if not s then return "Unavailable" end
    local result = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return result:gsub("^,", "")
end
local function Fresh() return received and GetTime() - received < 15 end
local function Header() return native.size() + 1 end
local function Own(index) return active and not settings.collapsed and index == Header() + 1 end
local function WatchedIndex()
    if not settings.watched then return nil end
    for i = 1, 3 do
        if not native.backpack(i) then return i end
    end
end

local function Tooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(NAME, 1, 0.82, 0)
    GameTooltip:AddLine("Used at an upgrade anvil to improve your equipment.", 1, 1, 1, true)
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine(Fresh() and "Total" or "Last known total", Format(balance), 1, 0.82, 0, 1, 1, 1)
    if not Fresh() then
        GameTooltip:AddLine("Waiting for your balance from the realm.", 0.7, 0.7, 0.7, true)
    end
    GameTooltip:AddLine("Stored for this character. Kept through Rebirth.", 0.7, 0.7, 0.7, true)
    GameTooltip:Show()
end

local function Hover(button, test)
    if not button or button.rebirthCurrencyHover then return end
    button.rebirthCurrencyHover = true
    local old = button:GetScript("OnEnter")
    button:SetScript("OnEnter", function(self, ...)
        if test(self) then Tooltip(self) elseif old then old(self, ...) end
    end)
    local leave = button:GetScript("OnLeave")
    button:SetScript("OnLeave", function(self, ...)
        if test(self) then GameTooltip:Hide() elseif leave then leave(self, ...) end
    end)
end

local function Decorate()
    if not active then return end
    local container = TokenFrameContainer
    if container and container.buttons then
        for _, button in ipairs(container.buttons) do
            Hover(button.LinkButton, function(self) return Own(self:GetParent().index) end)
            Hover(button, function(self) return Own(self.index) end)
            -- Restore each recycled native row before applying our width adjustment.
            if button.rebirthCurrencyWidth then
                button.name:SetWidth(button.rebirthCurrencyWidth)
                button.rebirthCurrencyWidth = nil
            end
            if Own(button.index) and button.name and button.count then
                button.rebirthCurrencyWidth = button.name:GetWidth()
                button.name:SetWidth(math.max(60, button:GetWidth() - button.count:GetStringWidth() - 52))
            end
        end
    end
    for i = 1, 3 do
        local button = _G["BackpackTokenFrameToken" .. i]
        Hover(button, function(self) return WatchedIndex() == self:GetID() end)
    end
end

local function Refresh()
    if not active then return end
    if TokenFrame_Update then TokenFrame_Update() end
    if BackpackTokenFrame_Update then BackpackTokenFrame_Update() end
    if ManageBackpackTokenFrame then ManageBackpackTokenFrame() end
    Decorate()
end

local function InstallTokenHooks()
    if installed or not active or not TokenFrame_Update then return end
    installed = true
    hooksecurefunc("TokenFrame_Update", Decorate)
    hooksecurefunc("BackpackTokenFrame_Update", Decorate)
    -- HybridScrollFrame retains a function reference created before our hook.
    TokenFrameContainer.update = function() TokenFrame_Update() end
    GetNumWatchedTokens = function()
        local count = 0
        for i = 1, 3 do if GetBackpackCurrencyInfo(i) then count = count + 1 end end
        return count
    end
    local oldLink = TokenButtonLinkButton_OnClick
    TokenButtonLinkButton_OnClick = function(self, button, ...)
        if Own(self:GetParent().index) then
            if IsModifiedClick("CHATLINK") then ChatEdit_InsertLink("[" .. NAME .. "]") end
        elseif oldLink then return oldLink(self, button, ...) end
    end
    local oldBackpack = BackpackTokenButton_OnClick
    BackpackTokenButton_OnClick = function(self, ...)
        if WatchedIndex() == self:GetID() then
            if IsModifiedClick("CHATLINK") then ChatEdit_InsertLink("[" .. NAME .. "]") end
        elseif oldBackpack then return oldBackpack(self, ...) end
    end
    Refresh()
end

local function InstallList()
    native.size, native.info = GetCurrencyListSize, GetCurrencyListInfo
    native.expand, native.unused, native.watch = ExpandCurrencyList, SetCurrencyUnused, SetCurrencyBackpack
    native.backpack = GetBackpackCurrencyInfo
    GetCurrencyListSize = function() return native.size() + (settings.collapsed and 1 or 2) end
    GetCurrencyListInfo = function(index)
        if index == Header() then
            return settings.inactive and "Project Reverie (Inactive)" or "Project Reverie", true,
                not settings.collapsed, settings.inactive, false, 0
        elseif Own(index) then
            local count = Fresh() and (balance == "0" and 0 or Format(balance)) or "?"
            return NAME, false, false, settings.inactive, WatchedIndex() ~= nil, count, 0, ICON, 0
        end
        return native.info(index)
    end
    ExpandCurrencyList = function(index, expand)
        if index == Header() then settings.collapsed = expand ~= 1
        else return native.expand(index, expand) end
    end
    SetCurrencyUnused = function(index, unused)
        if Own(index) then settings.inactive = unused == 1
        else return native.unused(index, unused) end
    end
    SetCurrencyBackpack = function(index, watch)
        if Own(index) then
            if watch == 1 then
                -- Respect the stock three-currency watch limit, including native tokens.
                local room = false
                for i = 1, 3 do if not native.backpack(i) then room = true end end
                if room then settings.watched = true end
            else settings.watched = false end
        else return native.watch(index, watch) end
    end
    GetBackpackCurrencyInfo = function(index)
        if index == WatchedIndex() then
            -- Stock code requires a number here and displays '*' above 99,999.
            -- Never convert a large wallet to a Lua number; tooltip retains all digits.
            local count = balance and #balance <= 5 and tonumber(balance) or 100000
            if not Fresh() then count = 100000 end
            return NAME, count, 0, ICON, 0
        end
        return native.backpack(index)
    end
end

local function Request()
    serial = serial + 1
    if serial > 999999999 then serial = 1 end
    pending = {nonce = tostring(serial), sent = GetTime()}
    batch = nil
    SendAddonMessage(PREFIX, "1\tGET\t" .. pending.nonce .. "\t" .. (cursor or "-"), "WHISPER", UnitName("player"))
    due = GetTime() + 2.5
end

local function Receive(message)
    local parts = {}
    for value in (message .. "\t"):gmatch("(.-)\t") do parts[#parts + 1] = value end
    if not pending or parts[1] ~= "1" or parts[3] ~= pending.nonce then return end
    local kind = parts[2]
    if kind == "ERROR" then
        pending, batch, received = nil, nil, nil
        due = GetTime() + 5
        Refresh()
    elseif kind == "BEGIN" and #parts == 7 and Decimal(parts[4]) and Decimal(parts[5]) and
        Decimal(parts[6]) and (parts[7] == "0" or parts[7] == "1") and
        (not revision or Compare(parts[5], revision) >= 0) and (not cursor or Compare(parts[6], cursor) >= 0) then
        batch = {balance = parts[4], revision = parts[5], cursor = parts[6], more = parts[7] == "1", gains = {}}
    elseif kind == "GAIN" and batch and #parts == 5 and Decimal(parts[4]) and Decimal(parts[5]) and
        parts[5] ~= "0" and cursor and #batch.gains < 16 then
        local last = batch.gains[#batch.gains]
        if Compare(parts[4], last and last.id or cursor) <= 0 or Compare(parts[4], batch.cursor) > 0 then
            batch = nil
        else batch.gains[#batch.gains + 1] = {id = parts[4], amount = parts[5]} end
    elseif kind == "END" and batch and #parts == 4 and parts[4] == tostring(#batch.gains) then
        local complete = batch
        balance, revision, cursor, received = complete.balance, complete.revision, complete.cursor, GetTime()
        pending, batch = nil, nil
        due = GetTime() + (complete.more and 2.1 or 2.5)
        Refresh()
        for _, credit in ipairs(complete.gains) do
            if DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage("You receive currency: [" .. NAME .. "] x" .. Format(credit.amount) .. ".", 0, 1, 0)
            end
        end
    end
end

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        if active or GetRealmName() ~= "Rebirth" then return end
        active = true
        ProjectRebirthProgressSettings = ProjectRebirthProgressSettings or {}
        ProjectRebirthProgressSettings.stoneCurrency = ProjectRebirthProgressSettings.stoneCurrency or {}
        settings = ProjectRebirthProgressSettings.stoneCurrency
        InstallList()
        -- Load the stock Currency page so new characters can see it even with zero tokens.
        if not TokenFrame_Update then LoadAddOn("Blizzard_TokenUI") end
        InstallTokenHooks()
        Request()
    elseif active and event == "ADDON_LOADED" and (...) == "Blizzard_TokenUI" then
        InstallTokenHooks()
    elseif active and event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        if prefix == PREFIX and channel == "WHISPER" and sender == UnitName("player") then Receive(message) end
    end
end)
local elapsed = 0
frame:SetScript("OnUpdate", function(self, delta)
    if not active then return end
    elapsed = elapsed + delta
    if elapsed < 0.25 then return end
    elapsed = 0
    local now = GetTime()
    if pending and now - pending.sent > 8 then pending, batch = nil, nil end
    if not pending and now >= due then Request() end
    if received and not Fresh() then received = nil; Refresh() end
end)
