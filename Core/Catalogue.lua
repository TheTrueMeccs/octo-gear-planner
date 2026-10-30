local U = OBP.Util
OBP.Catalogue = {}
local C = OBP.Catalogue
C.AcquisitionOptions={{"Reputation","reputation"},{"Dungeon","dungeon"},{"Raid","raid"},{"Profession","profession"},{"World Drop","world_drop"},{"Quest","quest"},{"Vendor","vendor"},{"PvP","pvp"},{"World Boss","world_boss"},{"Fishing","fishing"},{"Container","container"},{"Other","other"},{"Unknown","unknown"}}
local armor = { WARRIOR=4,PALADIN=4,HUNTER=3,ROGUE=2,PRIEST=1,SHAMAN=3,MAGE=1,WARLOCK=1,DRUID=2 }
local weapons = {
    WARRIOR={0,1,2,3,4,5,6,7,8,10,13,15,16,18,20},
    PALADIN={0,1,4,5,6,7,8,20}, HUNTER={0,1,2,3,6,7,8,10,13,15,16,18,20},
    ROGUE={0,2,3,4,7,13,15,16,18,20}, PRIEST={4,10,15,19,20},
    SHAMAN={0,1,4,5,10,13,15,20}, MAGE={7,10,15,19,20},
    WARLOCK={7,10,15,19,20}, DRUID={4,5,6,10,13,15,20}
}
local relic = { [7]="PALADIN",[8]="DRUID",[9]="SHAMAN" }
local weaponNames={[0]="One-Handed Axes",[1]="Two-Handed Axes",[2]="Bows",[3]="Guns",[4]="One-Handed Maces",[5]="Two-Handed Maces",[6]="Polearms",[7]="One-Handed Swords",[8]="Two-Handed Swords",[10]="Staves",[13]="Fist Weapons",[14]="Miscellaneous",[15]="Daggers",[16]="Thrown",[17]="Spears",[18]="Crossbows",[19]="Wands",[20]="Fishing Poles"}
local armorNames={[1]="Cloth",[2]="Leather",[3]="Mail",[4]="Plate"}
function C.Sources(item)
    local index=0
    return function()
        if item.sourceEdges then
            index=index+2
            local id=item.sourceEdges[index-1]
            if not id then return end
            local chance=item.sourceEdges[index]
            return (OBP.Data.sourceDefs or {})[id],chance and chance>=0 and chance or nil
        end
        index=index+1
        local source=(item.sources or {})[index]
        if source then return source,source.chance end
    end
end
function C.InInstance(item,instance)
    if not item.instanceIDs then
        item.instanceIDs={}
        for source in C.Sources(item) do
            if source.instance then item.instanceIDs[source.instance]=true end
            for _,loc in ipairs(source.locations or {}) do
                local alias=OBP.Data.instanceAliases and OBP.Data.instanceAliases[loc] or loc
                item.instanceIDs[alias]=true
            end
        end
    end
    return item.instanceIDs[instance]
end
function C.Fits(item, slot)
    if not item or not OBP.Slots[slot] then return false end
    for _, inv in ipairs(OBP.Slots[slot].inventory) do if item.inventoryType == inv then return true end end
    return false
end
function C.Eligible(item, profile)
    if not profile or not profile.class then return true end
    if U.maskAllows(item.classMask, profile.classID) == false then return false, "Your class cannot use this item." end
    if U.maskAllows(item.raceMask, profile.raceID) == false then return false, "Your race cannot use this item." end
    if item.faction and profile.faction and item.faction ~= profile.faction then return false, "This item is restricted to the other faction." end
    if item.classID == 4 then
        if item.subclassID >= 1 and item.subclassID <= 4 and item.subclassID > (armor[profile.class] or 0) then
            return false, "Your class cannot learn this armor type."
        end
        if item.subclassID == 6 and profile.class ~= "WARRIOR" and profile.class ~= "PALADIN" and profile.class ~= "SHAMAN" then return false, "Your class cannot use shields." end
        if relic[item.subclassID] and relic[item.subclassID] ~= profile.class then return false, "This relic is for another class." end
    elseif item.classID == 2 then
        if item.subclassID == 14 then return true end -- Tools need no weapon proficiency.
        for _, sub in ipairs(weapons[profile.class] or {}) do if sub == item.subclassID then return true end end
        return false, "Your class cannot learn this weapon type."
    elseif item.classID == 6 and profile.class ~= "HUNTER" and profile.class ~= "WARRIOR" and profile.class ~= "ROGUE" then
        return false, "Your class cannot use this ammunition."
    end
    return true
end
function C.EnchantFits(enchant, item, profile)
    if not enchant or not item or enchant.temporary then return false end
    local found = false
    for _, inv in ipairs(enchant.inventory or {}) do if item.inventoryType == inv then found = true end end
    if not found then return false end
    if enchant.minItemLevel and (item.itemLevel or 0) < enchant.minItemLevel then return false end
    if enchant.maxItemLevel and (item.itemLevel or 0) > enchant.maxItemLevel then return false end
    if enchant.classID and item.classID ~= enchant.classID then return false end
    if enchant.subclassID and item.subclassID ~= enchant.subclassID then return false end
    if enchant.subclassMask and not U.maskAllows(enchant.subclassMask,(item.subclassID or 0)+1) then return false end
    if enchant.ownerSkill and profile and (profile.professions[enchant.ownerSkill] or 0) < (enchant.ownerSkillRank or 1) then return false end
    return true
end
function C.BuildIndex()
    C.bySlot = {}
    for slot in pairs(OBP.Slots) do C.bySlot[slot] = {} end
    for id, item in pairs(OBP.Data.items) do
        item.search = string.lower(item.name)
        for slot in pairs(OBP.Slots) do if C.Fits(item, slot) then table.insert(C.bySlot[slot], id) end end
    end
    for _, ids in pairs(C.bySlot) do
        table.sort(ids, function(a,b)
            local x,y = OBP.Data.items[a],OBP.Data.items[b]
            if (x.itemLevel or 0)~=(y.itemLevel or 0) then return (x.itemLevel or 0)>(y.itemLevel or 0) end
            if x.search == y.search then return a < b end
            return x.search < y.search
        end)
    end
end
function C.FilterStat(item,key)
    local stats=item.stats or {}
    if key=="spell_power" then
        local bonus=stats.spell_power or 0
        for _,school in ipairs({"arcane","fire","frost","holy","nature","shadow"}) do bonus=math.max(bonus,(stats.spell_power or 0)+(stats["power_"..school] or 0)) end
        return bonus
    end
    if string.find(key,"^power_") then return (stats.spell_power or 0)+(stats[key] or 0) end
    return stats[key] or 0
end
function C.ItemType(item)
    if item.classID==2 and weaponNames[item.subclassID] then return "weapon",item.subclassID,weaponNames[item.subclassID] end
    if item.inventoryType==14 then return "weapon","shield","Shields" end
    if item.inventoryType==23 then return "weapon","held","Held in Off-hand" end
    if item.inventoryType==28 then
        local names={[7]="Librams",[8]="Idols",[9]="Totems"}
        if names[item.subclassID] then return "weapon","relic"..item.subclassID,names[item.subclassID] end
    end
    if item.classID==4 and armorNames[item.subclassID] then return "armor",item.subclassID,armorNames[item.subclassID] end
end
function C.TypeOptions(slot,profile,hide)
    if not C.bySlot then C.BuildIndex() end
    local options,seen,group={},{},nil
    for _,id in ipairs(C.bySlot[slot] or {}) do
        local item=OBP.Data.items[id]
        if not hide or C.Eligible(item,profile) then
            local kind,key,name=C.ItemType(item)
            if kind and not seen[key] then
                group=kind;seen[key]=true;table.insert(options,{key=key,text=name})
            end
        end
    end
    if table.getn(options)<2 then return nil,nil,{} end
    table.sort(options,function(a,b) return a.text<b.text end)
    return group,group=="weapon" and "Weapon Types" or "Armor Types",options
end
function C.Query(slot, filters, profile, hide)
    if not C.bySlot then C.BuildIndex() end
    local out, query = {}, string.lower(U.trim(filters.name))
    local typeGroup,_,typeOptions=C.TypeOptions(slot,profile,hide)
    local typeFilter=typeGroup and filters[typeGroup] or {}
    local filterTypes=false
    for _,option in ipairs(typeOptions) do if typeFilter and typeFilter[option.key] then filterTypes=true end end
    local requireQuality=false
    for _,state in pairs(filters.qualities or {}) do if state==true then requireQuality=true end end
    local requireAcquisition=false
    for _,state in pairs(filters.acquisition or {}) do if state==true then requireAcquisition=true end end
    for _, id in ipairs(C.bySlot[slot] or {}) do
        local item, accept = OBP.Data.items[id], true
        if hide and not C.Eligible(item, profile) then accept = false end
        local acquisitions=item.acquisition or {unknown=0}
        local routeLevel
        for key,minimum in pairs(acquisitions) do
            local state=(filters.acquisition or {})[key]
            if state==-1 then accept=false end
            if not requireAcquisition or state==true then routeLevel=math.min(routeLevel or minimum,minimum) end
        end
        if requireAcquisition and not routeLevel then accept=false end
        local level = math.max(1, item.requiredLevel or 0, routeLevel or 0)
        if filters.instance then
            local entryLevels=(OBP.Data.manifest or {}).instanceEntryLevels or {}
            level=math.max(level,entryLevels[filters.instance] or 0)
        end
        if level < (filters.minLevel or 1) or level > (filters.maxLevel or 60) then accept = false end
        if filters.quality ~= nil and item.quality ~= filters.quality then accept = false end
        if filters.qualities then
            local state=filters.qualities[item.quality]
            if state==-1 or (requireQuality and state~=true) then accept=false end
        end
        if query ~= "" and not string.find(item.search, query, 1, true) then accept = false end
        if filterTypes then
            local _,key=C.ItemType(item)
            if not key or not typeFilter[key] then accept=false end
        end
        for key, state in pairs(filters.stats or {}) do
            local present=C.FilterStat(item,key)>0
            if (state==true and not present) or (state==-1 and present) then accept=false end
        end
        if filters.instance then
            if not C.InInstance(item,filters.instance) then accept = false end
        end
        if accept then table.insert(out, id) end
    end
    return out
end
function C.Sort(ids,mode)
    mode=mode or "ilevel_desc"
    local field=string.find(mode,"^quality_") and "quality" or string.find(mode,"^required_") and "requiredLevel" or "itemLevel"
    local ascending=string.find(mode,"_asc$")~=nil
    local byName=string.find(mode,"^name_")~=nil
    table.sort(ids,function(a,b)
        local x,y=OBP.Data.items[a],OBP.Data.items[b]
        local xn,yn=x.search or string.lower(x.name),y.search or string.lower(y.name)
        local xv,yv=byName and xn or (x[field] or 0),byName and yn or (y[field] or 0)
        if xv~=yv then if ascending then return xv<yv else return xv>yv end end
        if (x.itemLevel or 0)~=(y.itemLevel or 0) then return (x.itemLevel or 0)>(y.itemLevel or 0) end
        if xn~=yn then return xn<yn end
        return a<b
    end)
    return ids
end
function C.Enchantments(item, profile)
    local list = {}
    for key, enchant in pairs(OBP.Data.enchants) do
        if C.EnchantFits(enchant, item, profile) then table.insert(list, key) end
    end
    table.sort(list, function(a,b) return OBP.Data.enchants[a].name < OBP.Data.enchants[b].name end)
    return list
end
