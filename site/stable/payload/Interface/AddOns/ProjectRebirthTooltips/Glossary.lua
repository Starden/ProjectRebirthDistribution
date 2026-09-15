-- Read-only catalog browser. Server snapshots, never catalog presence, establish ownership.
ProjectRebirthGlossary = {}
local G = ProjectRebirthGlossary
local rarityOrder = {Common=1,Uncommon=2,Rare=3,Epic=4,Legendary=5,Mythic=6}
local colors = {Common={.90,.90,.90},Uncommon={.12,1,.12},Rare={.15,.48,1},Epic={.64,.21,.93},Legendary={1,.50,.08},Mythic={.35,.90,1}}
local options = {search="", tier={}, rarity={}, ownership={}, group="Tier"}
local page, selected, frame, attachedParent = 1, nil, nil, nil
local PAGE_SIZE = 9

function G.Snapshot()
    local source = type(ProjectRebirth_GetGlossaryState) == "function" and ProjectRebirth_GetGlossaryState() or nil
    local result = {available=source and source.available == true or false, skills={}}
    if result.available then
        for _, skill in ipairs(source.skills or {}) do
            if tonumber(skill.id) and tonumber(skill.rank) then
                result.skills[tonumber(skill.id)] = {rank=tonumber(skill.rank), effects=skill.effects == true, operational=skill.operational == true}
            end
        end
    end
    return result
end

function G.Ownership(entry, snapshot)
    if not snapshot or not snapshot.available then return "Unknown", nil end
    local skill = snapshot.skills[entry.id]
    if not skill or skill.rank < 1 then return "Not owned", nil end
    if skill.rank >= 5 then return "Mastered this Life", skill end
    return "Owned", skill
end

function G.Group(entry, grouping, snapshot)
    if grouping == "Tier" then return "Tier " .. entry.tier, entry.tier end
    if grouping == "Rarity" then return entry.rarity, rarityOrder[entry.rarity] or 99 end
    if grouping == "Mastery" then
        local owned = G.Ownership(entry, snapshot)
        local order = {['Mastered this Life']=1,Owned=2,['Not owned']=3,Unknown=4}
        return owned, order[owned]
    end
    if grouping == "Category" then return entry.category, entry.category:lower() end
    return entry.name:sub(1,1):upper(), entry.name:sub(1,1):lower()
end

local function facetMatches(selection, value)
    if type(selection) == "table" then return next(selection) == nil or selection[value] == true end
    -- Preserve scalar callers; the UI stores explicit sets. An empty set means All.
    return selection == nil or selection == 0 or selection == "All" or selection == value
end

function G.Filter(data, filter, snapshot)
    local result = {}
    local search = (filter.search or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    for _, entry in ipairs(data or {}) do
        local owned = G.Ownership(entry, snapshot)
        local matchesOwned = facetMatches(filter.ownership, owned)
            or (owned == "Mastered this Life" and facetMatches(filter.ownership, "Owned"))
        local matchesSearch = search == "" or (entry.name .. "\n" .. entry.description):lower():find(search, 1, true)
        if facetMatches(filter.tier, entry.tier)
            and facetMatches(filter.rarity, entry.rarity)
            and matchesOwned and matchesSearch then result[#result+1] = entry end
    end
    table.sort(result, function(a,b)
        local _, ak = G.Group(a, filter.group or "Tier", snapshot)
        local _, bk = G.Group(b, filter.group or "Tier", snapshot)
        if ak ~= bk then return ak < bk end
        if a.name:lower() ~= b.name:lower() then return a.name:lower() < b.name:lower() end
        return a.id < b.id
    end)
    return result
end

local function label(parent, text, x, y, width, font)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetWidth(width)
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    return fs
end

local function button(parent, text, x, y, width, callback)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 23)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    b:SetText(text)
    b:SetScript("OnClick", callback)
    return b
end

local function detail(entry, snapshot)
    if not entry then return "Select a Skill", "Choose a skill on the left to view its effects and current-Life status." end
    local owned, skill = G.Ownership(entry, snapshot)
    local parts = {ProjectRebirthSkillPresentation.Meta(entry.rarity, entry.tier),
        owned == "Unknown" and "Ownership unknown" or owned}
    if skill then
        parts[#parts+1] = "Current rank: " .. skill.rank .. "/5"
        if not skill.effects or not skill.operational then parts[#parts+1] = "Currently inactive." end
    end
    parts[#parts+1] = ProjectRebirthSkillPresentation.Effect(entry.id)
    if entry.requirement and entry.requirement ~= "" then parts[#parts+1] = "Requires: " .. entry.requirement end
    return entry.name, table.concat(parts, "\n\n")
end
G.Detail = detail

function G.Refresh()
    if not frame or not frame:IsShown() then return end
    local snapshot = G.Snapshot()
    local data = ProjectRebirthGlossaryData or {}
    local results = G.Filter(data, options, snapshot)
    local pages = math.max(1, math.ceil(#results / PAGE_SIZE))
    page = math.min(math.max(page, 1), pages)
    local found = false
    for _, entry in ipairs(results) do if selected == entry.id then found = true; break end end
    if not found then
        selected = results[1] and results[1].id or nil
        frame.detailScroll:SetVerticalScroll(0)
    end
    local current
    for _, entry in ipairs(results) do if entry.id == selected then current = entry; break end end
    for index, row in ipairs(frame.rows) do
        local entry = index <= PAGE_SIZE and results[(page-1)*PAGE_SIZE+index] or nil
        row.entry = entry
        if entry then
            local group = G.Group(entry, options.group, snapshot)
            local owned, live = G.Ownership(entry, snapshot)
            local card = ProjectRebirthSkillData and ProjectRebirthSkillData[entry.id]
            row.icon:SetTexture(card and card.icon or "Interface\\Icons\\INV_Misc_Book_09")
            row.title:SetText(entry.name)
            local c = colors[entry.rarity] or {.65,.65,.65}
            row.title:SetTextColor(c[1],c[2],c[3])
            row.subtitle:SetText(group .. "  |  " .. owned .. (live and ("  " .. live.rank .. "/5") or ""))
            row.selection:SetAlpha(entry.id == selected and .35 or 0)
            row:Show()
        else row:Hide() end
    end
    frame.count:SetText(#results .. " matches / " .. #data .. " catalog skills")
    frame.pageText:SetText("Page " .. page .. " / " .. pages)
    if page > 1 then frame.previous:Enable() else frame.previous:Disable() end
    if page < pages then frame.next:Enable() else frame.next:Disable() end
    frame.state:SetText(snapshot.available and "Showing Skills owned this Life." or "Ownership unknown — refreshing your Skills.")
    local title, body = detail(current, snapshot)
    frame.detailTitle:SetText(title)
    frame.detailText:SetText(body)
    frame.detailChild:SetHeight(math.max(350, frame.detailText:GetStringHeight()+15))
    frame.detailScroll:UpdateScrollChildRect()
end

local function dropdown(parent, key, values, prefix, x, width)
    local control = CreateFrame("Frame", "ProjectRebirthGlossaryFilter" .. key, parent, "UIDropDownMenuTemplate")
    control:SetPoint("TOPLEFT", parent, "TOPLEFT", x-16, -65)
    UIDropDownMenu_SetWidth(control, width)
    local multiple = key ~= "group" -- Grouping changes order, not the result-set filter.
    local function update()
        if multiple then
            local count, only = 0, nil
            for value in pairs(options[key]) do count=count+1; only=value end
            UIDropDownMenu_SetSelectedValue(control, nil)
            UIDropDownMenu_SetText(control, prefix .. (count==0 and "All" or count==1 and tostring(only) or count .. " selected"))
        else
            UIDropDownMenu_SetSelectedValue(control, options[key])
            UIDropDownMenu_SetText(control, prefix .. tostring(options[key]))
        end
    end
    UIDropDownMenu_Initialize(control, function(self, level)
        for _, value in ipairs(values) do
            local selectedValue = value
            local info = UIDropDownMenu_CreateInfo()
            local isAll = value == 0 or value == "All"
            info.text = isAll and "All (clear selections)" or tostring(value)
            info.value = value
            info.isNotRadio = multiple
            info.keepShownOnClick = multiple
            if multiple then
                info.checked = function()
                    return isAll and next(options[key]) == nil or (not isAll and options[key][selectedValue] == true)
                end
            else
                info.checked = options[key] == value
            end
            info.func = function()
                if multiple then
                    if isAll then options[key] = {}
                    elseif options[key][selectedValue] then options[key][selectedValue] = nil
                    else options[key][selectedValue] = true end
                else options[key] = selectedValue end
                page = 1
                update()
                if multiple then
                    -- Native Refresh reevaluates all checked callbacks, including All, without closing.
                    if UIDropDownMenu_Refresh then UIDropDownMenu_Refresh(control, nil, level) end
                else CloseDropDownMenus() end
                G.Refresh()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    update()
    parent.filters = parent.filters or {}
    parent.filters[#parent.filters+1] = {update=update, control=control, x=x}
end

local function place(widget,parent,x,y)
    widget:ClearAllPoints()
    widget:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
end

local function layoutEmbedded()
    local width,height=attachedParent:GetWidth(),attachedParent:GetHeight()
    frame:SetScale(1)
    frame:SetSize(width,height)
    local left=math.floor(width*.48)
    local rightX=left+16
    local rightWidth=width-rightX-30
    -- Native-size controls remain readable; smaller hosts get fewer rows per page.
    PAGE_SIZE=math.max(1,math.min(9,math.floor((height-185)/35)))
    place(frame.searchLabel,frame,16,-14)
    place(frame.search,frame,76,-8)
    frame.search:SetWidth(left-100)
    place(frame.searchHint,frame,rightX,-14)
    frame.searchHint:SetWidth(rightWidth)
    for _,filter in ipairs(frame.filters) do place(filter.control,frame,filter.x-16,-33) end
    place(frame.reset,frame,714,-37)
    place(frame.count,frame,16,-70)
    frame.count:SetWidth(left-30)
    for i,row in ipairs(frame.rows) do
        place(row,frame,16,-90-(i-1)*35)
        row:SetSize(left-30,35)
        place(row.title,row,42,-1)
        place(row.subtitle,row,42,-18)
        row.title:SetWidth(left-75)
        row.subtitle:SetWidth(left-75)
    end
    place(frame.detailTitle,frame,rightX,-70)
    frame.detailTitle:SetWidth(rightWidth)
    place(frame.detailScroll,frame,rightX,-113)
    frame.detailScroll:SetSize(rightWidth-15,height-155)
    frame.detailChild:SetWidth(rightWidth-22)
    frame.detailText:SetWidth(rightWidth-27)
    place(frame.previous,frame,16,-height+78)
    place(frame.pageText,frame,125,-height+71)
    frame.pageText:SetWidth(left-240)
    place(frame.next,frame,left-109,-height+78)
    place(frame.state,frame,16,-height+30)
    frame.state:SetWidth(width-32)
end

local function create()
    frame = CreateFrame("Frame", "ProjectRebirthSkillGlossary", UIParent)
    frame:SetSize(940, 610)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=32,insets={left=11,right=12,top=12,bottom=11}})
    frame:SetBackdropColor(1,1,1,1)
    frame.title = label(frame,"Skill Glossary",23,-19,700,"GameFontNormalLarge")
    local close = CreateFrame("Button",nil,frame,"UIPanelCloseButton")
    close:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-5,-5)
    close:SetScript("OnClick",function() frame:Hide() end)
    frame.close = close
    UISpecialFrames[#UISpecialFrames+1] = "ProjectRebirthSkillGlossary"
    frame.searchLabel=label(frame,"Search",24,-47,60)
    local search = CreateFrame("EditBox",nil,frame,"InputBoxTemplate")
    search:SetSize(370,22)
    search:SetPoint("TOPLEFT",frame,"TOPLEFT",84,-41)
    search:SetAutoFocus(false)
    search:SetMaxLetters(100)
    search:SetScript("OnTextChanged",function(self) options.search=self:GetText() or ""; page=1; G.Refresh() end)
    search:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    frame.search=search
    frame.searchHint=label(frame,"Name or effect text",477,-47,400,"GameFontHighlightSmall")
    dropdown(frame,"tier",{0,1,2,3,4,5},"Tier: ",24,80)
    dropdown(frame,"rarity",{"All","Common","Uncommon","Rare","Epic","Legendary","Mythic"},"Rarity: ",134,125)
    dropdown(frame,"ownership",{"All","Owned","Not owned","Mastered this Life","Unknown"},"Show: ",289,190)
    dropdown(frame,"group",{"Tier","Rarity","Mastery","Category","Alphabetical"},"Group: ",509,155)
    frame.reset=button(frame,"Reset filters",714,-69,128,function()
        search:SetText("")
        options.search=""; options.tier={}; options.rarity={}; options.ownership={}; options.group="Tier"
        for _, control in ipairs(frame.filters or {}) do control.update() end
        CloseDropDownMenus()
        page=1; G.Refresh()
    end)
    frame.count=label(frame,"",25,-104,430,"GameFontHighlightSmall")
    frame.rows={}
    for i=1,PAGE_SIZE do
        local row=CreateFrame("Button",nil,frame)
        row:SetSize(435,43)
        row:SetPoint("TOPLEFT",frame,"TOPLEFT",24,-124-(i-1)*45)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        row.selection=row:CreateTexture(nil,"BACKGROUND")
        row.selection:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        row.selection:SetAllPoints(row)
        row.icon=row:CreateTexture(nil,"ARTWORK")
        row.icon:SetSize(32,32)
        row.icon:SetPoint("LEFT",row,"LEFT",3,0)
        row.title=label(row,"",42,-4,390,"GameFontHighlight")
        -- A one-line rectangle lets the native FontString truncate overflow.
        row.title:SetHeight(14)
        row.subtitle=label(row,"",42,-24,390,"GameFontHighlightSmall")
        row.subtitle:SetHeight(12)
        row:SetScript("OnEnter",function(self)
            if not self.entry then return end
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
            GameTooltip:SetText(self.entry.name)
            GameTooltip:AddLine("Tier " .. self.entry.tier .. " - " .. self.entry.rarity,1,1,1,true)
            GameTooltip:AddLine(self.entry.category,1,1,1,true)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave",function() GameTooltip:Hide() end)
        row:SetScript("OnClick",function(self)
            if ProjectRebirthChatLinks and ProjectRebirthChatLinks.Try("Skill", self.entry.id, 0) then return end
            selected=self.entry.id; frame.detailScroll:SetVerticalScroll(0); G.Refresh()
        end)
        frame.rows[i]=row
    end
    frame.detailTitle=label(frame,"",485,-107,420,"GameFontNormalLarge")
    -- Reserve two native text lines before the detail scroll viewport.
    frame.detailTitle:SetHeight(36)
    frame.detailScroll=CreateFrame("ScrollFrame","ProjectRebirthGlossaryDetailScroll",frame,"UIPanelScrollFrameTemplate")
    frame.detailScroll:SetSize(405,380)
    frame.detailScroll:SetPoint("TOPLEFT",frame,"TOPLEFT",485,-149)
    frame.detailChild=CreateFrame("Frame",nil,frame.detailScroll)
    frame.detailChild:SetSize(398,391)
    frame.detailText=label(frame.detailChild,"",0,0,393,"GameFontHighlightSmall")
    frame.detailScroll:SetScrollChild(frame.detailChild)
    frame.previous=button(frame,"Previous",24,-536,95,function() page=page-1; G.Refresh() end)
    frame.pageText=label(frame,"",133,-543,203,"GameFontHighlightSmall")
    frame.next=button(frame,"Next",364,-536,95,function() page=page+1; G.Refresh() end)
    frame.state=label(frame,"",24,-572,890,"GameFontHighlightSmall")
    frame:SetScript("OnShow",function(self)
        if attachedParent then
            layoutEmbedded()
        else
            self:SetScale(math.min(1,(UIParent:GetWidth()-30)/940,(UIParent:GetHeight()-30)/610))
        end
        G.Refresh()
    end)
    G.Frame=frame
    frame:Hide()
end

-- The menu owns tab visibility. Attach never opens a second window or requests data.
function G.Attach(parent)
    if not parent or (GetRealmName and GetRealmName() ~= "Rebirth") then return nil end
    if not frame then create() end
    attachedParent = parent
    frame:Hide()
    frame:SetParent(parent)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT",parent,"TOPLEFT",0,0)
    frame:SetBackdrop(nil)
    frame:SetMovable(false)
    frame:SetClampedToScreen(false)
    frame:SetScript("OnDragStart",nil)
    frame:SetScript("OnDragStop",nil)
    frame.title:Hide()
    frame.close:Hide()
    layoutEmbedded()
    for i=#UISpecialFrames,1,-1 do
        if UISpecialFrames[i] == "ProjectRebirthSkillGlossary" then table.remove(UISpecialFrames,i) end
    end
    return frame
end

function G.Toggle()
    if GetRealmName and GetRealmName() ~= "Rebirth" then
        if frame then frame:Hide() end
        return
    end
    if not frame then create(); frame:Show(); G.Refresh()
    elseif frame:IsShown() then frame:Hide()
    else frame:Show() end
end
