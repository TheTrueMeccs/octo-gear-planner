local U = OBP.Util
OBP.Compat = {queue={},queued={},attempts={},elapsed=0}
local C = OBP.Compat
function C.Script(frame, eventName, callback)
    frame:SetScript(eventName,function(a,b,c,d)
        local current = type(a)=="table" and a or this
        if type(a)=="table" then callback(current,b,c,d)
        elseif eventName=="OnEvent" then callback(current,event,arg1,arg2)
        else callback(current,arg1,arg2,arg3) end
    end)
end
function C.Capabilities()
    return {classicAPI=CLASSIC_API_VERSION,superWoW=SUPERWOW_VERSION,
        effects=C_Spell and type(C_Spell.GetSpellEffectInfo)=="function",
        auras=C_UnitAuras and type(C_UnitAuras.GetAuraDataByIndex)=="function",
        itemData=C_Item and type(C_Item.GetItemDataByID)=="function",
        itemRequests=C_Item and type(C_Item.RequestLoadItemDataByID)=="function"}
end
function C.Link(itemID,enchantKey)
    local enchant = enchantKey and OBP.Data.enchants[enchantKey]
    return "item:"..itemID..":"..(enchant and enchant.enchantID or 0)..":0:0"
end
function C.Cached(id) return GetItemInfo and GetItemInfo(C.Link(id))~=nil end
function C.Request(id)
    if not id or C.Cached(id) or C.queued[id] or (C.attempts[id] or 0)>=3 or table.getn(C.queue)>=32 then return end
    table.insert(C.queue,id);C.queued[id]=true
    if C.driver then C.driver:Show() end
end
function C.StartQueue()
    C.driver=CreateFrame("Frame","OBPCacheDriver",UIParent)
    C.driver:Hide()
    C.Script(C.driver,"OnUpdate",function(_,elapsed)
        C.elapsed=C.elapsed+(elapsed or 0)
        if C.elapsed<0.35 then return end
        C.elapsed=0
        local id=table.remove(C.queue,1)
        if not id then C.driver:Hide();return end
        C.queued[id]=nil
        if not C.Cached(id) then
            C.attempts[id]=(C.attempts[id] or 0)+1
            if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID,id)
            elseif C.hidden then pcall(C.hidden.SetHyperlink,C.hidden,C.Link(id)) end
        end
    end)
    C.hidden=CreateFrame("GameTooltip","OBPCacheTooltip",UIParent,"GameTooltipTemplate")
    C.hidden:SetOwner(UIParent,"ANCHOR_NONE")
end
function C.Diagnostic()
    local c=C.Capabilities()
    local lines={"Octo Build Planner "..OBP.version,"Client capabilities:"}
    for _,key in ipairs(U.keys(c)) do table.insert(lines,"  "..key..": "..tostring(c[key])) end
    local m=OBP.Data.manifest or {}
    table.insert(lines,"Catalogue: "..tostring(m.version)..", "..tostring(m.itemCount).." items; complete="..tostring(m.complete))
    if OBP.profile then
        local working=OBP.Persistence and OBP.Persistence.working
        local profile=working and OBP.Profile.ForTalents(OBP.profile,working.talents) or OBP.profile
        table.insert(lines,"Profile: "..tostring(OBP.profile.class).." / "..tostring(OBP.profile.race).." / level "..tostring(OBP.profile.level))
        if working and working.talents then table.insert(lines,"Planned talents: budget level "..working.talents.level..", "..OBP.Talents.Spent(working.talents).."/"..working.talents.level-9 .." points; stats use actual character level.") end
        for _,key in ipairs({"str","agi","sta","int","spi"}) do
            table.insert(lines,"  "..key.." baseline="..tostring(profile.base[key])..", passive flat="..tostring(profile.flat[key] or 0))
        end
        for _,line in ipairs(profile.notes or {}) do table.insert(lines,line) end
        for _,line in ipairs(profile.unknown or {}) do table.insert(lines,"Unresolved: "..line) end
        if OBP.Stats and OBP.Persistence.working then
            local result=OBP.Stats.Evaluate(profile,OBP.Persistence.working.loadout)
            for _,line in ipairs(result.missing) do table.insert(lines,"Calculation: "..line) end
        end
    end
    table.insert(lines,"Actual-client stat/preview validation is required; see docs/COMPATIBILITY.md.")
    return table.concat(lines,"\n")
end
