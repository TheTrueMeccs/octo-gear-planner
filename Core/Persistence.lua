local U = OBP.Util
OBP.Persistence = {}
local P = OBP.Persistence
function P.DefaultFilters() return {name="",minLevel=1,maxLevel=60,armor={},weapon={},stats={},qualities={},acquisition={}} end
local function equipmentShape(loadout)
    if type(loadout)~="table" then return false end
    local count=0
    for slot,entry in pairs(loadout) do
        count=count+1
        if count>20 or (not OBP.Slots[slot] and slot~=0) or type(entry)~="table" or type(entry.item)~="number" or entry.item<1 or entry.item~=math.floor(entry.item) or (entry.enchant~=nil and type(entry.enchant)~="string") then return false end
    end
    return true
end
function P.Load(db)
    if db and (type(db) ~= "table" or db.schema ~= 1) then return nil,"Unrecognized saved-data version. Your original data has been preserved." end
    db = db or {schema=1,nextID=1,sets={},order={},prefs={hideUnusable=true,slot=1,left="Base Stats",right="Spell",filters=P.DefaultFilters()}}
    if type(db.sets) ~= "table" or type(db.order) ~= "table" or type(db.prefs) ~= "table" then return nil,"Saved set data is damaged; the original was preserved." end
    local seen,maxID = {},0
    for _, id in ipairs(db.order) do
        local set = db.sets[id]
        if type(id) ~= "number" or id ~= math.floor(id) or id < 1 or seen[id] or type(set) ~= "table" or not U.name(set.name) or not equipmentShape(set.loadout) then return nil,"Saved set data is damaged; the original was preserved." end
        seen[id],maxID = true,math.max(maxID,id)
    end
    for id in pairs(db.sets) do if not seen[id] then return nil,"The saved set order is damaged; the original was preserved." end end
    if db.working and (type(db.working)~="table" or type(db.working.name)~="string" or (db.working.name~="" and not U.name(db.working.name)) or not equipmentShape(db.working.loadout)) then return nil,"The recovered draft is damaged; the original data was preserved." end
    for _,set in pairs(db.sets) do if set.talents and not OBP.Talents.Validate(set.talents) then return nil,"A saved talent build is invalid; the original data was preserved." end end
    if db.working and db.working.talents and not OBP.Talents.Validate(db.working.talents) then return nil,"The recovered talent build is invalid; the original data was preserved." end
    for _,set in pairs(db.sets) do set.talents=set.talents or OBP.Talents.Default() end
    if db.working then db.working.talents=db.working.talents or OBP.Talents.Default() end
    -- Retire legacy ammo selections without preventing old sets/drafts from
    -- loading. Keep the removed entries separately for recovery.
    local function retireAmmo(loadout,key)
        if not loadout[0] then return end
        if type(db.retiredAmmo)~="table" then db.retiredAmmo={} end
        db.retiredAmmo[key]=U.copy(loadout[0]);loadout[0]=nil
    end
    for id,set in pairs(db.sets) do retireAmmo(set.loadout,"set:"..id) end
    if db.working then retireAmmo(db.working.loadout,"working") end
    db.nextID = math.max(type(db.nextID)=="number" and db.nextID<1000000000 and db.nextID==math.floor(db.nextID) and db.nextID or 1,maxID+1)
    local prefs=db.prefs
    if type(prefs.uiScale)~="number" or prefs.uiScale~=prefs.uiScale or math.abs(prefs.uiScale)==math.huge then prefs.uiScale=1 end
    prefs.uiScale=U.clamp(math.floor(prefs.uiScale*100+0.5)/100,0.5,1.5)
    local sorts={ilevel_desc=true,ilevel_asc=true,name_asc=true,name_desc=true,quality_desc=true,quality_asc=true,required_desc=true,required_asc=true}
    if not sorts[prefs.sort] then prefs.sort="ilevel_desc" end
    if not OBP.Slots[prefs.slot] then prefs.slot=1 end
    local categories={};for _,name in ipairs(OBP.Stats.Categories) do categories[name]=true end
    if not categories[prefs.left] then prefs.left="Base Stats" end
    if not categories[prefs.right] then prefs.right="Spell" end
    prefs.drawer=nil -- Filters and Enchantments are now independent, always-visible panels.
    if prefs.characterPage~="Character" and prefs.characterPage~="Talents" then prefs.characterPage="Character" end
    if type(prefs.talentTab)~="number" or prefs.talentTab~=math.floor(prefs.talentTab) or prefs.talentTab<1 or prefs.talentTab>3 then prefs.talentTab=1 end
    if type(prefs.filters)~="table" then prefs.filters=P.DefaultFilters() end
    local filters=prefs.filters
    if type(filters.name)~="string" then filters.name="" end
    for _,key in ipairs({"minLevel","maxLevel"}) do if type(filters[key])~="number" or filters[key]~=filters[key] then filters[key]=key=="minLevel" and 1 or 60 end;filters[key]=U.clamp(math.floor(filters[key]),1,60) end
    if filters.minLevel>filters.maxLevel then filters.minLevel,filters.maxLevel=filters.maxLevel,filters.minLevel end
    if type(filters.armor)~="table" then filters.armor={} end
    if type(filters.weapon)~="table" then filters.weapon={} end
    if type(filters.stats)~="table" then filters.stats={} end
    for key,enabled in pairs(filters.armor) do if type(key)~="number" or enabled~=true then filters.armor[key]=nil end end
    for key,enabled in pairs(filters.weapon) do
        local numeric=type(key)=="number" and key==math.floor(key) and key>=0 and key<=20
        if (not numeric and key~="shield" and key~="held" and key~="relic7" and key~="relic8" and key~="relic9") or enabled~=true then filters.weapon[key]=nil end
    end
    for key,state in pairs(filters.stats) do if type(key)~="string" or (state~=true and state~=-1) then filters.stats[key]=nil end end
    if type(filters.qualities)~="table" then filters.qualities={} end
    for key,enabled in pairs(filters.qualities) do if (key~=2 and key~=3 and key~=4 and key~=5) or (enabled~=true and enabled~=-1) then filters.qualities[key]=nil end end
    if filters.quality==2 or filters.quality==3 or filters.quality==4 or filters.quality==5 then filters.qualities[filters.quality]=true end
    filters.quality=nil
    if type(filters.acquisition)~="table" then filters.acquisition={} end
    local acquisitionKeys={};for _,option in ipairs(OBP.Catalogue.AcquisitionOptions) do acquisitionKeys[option[2]]=true end
    for key,state in pairs(filters.acquisition) do if not acquisitionKeys[key] or (state~=true and state~=-1) then filters.acquisition[key]=nil end end
    if type(filters.instance)~="number" then filters.instance=nil end
    if type(prefs.position)~="table" or type(prefs.position.x)~="number" or type(prefs.position.y)~="number" then prefs.position=nil end
    if prefs.position and (type(prefs.position.scale)~="number" or prefs.position.scale~=prefs.position.scale or prefs.position.scale<=0 or prefs.position.scale==math.huge) then prefs.position.scale=nil end
    if type(prefs.hideUnusable)~="boolean" then prefs.hideUnusable=true end
    P.db = db
    if db.active and not db.sets[db.active] then db.active = nil end
    local base = db.active and db.sets[db.active] or {name="",loadout={},talents=OBP.Talents.Default()}
    P.working = db.working and type(db.working.loadout)=="table" and U.copy(db.working) or U.copy(base)
    P.baseline = U.copy(base)
    P.Sync()
    return db
end
function P.Sync() P.db.working = U.copy(P.working) end
function P.Dirty() return not U.equal(P.working,P.baseline) end
function P.NameExists(name)
    for _, set in pairs(P.db.sets) do if set.name == name then return true end end
    return false
end
function P.Select(id)
    if id and not P.db.sets[id] then return nil,"Set not found." end
    P.db.active = id
    P.baseline = U.copy(id and P.db.sets[id] or {name="",loadout={},talents=OBP.Talents.Default()})
    P.working = U.copy(P.baseline)
    P.Sync()
    return true
end
function P.Create(name,loadout,profile,talents)
    local valid,reason = U.name(name)
    if not valid then return nil,reason end
    if P.NameExists(valid) then return nil,"A set with that name already exists." end
    local okay, why = OBP.Loadout.Validate(loadout or {},profile)
    if not okay then return nil,why end
    talents=talents or OBP.Talents.Default(profile)
    local validBuild,buildReason=OBP.Talents.Validate(talents,profile)
    if not validBuild then return nil,buildReason end
    local id = P.db.nextID
    P.db.nextID = id + 1
    P.db.sets[id] = {name=valid,loadout=U.copy(loadout or {}),talents=U.copy(talents)}
    table.insert(P.db.order,id)
    P.Select(id)
    return id
end
function P.Save(name,profile)
    local okay,reason = OBP.Loadout.Validate(P.working.loadout,profile)
    if not okay then return nil,reason end
    local validBuild,buildReason=OBP.Talents.Validate(P.working.talents,profile)
    if not validBuild then return nil,buildReason end
    if not P.db.active then return P.Create(name,P.working.loadout,profile,P.working.talents) end
    P.db.sets[P.db.active] = U.copy(P.working)
    P.baseline = U.copy(P.working)
    P.Sync()
    return true
end
function P.Discard() P.working = U.copy(P.baseline); P.Sync() end
function P.Edit(loadout) P.working.loadout = U.copy(loadout); P.Sync() end
function P.EditTalents(build,profile)
    local valid,reason=OBP.Talents.Validate(build,profile)
    if not valid then return nil,reason end
    P.working.talents=U.copy(build);P.Sync();return true
end
function P.Delete(id)
    local position
    for i,value in ipairs(P.db.order) do if value==id then position=i end end
    if not position then return nil,"Set not found." end
    local active = P.db.active==id
    table.remove(P.db.order,position)
    P.db.sets[id]=nil
    if active then P.Select(P.db.order[position] or P.db.order[position-1]) end
    return true
end
function P.Import(candidate,profile)
    local name,index = candidate.name,2
    while P.NameExists(name) do
        local suffix = " ("..index..")"
        local base = string.sub(candidate.name,1,64-string.len(suffix))
        while not U.utf8(base) do base=string.sub(base,1,string.len(base)-1) end
        name,index = base..suffix,index+1
    end
    return P.Create(name,candidate.loadout,profile,candidate.talents)
end
