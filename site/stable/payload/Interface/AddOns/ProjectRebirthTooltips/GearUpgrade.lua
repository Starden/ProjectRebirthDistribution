-- Realm-bundled presentation for the native, server-authoritative upgrade gossip.
-- RBUP1 is inert gossip text, never an addon-channel command or purchase authority.
ProjectRebirthGearUpgrade = {}
local ui = ProjectRebirthGearUpgrade
local window, selection, quote, pending, deadline
local rows = {}
local closeFromServer = false
local refreshing = false
local cacheWaiting, nextCachePoll = false, 0
local cacheRequests = {}
local ICON = "Interface\\Icons\\INV_Hammer_20"

local function RealmEnabled()
    return GetRealmName and GetRealmName() == "Rebirth"
end

function ui.ParseOptions(options)
    if type(options) ~= "table" or type(options[1]) ~= "string" then return nil end
    local marker = options[1]
    local mode = marker:match("^RBUP1|([IB])$")
    if mode then return { mode = mode } end
    local a,b,c,d,e,f,g,h,i = marker:match("^RBUP1|Q|(%d+)|(%d+)|(%d+)|(%d+)|(%d+)|(%d+)|(%d+)|(%d+)|([01])$")
    if not a then return nil end
    local result = { mode="Q", current=tonumber(a), target=tonumber(b), oldRank=tonumber(c),
        newRank=tonumber(d), oldLevel=tonumber(e), newLevel=tonumber(f), stones=g,
        copper=tonumber(h), canBuy=i == "1" }
    if result.current == 0 or result.target == 0 or result.newRank ~= result.oldRank + 1 or
        result.newRank > 5 or result.newLevel ~= result.oldLevel + 3 or
        result.copper > 2147483647 then return nil end
    return result
end

local function Money(copper)
    return string.format("%dg %ds %dc", math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100)
end

local function Label(parent, font, point, x, y, width)
    local text = parent:CreateFontString(nil, "OVERLAY", font)
    text:SetPoint(point, parent, point, x, y)
    if width then text:SetWidth(width); text:SetJustifyH("LEFT") end
    return text
end

local function Button(parent, text, width, callback)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetWidth(width); button:SetHeight(24); button:SetText(text)
    button:SetScript("OnClick", callback)
    return button
end

local function Panel(parent, width, height)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetWidth(width); panel:SetHeight(height)
    panel:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=32,edgeSize=12,
        insets={left=3,right=3,top=3,bottom=3}})
    panel:SetBackdropColor(0.08,0.08,0.08,0.95)
    return panel
end

-- Hiding the stock frame normally calls CloseGossip. Suppress only that OnHide
-- while retiring its panel; restore immediately, preserving all other gossip.
local function RetireStockGossip()
    if not GossipFrame or not GossipFrame:IsShown() then return end
    local onHide = GossipFrame:GetScript("OnHide")
    GossipFrame:SetScript("OnHide", nil)
    HideUIPanel(GossipFrame)
    GossipFrame:SetScript("OnHide", onHide)
end

local function SetBusy(value)
    pending = value
    if not window then return end
    window.upgrade:Disable()
    for _, row in ipairs(rows) do
        if value then row:Disable() else row:Enable() end
    end
    if value then window.choose:Disable() else window.choose:Enable() end
end

function ui.Select(index)
    if not selection or pending or not RealmEnabled() then return false end
    local options = {GetGossipOptions()}
    -- Validate the entire current menu identity, not just a recycled option index.
    if #options ~= #selection then return false end
    for i=1,#options do if options[i] ~= selection[i] then return false end end
    if not index or index < 2 or not options[index * 2 - 1] then return false end
    SetBusy(true)
    window.status:SetText("Waiting for the anvil...")
    SelectGossipOption(index)
    return true
end

local function Icon(parent)
    local button = CreateFrame("Button", nil, parent)
    button:SetWidth(58); button:SetHeight(58)
    button:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
    button.art = button:CreateTexture(nil, "ARTWORK")
    button.art:SetPoint("TOPLEFT",button,"TOPLEFT",5,-5)
    button.art:SetPoint("BOTTOMRIGHT",button,"BOTTOMRIGHT",-5,5)
    button.art:SetTexture(ICON)
    button:SetScript("OnEnter", function(self)
        if self.entry then GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetHyperlink("item:"..self.entry); GameTooltip:Show() end
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return button
end

local function Build()
    if window then return end
    window = CreateFrame("Frame", "ProjectRebirthGearUpgradeFrame", UIParent)
    window:Hide(); window:SetWidth(580); window:SetHeight(570)
    window:SetPoint("CENTER"); window:SetFrameStrata("DIALOG")
    window:SetClampedToScreen(true); window:EnableMouse(true); window:SetMovable(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart",function(self) self:StartMoving() end)
    window:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
    window:SetBackdrop({bgFile="Interface\\AchievementFrame\\UI-Achievement-StatsBackground",
        edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=false,edgeSize=24,
        insets={left=7,right=7,top=7,bottom=7}})
    window:SetBackdropColor(0.65,0.65,0.65,1)
    local titleBar=Panel(window,550,34); titleBar:SetPoint("TOP",0,-10)
    Label(titleBar,"GameFontNormalLarge","CENTER",0,0):SetText("Item Upgrade")
    local hammer=Icon(window)
    hammer:SetWidth(44); hammer:SetHeight(44); hammer:SetPoint("TOPLEFT",20,-4)
    local close=CreateFrame("Button",nil,window,"UIPanelCloseButton")
    close:SetPoint("TOPRIGHT",-6,-6)
    close:SetScript("OnClick",function() window:Hide() end)
    window:SetScript("OnHide",function()
        selection=nil; quote=nil; pending=nil; deadline=nil
        cacheWaiting=false; cacheRequests={}
        GameTooltip:Hide()
        if not closeFromServer then CloseGossip() end
    end)
    UISpecialFrames[#UISpecialFrames+1]="ProjectRebirthGearUpgradeFrame"
    window.oldIcon=Icon(window); window.oldIcon:SetPoint("TOPLEFT",110,-62)
    window.newIcon=Icon(window); window.newIcon:SetPoint("TOPRIGHT",-110,-62)
    local arrow=Label(window,"GameFontNormalLarge","TOP",0,-69)
    arrow:SetFont("Fonts\\FRIZQT__.TTF",40)
    arrow:SetText(">")
    window.left=Panel(window,263,332); window.left:SetPoint("TOPLEFT",17,-133)
    window.right=Panel(window,263,332); window.right:SetPoint("TOPRIGHT",-17,-133)
    for _, panel in ipairs({window.left,window.right}) do
        panel.heading=Label(panel,"GameFontHighlight","TOPLEFT",12,-12,239)
        panel.body=Label(panel,"GameFontHighlightSmall","TOPLEFT",12,-44,239)
        panel.body:SetHeight(276); panel.body:SetJustifyV("TOP")
    end
    window.cost=Label(window,"GameFontNormal","BOTTOMLEFT",22,72,530)
    window.status=Label(window,"GameFontHighlightSmall","BOTTOMLEFT",22,42,530)
    window.status:SetHeight(26); window.status:SetJustifyV("TOP")
    window.choose=Button(window,"Choose Item",140,function() ui.Select(window.chooseIndex) end)
    window.choose:SetPoint("BOTTOMLEFT",19,14)
    window.upgrade=Button(window,"Upgrade",140,function()
        if quote and quote.canBuy and deadline and GetTime()<deadline then ui.Select(window.upgradeIndex) end
    end)
    window.upgrade:SetPoint("BOTTOMRIGHT",-19,14)
    window.list=Panel(window,546,332); window.list:SetPoint("TOPLEFT",17,-133)
    for i=1,20 do
        local row=Button(window.list,"",512,function(self) ui.Select(self.optionIndex) end)
        row:SetPoint("TOPLEFT",16,-10-(i-1)*30)
        row:SetHeight(28); row:Hide(); rows[i]=row
    end
    window.page=1
    window.previous=Button(window,"Previous",90,function() window.page=window.page-1; ui.RenderList() end)
    window.previous:SetPoint("TOPLEFT",20,-100)
    window.next=Button(window,"Next",90,function() window.page=window.page+1; ui.RenderList() end)
    window.next:SetPoint("TOPRIGHT",-20,-100)
    window:SetScript("OnUpdate",function(self)
        RetireStockGossip()
        if quote and deadline and GetTime()>=deadline then
            self.upgrade:Disable(); self.status:SetText("This preview has expired. Choose the item again for a fresh price.")
        elseif quote and cacheWaiting and not pending and GetTime()>=nextCachePoll then
            nextCachePoll=GetTime()+0.5
            ui.RefreshQuote()
        end
    end)
end

local function ItemData(entry)
    local name,link,quality,level,required,class,subclass,stack,equip,texture = GetItemInfo(entry)
    return {name=name,link=link,quality=quality,level=level,required=required,subclass=subclass,
        equip=equip,texture=texture,stats=GetItemStats and GetItemStats("item:"..entry) or {}}
end

local function StatLabel(key)
    local label=_G[key]
    if not label then return key:gsub("ITEM_MOD_",""):gsub("_SHORT",""):gsub("_"," "):lower() end
    return label:gsub("%%[%d%.]*[dfs]",""):gsub("^%s+",""):gsub("%s+$","")
end

function ui.StatLines(current,target)
    local keys, seen = {}, {}
    for key in pairs(current or {}) do keys[#keys+1]=key; seen[key]=true end
    for key in pairs(target or {}) do if not seen[key] then keys[#keys+1]=key end end
    table.sort(keys)
    local oldLines,newLines={},{}
    for _,key in ipairs(keys) do
        local old,new=tonumber((current or {})[key]) or 0,tonumber((target or {})[key]) or 0
        local label=StatLabel(key)
        oldLines[#oldLines+1]=label..": "..old
        local delta=new-old
        newLines[#newLines+1]=label..": "..new..(delta>0 and " |cff20ff20(+"..delta..")|r" or "")
    end
    return oldLines,newLines
end

-- The native tooltip carries armor and weapon damage even where GetItemStats
-- does not. Copy only those real lines; do not derive proc/spell changes.
local scanner
local function Scanner()
    if not scanner then scanner=CreateFrame("GameTooltip","ProjectRebirthUpgradeScanner",UIParent,"GameTooltipTemplate") end
    return scanner
end

local function RequestItem(entry)
    -- Wrath's GetItemInfo may only inspect the cache. SetHyperlink requests the
    -- missing template. Bound requests to one per item per 2s until quote expiry;
    -- the 0.5s cache poll also works if GET_ITEM_INFO_RECEIVED never arrives.
    local now=GetTime()
    if not deadline or now>=deadline or (cacheRequests[entry] and now-cacheRequests[entry]<2) then return end
    cacheRequests[entry]=now
    local tooltip=Scanner()
    tooltip:SetOwner(UIParent,"ANCHOR_NONE"); tooltip:ClearLines()
    tooltip:SetHyperlink("item:"..entry); tooltip:Hide()
end

local function ExtraLines(entry)
    scanner=Scanner()
    scanner:SetOwner(UIParent,"ANCHOR_NONE"); scanner:ClearLines(); scanner:SetHyperlink("item:"..entry)
    local result={}
    local armorPattern = ARMOR_TEMPLATE and "^"..ARMOR_TEMPLATE:gsub("%%d","(%%d+)").."$"
    for i=2,scanner:NumLines() do
        local line=_G["ProjectRebirthUpgradeScannerTextLeft"..i]
        local text=line and line:GetText()
        if text and ((armorPattern and text:match(armorPattern)) or text:match("^%d+%s*%-%s*%d+%s")) then result[#result+1]=text end
    end
    scanner:Hide()
    return result
end

function ui.RefreshQuote()
    if not quote or refreshing then return end
    refreshing=true
    local old,new=ItemData(quote.current),ItemData(quote.target)
    window.oldIcon.entry=quote.current; window.newIcon.entry=quote.target
    window.oldIcon.art:SetTexture(old.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
    window.newIcon.art:SetTexture(new.texture or old.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
    window.left.heading:SetText("Item Level "..quote.oldLevel.."\nRank "..quote.oldRank.." / 5")
    window.right.heading:SetText("Item Level "..quote.newLevel.." |cff20ff20(+3)|r\nRank "..quote.newRank.." / 5")
    if not old.name or not new.name then
        cacheWaiting=true
        if not old.name then RequestItem(quote.current) end
        if not new.name then RequestItem(quote.target) end
        window.left.body:SetText((old.name or "Loading item...").."\n\nHover the icon for the full item tooltip.")
        window.right.body:SetText(new.name or "Loading upgraded item...")
        window.upgrade:Disable()
    else
        cacheWaiting=false
        local left,right=ui.StatLines(old.stats,new.stats)
        local before,after=ExtraLines(quote.current),ExtraLines(quote.target)
        for i,line in ipairs(before) do left[#left+1]=line end
        for i,line in ipairs(after) do right[#right+1]=(line~=before[i] and "|cff20ff20"..line.."|r" or line) end
        local hint="\n\nHover the item icon for the full tooltip."
        window.left.body:SetText(old.name.."\n\n"..table.concat(left,"\n")..hint)
        window.right.body:SetText(new.name.."\n\n"..table.concat(right,"\n")..hint)
        if quote.canBuy and not pending and deadline and GetTime()<deadline then window.upgrade:Enable() end
    end
    refreshing=false
end

function ui.RenderList()
    if not selection then return end
    local total=math.max(0,#selection/2-3)
    local pages=math.max(1,math.ceil(total/10))
    window.page=math.max(1,math.min(window.page,pages))
    for _,row in ipairs(rows) do row:Hide() end
    for i=1,10 do
        local index=3+(window.page-1)*10+i
        if selection[index*2-1] then
            local row=rows[i]; row.optionIndex=index; row:SetText(selection[index*2-1]); row:Show()
        end
    end
    if window.page>1 then window.previous:Enable() else window.previous:Disable() end
    if window.page<pages then window.next:Enable() else window.next:Disable() end
    window.status:SetText(total==0 and "No eligible unequipped items in your backpack." or
        "Choose an item from your backpack. Page "..window.page.." / "..pages)
end

function ui.OnGossip()
    local options={GetGossipOptions()}
    local parsed=RealmEnabled() and ui.ParseOptions(options)
    if not parsed then
        if window and window:IsShown() then closeFromServer=true; window:Hide(); closeFromServer=false end
        return
    end
    Build()
    selection=options; quote=nil; deadline=nil; pending=false
    cacheWaiting=false; nextCachePoll=GetTime()+0.5; cacheRequests={}
    window.page=1; window.upgradeIndex=nil; window.chooseIndex=nil
    for _,row in ipairs(rows) do row:Hide() end
    SetBusy(false)
    window.upgrade:Hide(); window.previous:Hide(); window.next:Hide()
    window.list:Hide(); window.left:Show(); window.right:Show()
    window.oldIcon.entry=nil; window.newIcon.entry=nil
    window.oldIcon.art:SetTexture(ICON); window.newIcon.art:SetTexture(ICON)
    window.cost:SetText(""); window.status:SetText("")
    window.choose:SetText("Choose Item"); window.choose:Show(); window.choose:Enable()
    if parsed.mode=="Q" then
        quote=parsed; deadline=GetTime()+28 -- server quote lasts 30s; expire early.
        window.cost:SetText("|TInterface\\Icons\\INV_Misc_Gem_02:20:20|t "..quote.stones..
            " Enhancement Stones    |TInterface\\MoneyFrame\\UI-GoldIcon:16:16|t "..Money(quote.copper))
        window.status:SetText(quote.canBuy and "Upgrading binds this item to you." or
            "Not enough Enhancement Stones or gold. Choose another item or return with more currency.")
        window.chooseIndex=quote.canBuy and 4 or 3
        if quote.canBuy then window.upgradeIndex=3; window.upgrade:Show() end
        ui.RefreshQuote()
    elseif parsed.mode=="B" then
        window.cost:SetText(options[3] or "")
        window.list:Show(); window.previous:Show(); window.next:Show(); window.choose:Hide()
        ui.RenderList()
    else
        window.left.heading:SetText("Improve Your Equipment")
        window.right.heading:SetText("Choose an Item")
        window.left.body:SetText(options[3] or "")
        window.right.body:SetText("Place the item in your backpack, then choose it to see the next rank and its cost.\n\nUp to five ranks. Each rank adds 3 item levels and 3% of the original eligible stats.")
        window.chooseIndex=3
    end
    local scale=math.min(1,(UIParent:GetWidth()-24)/580,(UIParent:GetHeight()-24)/570)
    window:SetScale(math.max(0.5,scale)); window:Show(); RetireStockGossip()
end

local events=CreateFrame("Frame")
events:RegisterEvent("GOSSIP_SHOW"); events:RegisterEvent("GOSSIP_CLOSED")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED"); events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent",function(_,event)
    if event=="GOSSIP_SHOW" then ui.OnGossip()
    elseif event=="GET_ITEM_INFO_RECEIVED" then if window and window:IsShown() then ui.RefreshQuote() end
    elseif window and window:IsShown() then closeFromServer=true; window:Hide(); closeFromServer=false end
end)
