local U=OBP.Util
OBP.EquippedItems={resolved={},attempts={}}
local E=OBP.EquippedItems
local statKeys={ITEM_MOD_STRENGTH_SHORT="str",ITEM_MOD_AGILITY_SHORT="agi",ITEM_MOD_STAMINA_SHORT="sta",ITEM_MOD_INTELLECT_SHORT="int",ITEM_MOD_SPIRIT_SHORT="spi",ITEM_MOD_MANA_SHORT="mana",ITEM_MOD_HEALTH_SHORT="health",RESISTANCE0_NAME="armor",ITEM_MOD_ATTACK_POWER_SHORT="ap",ITEM_MOD_RANGED_ATTACK_POWER_SHORT="rap",ITEM_MOD_CRIT_MELEE_RATING="melee_crit",ITEM_MOD_CRIT_RANGED_RATING="ranged_crit",ITEM_MOD_HIT_MELEE_RATING="melee_hit",ITEM_MOD_HIT_RANGED_RATING="ranged_hit",ITEM_MOD_HIT_SPELL_RATING="spell_hit",ITEM_MOD_CRIT_SPELL_RATING="spell_crit",ITEM_MOD_SPELL_DAMAGE_DONE_SHORT="spell_power",ITEM_MOD_SPELL_HEALING_DONE_SHORT="healing",ITEM_MOD_SPELL_PENETRATION="spell_pen",ITEM_MOD_ARMOR_PENETRATION_RATING="armor_pen",ITEM_MOD_MANA_REGENERATION="mp5",ITEM_MOD_HEALTH_REGEN="hp5",ITEM_MOD_DEFENSE_SKILL_RATING="defense",ITEM_MOD_DODGE_RATING="dodge",ITEM_MOD_PARRY_RATING="parry",ITEM_MOD_BLOCK_RATING="block",ITEM_MOD_BLOCK_VALUE="block_value"}
local schools={"holy","fire","nature","frost","shadow","arcane"}
for index,school in ipairs(schools) do statKeys["RESISTANCE"..index.."_NAME"]="res_"..school;statKeys["ITEM_MOD_"..string.upper(school).."_SPELL_DAMAGE_DONE_SHORT"]="power_"..school end
local statTypes={[0]="mana",[1]="health",[3]="agi",[4]="str",[5]="int",[6]="spi",[7]="sta"}
local inventories={INVTYPE_HEAD=1,INVTYPE_NECK=2,INVTYPE_SHOULDER=3,INVTYPE_BODY=4,INVTYPE_CHEST=5,INVTYPE_WAIST=6,INVTYPE_LEGS=7,INVTYPE_FEET=8,INVTYPE_WRIST=9,INVTYPE_HAND=10,INVTYPE_FINGER=11,INVTYPE_TRINKET=12,INVTYPE_WEAPON=13,INVTYPE_SHIELD=14,INVTYPE_RANGED=15,INVTYPE_CLOAK=16,INVTYPE_2HWEAPON=17,INVTYPE_TABARD=19,INVTYPE_ROBE=20,INVTYPE_WEAPONMAINHAND=21,INVTYPE_WEAPONOFFHAND=22,INVTYPE_HOLDABLE=23,INVTYPE_THROWN=25,INVTYPE_RANGEDRIGHT=26,INVTYPE_RELIC=28}
local function number(n,low,high) return type(n)=="number" and n==n and n>=low and n<=high end
local function integer(n,low,high) return number(n,low,high) and n==math.floor(n) end
local function text(s,limit) return type(s)=="string" and string.len(s)>0 and string.len(s)<=limit and not string.find(s,"[%c|]") end
local function read(reader,input)
    if type(reader)~="function" then return nil end
    local okay,result=pcall(reader,input)
    if okay then return result end
end
function E.Parse(link)
    if type(link)~="string" or string.len(link)>1024 then return nil end
    local payload=U.match(link,"(item:%d+:%d+:%-?%d+:%d+)")
    if not payload then return nil end
    local parts=U.split(payload,":")
    local id,applied,suffix,unique=tonumber(parts[2]),tonumber(parts[3]),tonumber(parts[4]),tonumber(parts[5])
    if not integer(id,1,4294967295) or not integer(applied,0,4294967295) or not integer(suffix,-2147483648,2147483647) or not integer(unique,0,4294967295) then return nil end
    return id,applied,suffix,unique,"item:"..id..":0:"..suffix..":"..unique
end
function E.Shape(entry)
    if entry.applied~=nil and not integer(entry.applied,1,4294967295) then return false end
    if not entry.link and not entry.snapshot then return true end
    local id,applied,_,_,canonical=E.Parse(entry.link)
    if id~=entry.item or applied~=0 or canonical~=entry.link or type(entry.snapshot)~="table" then return false end
    local item=entry.snapshot
    if item.id~=id or not text(item.name,256) or not text(item.icon,256) or not integer(item.inventoryType,1,28) or not integer(item.classID,0,20) or not integer(item.subclassID,0,30) or not integer(item.quality,0,6) or type(item.stats)~="table" or type(item.unsupported)~="table" then return false end
    local allowed={};for _,key in pairs(statKeys) do allowed[key]=true end
    for key,n in pairs(item.stats) do if not allowed[key] or not number(n,-1000000000,1000000000) then return false end end
    for _,key in ipairs({"speed","damageMin","damageMax","baseArmor","itemLevel","requiredLevel","unique"}) do if item[key]~=nil and not number(item[key],0,1000000000) then return false end end
    if table.getn(item.unsupported)>32 then return false end
    if item.pending~=nil and type(item.pending)~="boolean" then return false end
    for _,line in pairs(item.unsupported) do if not text(line,256) then return false end end
    for _,key in ipairs({"classMask","raceMask"}) do if item[key]~=nil and not integer(item[key],-1,4294967295) then return false end end
    if item.excluded~=nil then
        if type(item.excluded)~="table" or table.getn(item.excluded)>32 then return false end
        for _,line in pairs(item.excluded) do if not text(line,256) then return false end end
    end
    return true
end
function E.Capture(link,slot)
    local id,applied,_,_,canonical=E.Parse(link)
    if not id or not OBP.Slots[slot] then return nil,"The equipped item link could not be read." end
    local api=C_Item or {}
    local base=OBP.Data.items[id] or {}
    local data=read(api.GetItemDataByID,canonical)
    if type(data)~="table" then data={} end
    local name,_,quality,level,required,kind,subtype,stack,equipLoc,icon
    if GetItemInfo then name,_,quality,level,required,kind,subtype,stack,equipLoc,icon=GetItemInfo(canonical) end
    local display=U.match(link,"|h%[(.-)%]|h")
    if text(display,256) then name=display end
    if not text(name,256) then name=text(data.name,256) and data.name or base.name or "Item #"..id end
    local item={id=id,name=name,icon=data.icon or icon or base.icon or "Interface\\Icons\\INV_Misc_QuestionMark",quality=data.quality or quality or base.quality or 1,inventoryType=data.inventoryType or inventories[equipLoc] or base.inventoryType or OBP.Slots[slot].inventory[1],classID=data.classID or base.classID or 0,subclassID=data.subclassID or base.subclassID or 0,itemLevel=data.itemLevel or level or base.itemLevel or 0,requiredLevel=data.requiredLevel or required or base.requiredLevel or 0,classMask=data.allowableClass or base.classMask or -1,raceMask=data.allowableRace or base.raceMask or -1,stats={},unsupported={},excluded={}}
    if data.maxCount then if data.maxCount>0 then item.unique=data.maxCount end else item.unique=base.unique end
    if data.itemSet and data.itemSet>0 then item.itemSet=data.itemSet end
    if data.armor then item.baseArmor=data.armor end
    if data.delay and data.delay>0 then item.speed=data.delay/1000 end
    for _,field in ipairs({"damageMin","damageMax"}) do
        if type(data[field])=="table" then
            item[field]=0;for _,n in pairs(data[field]) do if number(n,0,1000000000) then item[field]=item[field]+n end end
        end
    end
    local stats=read(api.GetItemStats,canonical)
    if type(stats)=="table" then
        for key,n in pairs(stats) do if statKeys[key] and number(n,-1000000000,1000000000) then item.stats[statKeys[key]]=n end end
        -- Generic attack power benefits melee and ranged attacks; the API's
        -- ranged key contains only the additional ranged-only allocation.
        if item.stats.ap then item.stats.rap=(item.stats.rap or 0)+item.stats.ap end
    else
        item.pending=true
        for key,n in pairs(data.stats or {}) do if statTypes[key] and number(n,-1000000000,1000000000) then item.stats[statTypes[key]]=n end end
        item.stats.armor=data.armor or 0
        for _,school in ipairs(schools) do item.stats["res_"..school]=data["resistance"..string.upper(string.sub(school,1,1))..string.sub(school,2)] or 0 end
        table.insert(item.unsupported,"Exact item bonuses could not be read. Enable or update ClassicAPI and copy the gear again.")
    end
    -- GetItemStats omits unusual equip effects. Do not present incomplete
    -- calculations as final when an equip aura cannot be represented there.
    local supported={[0]=true,[13]=true,[22]=true,[29]=true,[34]=true,[35]=true,[47]=true,[49]=true,[51]=true,[52]=true,[54]=true,[55]=true,[57]=true,[85]=true,[99]=true,[123]=true,[124]=true,[135]=true,[158]=true}
    for _,spell in pairs(data.spells or {}) do
        if spell.trigger==1 then
            local effects=read(C_Spell and C_Spell.GetSpellEffectInfo,spell.id)
            local incomplete=type(effects)~="table"
            for _,effect in ipairs(type(effects)=="table" and effects or {}) do
                local aura=effect.auraName or 0
                if not supported[aura] or (aura==13 and effect.miscValue==1) or ((aura==55 or aura==57) and effect.miscValue~=0 and effect.miscValue~=126 and effect.miscValue~=127 and effect.miscValue~=-1) then incomplete=true end
            end
            if incomplete then table.insert(item.unsupported,"An equipped spell effect is outside the supported item-stat reader.") end
        else table.insert(item.excluded,"Triggered and on-use effects are excluded from planned totals.") end
    end
    local entry={item=id,link=canonical,snapshot=item,applied=applied>0 and applied or nil}
    if not E.Shape(entry) then return nil,"The client returned invalid item data." end
    return entry
end
function E.Item(entry)
    local item=entry and entry.snapshot
    if not item then return entry and OBP.Data.items[entry.item] end
    if not item.pending or not (C_Item and C_Item.GetItemStats) then return item end
    if E.resolved[entry.link] then return E.resolved[entry.link] end
    local now=GetTime and GetTime()
    if now and E.attempts[entry.link] and now-E.attempts[entry.link]<0.5 then return item end
    E.attempts[entry.link]=now
    for slot,definition in pairs(OBP.Slots) do
        for _,inventory in ipairs(definition.inventory) do
            if inventory==item.inventoryType then
                local fresh=E.Capture(entry.link,slot)
                if fresh and not fresh.snapshot.pending then E.resolved[entry.link]=fresh.snapshot;return fresh.snapshot end
                return item
            end
        end
    end
    return item
end
function E.Invalidate(id)
    for link in pairs(E.attempts) do if not id or E.Parse(link)==id then E.attempts[link]=nil end end
end
