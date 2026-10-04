-- Optional, read-only panel presentation. Version-3 commits are deliberately separate.
ProjectRebirthPanelProtocol = {}
local P = ProjectRebirthPanelProtocol
local pending, request = nil, 0
local transport, deliver, failure
local MAX64 = "18446744073709551615"
local function Number(value, low, high)
    if type(value) ~= "string" or not value:match("^%d+$") or
        (#value > 1 and value:sub(1,1) == "0") then return nil end
    local n = tonumber(value)
    if not n or n < low or n > high then return nil end
    return n
end
local function Decimal(value)
    if value == "unavailable" then return nil end
    if type(value) ~= "string" or not value:match("^%d+$") or
        (#value > 1 and value:sub(1,1) == "0") or #value > #MAX64 or
        (#value == #MAX64 and value > MAX64) then error("invalid decimal") end
    return value
end
local function Bool(value)
    if value == "1" then return true elseif value == "0" then return false
    elseif value == "unavailable" then return nil end
    error("invalid boolean")
end
local function Decode(value)
    if value:gsub("%%(%x%x)", ""):find("%%") then error("invalid escape") end
    return (value:gsub("%%(%x%x)", function(h) return string.char(tonumber(h,16)) end))
end
local function Split(value)
    local out = {}
    for field in (value .. "\t"):gmatch("(.-)\t") do out[#out+1] = field end
    return out
end
local function Text(value)
    if value:find("[%z\1-\8\11\12\14-\31\127]") then error("invalid text") end
    -- Server prose is data, never a client link/texture escape.
    return value:gsub("|", "||")
end
local function Parse(records, mode, id, level)
    local result = {heritages={}, skills={}, criteria={}, features={}, mode=mode, id=id, previewLevel=level}
    local deferred = {}
    local counts = {HERITAGE=17,ROW=4,SIGNATURE=6,MILESTONE=5,GROWTH=3,CHOICE=5,SKILL=9,CRITERION=4,FEATURE=4}
    for _, encoded in ipairs(records) do
        local fields = Split(Decode(encoded))
        for i,value in ipairs(fields) do fields[i] = Decode(value) end
        local kind = fields[1]
        if not counts[kind] or #fields ~= counts[kind] then error("invalid record") end
        if kind == "HERITAGE" then
            local key = Number(fields[2],1,2147483647)
            local rank, maximum = Number(fields[6],0,100), Number(fields[7],1,100)
            if not key or not rank or not maximum or rank > maximum or result.heritages[key] or
                (fields[3] ~= "legacy_heritage" and fields[3] ~= "bloodline" and fields[3] ~= "life") then error("invalid heritage") end
            result.heritages[key] = {id=key,kind=fields[3],name=Text(fields[4]),icon=Text(fields[5]),
                level=rank,maxLevel=maximum,status=Text(fields[8]),xp=Decimal(fields[9]),
                earnedXp=Decimal(fields[10]),nextXp=Decimal(fields[11]),remainingXp=Decimal(fields[12]),
                atCap=Bool(fields[13]),selected=Bool(fields[14]),eligible=Bool(fields[15]),
                ineligibleReason=Text(fields[16]),previewLevel=Number(fields[17],0,100),rows={},milestones={},choices={}}
        elseif kind == "SKILL" then
            local key,rank=Number(fields[2],1,2147483647),Number(fields[3],0,5)
            if not key or not rank or result.skills[key] or mode ~= "state" then error("invalid skill") end
            result.skills[key]={id=key,rank=rank,xp=Decimal(fields[4]),earnedXp=Decimal(fields[5]),
                nextXp=Decimal(fields[6]),remainingXp=Decimal(fields[7]),atCap=Bool(fields[8]),status=Text(fields[9])}
        elseif kind == "CRITERION" or kind == "FEATURE" then
            local pattern=kind=="FEATURE" and "^[%w_:]+$" or "^[%w_]+$"
            local prefix="heritage:"..tostring(id)..":"
            if #fields[2]>100 or not fields[2]:match(pattern) or
                (mode~="state" and (kind~="FEATURE" or fields[2]:sub(1,#prefix)~=prefix)) then error("invalid state record") end
            local bucket=kind=="CRITERION" and result.criteria or result.features
            for _,row in ipairs(bucket) do if row.key==fields[2] then error("duplicate key") end end
            bucket[#bucket+1]=kind=="CRITERION" and {key=fields[2],label=Text(fields[3]),met=Bool(fields[4])} or
                {key=fields[2],status=Text(fields[3]),detail=Text(fields[4])}
        else deferred[#deferred+1]=fields end
    end
    for _, fields in ipairs(deferred) do
        local owner = result.heritages[Number(fields[2],1,2147483647) or 0]
        if not owner then error("orphan record") end
        local kind=fields[1]
        if kind=="ROW" then owner.rows[#owner.rows+1]={label=Text(fields[3]),value=Text(fields[4])}
        elseif kind=="SIGNATURE" then
            if owner.signature then error("duplicate signature") end
            local rank=Number(fields[4],1,100);if not rank then error("signature rank") end
            owner.signature={name=Text(fields[3]),unlockLevel=rank,text=Text(fields[5]),active=Bool(fields[6])}
        elseif kind=="MILESTONE" then
            local rank=Number(fields[3],1,100);if not rank then error("milestone rank") end
            for _, row in ipairs(owner.milestones) do if row.rank==rank then error("duplicate milestone") end end
            owner.milestones[#owner.milestones+1]={rank=rank,text=Text(fields[4]),reached=Bool(fields[5])}
        elseif kind=="GROWTH" then
            if owner.growth then error("duplicate growth") end
            owner.growth=Text(fields[3])
        elseif kind=="CHOICE" then
            local ordinal=Number(fields[3],0,255);if not ordinal then error("choice ordinal") end
            for _,row in ipairs(owner.choices) do if row.ordinal==ordinal then error("duplicate choice") end end
            owner.choices[#owner.choices+1]={ordinal=ordinal,label=Text(fields[4]),selected=Bool(fields[5])}
        end
    end
    if mode=="preview" then
        local owner=result.heritages[id]
        if not owner or owner.previewLevel~=level then error("wrong preview") end
        for key in pairs(result.heritages) do if key~=id then error("mixed preview") end end
    end
    return result
end
-- Nine SKILL fields: kind, id, rank, xp, earned, next, remaining, cap, status.
local function Reject(reason)
    pending=nil
    if failure then failure(reason) end
    return false
end
function P.Attach(send, receive, reject) transport,deliver,failure=send,receive,reject end
function P.Cancel() pending=nil end
function P.Request(mode,id,level)
    if not P.Available or not transport or (mode~="state" and mode~="preview") then return false end
    request=request%4294967295+1
    pending={request=tostring(request),mode=mode,id=id or 0,level=level or 0,sent=GetTime(),parts={},bytes=0}
    transport("4\t"..(mode=="preview" and ("PANEL_PREVIEW\t"..request.."\t"..id.."\t"..level) or "PANEL_STATE\t"..request))
    return true
end
function P.RequestState() return P.Request("state") end
function P.RequestPreview(id,level)
    if not Number(tostring(id),1,2147483647) or not Number(tostring(level),1,100) then return false end
    return P.Request("preview",id,level)
end
function P.CheckTimeout()
    if pending and GetTime()-pending.sent>15 then return Reject("Panel details timed out; legacy values remain available.") end
end
function P.Receive(fields)
    if fields[1]~="4" then return false end
    if not pending or fields[3]~=pending.request then return false end
    if GetTime()-pending.sent>15 then return Reject("Panel details arrived too late.") end
    local kind=fields[2]
    if kind=="PANEL_ERROR" then
        if #fields~=4 or fields[4]~="presentation_unavailable" then return Reject("Invalid panel error.") end
        return Reject("Panel presentation unavailable; legacy values remain available.")
    elseif kind=="PANEL_BEGIN" then
        local count,bytes=Number(fields[4],1,256),Number(fields[5],1,65536)
        local id,level=Number(fields[7],0,2147483647),Number(fields[8],0,100)
        if #fields~=8 or not count or not bytes or fields[6]~=pending.mode or
            id~=pending.id or level~=pending.level or pending.count then return Reject("Invalid panel envelope.") end
        pending.count,pending.expectedBytes=count,bytes
    elseif kind=="PANEL_PART" then
        local index,part,total=Number(fields[4],1,256),Number(fields[5],1,23),Number(fields[6],1,23)
        if #fields~=7 or not pending.count or not index or index>pending.count or not part or not total or
            part>total or #fields[7]<1 or #fields[7]>180 then return Reject("Invalid panel chunk.") end
        local row=pending.parts[index]
        if not row then row={total=total,bytes=0};pending.parts[index]=row end
        if row.total~=total or (row[part] and row[part]~=fields[7]) then return Reject("Conflicting panel chunk.") end
        if row[part] then return true end
        row[part]=fields[7];row.bytes=row.bytes+#fields[7];pending.bytes=pending.bytes+#fields[7]
        if row.bytes>4096 or pending.bytes>pending.expectedBytes or pending.bytes>65536 then return Reject("Panel details exceed their bounds.") end
    elseif kind=="PANEL_END" then
        if #fields~=5 or Number(fields[4],1,256)~=pending.count or Number(fields[5],1,65536)~=pending.expectedBytes or
            pending.bytes~=pending.expectedBytes then return Reject("Incomplete panel details.") end
        local records={}
        for i=1,pending.count or 0 do
            local row=pending.parts[i];if not row then return Reject("Missing panel record.") end
            for n=1,row.total do if not row[n] then return Reject("Missing panel chunk.") end end
            records[i]=table.concat(row,"",1,row.total)
        end
        local ok,result=pcall(Parse,records,pending.mode,pending.id,pending.level)
        if not ok then return Reject("Invalid panel record data.") end
        pending=nil
        if deliver then deliver(result) end
    else return Reject("Unknown panel packet.") end
    return true
end
