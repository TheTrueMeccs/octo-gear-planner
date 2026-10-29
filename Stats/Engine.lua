local U=OBP.Util
OBP.Stats={ruleVersion="reference-1"}
local S=OBP.Stats
local attributes={"str","agi","sta","int","spi"}
local schools={"arcane","fire","frost","holy","nature","shadow"}
-- Reference rules: vmangos/core StatSystem.cpp and ObjectMgr.cpp. Actual OctoWoW
-- validation is tracked separately; this table never reads live aggregate values.
local critRates={WARRIOR={3.9,20,0},PALADIN={4.6,20,0.7},HUNTER={3.5,53,0},ROGUE={2.2,29,0},PRIEST={11,20,3},SHAMAN={4.6,20,1.7},MAGE={12.9,20,3.2},WARLOCK={8.4,20,2},DRUID={4.6,20,0.9}}
local spellRates={MAGE={3.7,14.77,0.65},PALADIN={3.7,14.77,0.65},WARLOCK={3.18,11.30,0.82},PRIEST={2.97,10.03,0.82},DRUID={3.33,12.41,0.79},SHAMAN={3.54,11.51,0.8}}
local weaponSkills={[0]={"Axes",44,"axes"},[1]={"Two-Handed Axes",172,"two-handed_axes"},[2]={"Bows",45,"bows"},[3]={"Guns",46,"guns"},[4]={"Maces",54,"maces"},[5]={"Two-Handed Maces",160,"two-handed_maces"},[6]={"Polearms",229,"polearms"},[7]={"Swords",43,"swords"},[8]={"Two-Handed Swords",55,"two-handed_swords"},[10]={"Staves",136,"staves"},[13]={"Unarmed",162,"fist_weapons"},[15]={"Daggers",173,"daggers"},[16]={"Thrown",176,"thrown"},[18]={"Crossbows",226,"crossbows"},[19]={"Wands",228,"wands"},[20]={"Fishing",356,"fishing_poles"}}
local function add(t,key,value) t[key]=(t[key] or 0)+value end
local function value(n,unit,missing)
    return {value=n,unit=unit or "number",status=missing and "partial" or n==nil and "unavailable" or "complete"}
end
local function ap(class,level,str,agi)
    if not str or not agi then return nil end
    if class=="WARRIOR" or class=="PALADIN" then return level*3+str*2-20 end
    if class=="ROGUE" or class=="HUNTER" then return level*2+str+agi-20 end
    if class=="SHAMAN" then return level*2+str*2-20 end
    if class=="DRUID" then return str*2-20 end
    return str-10
end
local function rap(class,level,agi)
    if not agi then return nil end
    if class=="HUNTER" then return level*2+agi*2-10 end
    if class=="WARRIOR" or class=="ROGUE" then return level+agi-10 end
    return agi-10
end
function S.WeaponSkill(item,profile,totals)
    local info=item and weaponSkills[item.subclassID]
    if not info or not profile.skills[info[1]] then return nil end
    return profile.skills[info[1]]+(totals["skill_"..info[2]] or 0)+(totals["skill_"..info[3]] or 0)
end
function S.Evaluate(profile,loadout)
    local totals,missing,weaponDamage={},{},{}
    local weaponPct={}
    local itemArmor=0
    for key,n in pairs(profile.flat or {}) do totals[key]=n end
    for slot,entry in pairs(loadout) do
        if slot~=0 then
        local item=OBP.Data.items[entry.item]
        if not item then table.insert(missing,"Unavailable item "..tostring(entry.item))
        else
            local eligible,reason=OBP.Catalogue.Eligible(item,profile)
            if not eligible then table.insert(missing,item.name..": "..reason) end
            for key,n in pairs(item.stats or {}) do add(totals,key,n) end
            itemArmor=itemArmor+(item.baseArmor or item.stats.armor or 0)
            for _,text in ipairs(item.unsupported or {}) do table.insert(missing,item.name..": "..text) end
            if entry.enchant then
                local enchant=OBP.Data.enchants[entry.enchant]
                if enchant then
                    for key,n in pairs(enchant.stats or {}) do
                        if key=="physical_damage" and (slot==16 or slot==17 or slot==18) then weaponDamage[slot]=(weaponDamage[slot] or 0)+n
                        else add(totals,key,n) end
                    end
                    for _,text in ipairs(enchant.unsupported or {}) do table.insert(missing,enchant.name..": "..text) end
                else table.insert(missing,"Unavailable enhancement "..entry.enchant) end
            end
        end
        end
    end
    for _,effect in ipairs(profile.scoped or {}) do
        for _,slot in ipairs({16,17,18}) do
            local item=loadout[slot] and OBP.Data.items[loadout[slot].item]
            if item and item.classID==effect.itemClass and (not effect.subclassMask or effect.subclassMask==0 or U.maskAllows(effect.subclassMask,item.subclassID+1)) and (not effect.inventoryMask or effect.inventoryMask==0 or U.maskAllows(effect.inventoryMask,item.inventoryType+1)) then
                if effect.aura==13 then weaponDamage[slot]=(weaponDamage[slot] or 0)+effect.amount
                elseif effect.aura==79 then
                    local physical=U.mod(effect.schoolMask or 1,2)==1
                    if physical or (slot==18 and item.subclassID==19) then weaponPct[slot]=(weaponPct[slot] or 1)*(1+effect.amount/100) end
                elseif effect.aura==52 and slot~=17 then add(totals,slot==18 and "ranged_crit" or "melee_crit",effect.amount)
                elseif effect.aura==54 and slot~=17 then add(totals,slot==18 and "ranged_hit" or "melee_hit",effect.amount)
                elseif effect.aura==47 and slot==16 then add(totals,"parry",effect.amount)
                elseif effect.aura==138 and slot==16 then add(totals,"haste",effect.amount) end
            end
        end
    end
    for _,text in ipairs(profile.unknown or {}) do table.insert(missing,text) end
    local result={values={},totals=totals,missing=missing,profileRevision=profile.revision,ruleVersion=S.ruleVersion}
    local v=result.values
    local function put(key,n,unit) v[key]=value(n,unit,table.getn(missing)>0) end
    local calculated={}
    for _,key in ipairs(attributes) do
        local base=profile.base[key]
        if base then calculated[key]=math.floor((base*(profile.basePct[key] or 1)+(totals[key] or 0))*(profile.totalPct[key] or 1)+0.00001) end
        put(key,calculated[key])
    end
    local a=calculated
    put("armor",a.agi and math.floor((totals.armor or 0)+itemArmor*((profile.factors.itemArmor or 1)-1)+a.agi*2))
    local attackPower=ap(profile.class,profile.level,a.str,a.agi)
    local rangedPower=rap(profile.class,profile.level,a.agi)
    put("ap",attackPower and math.max(0,(attackPower+(totals.ap or 0))*(profile.factors.ap or 1)))
    put("rap",rangedPower and math.max(0,(rangedPower+(totals.rap or 0))*(profile.factors.rap or 1)))
    local rates=critRates[profile.class]
    local agiRate=rates and (rates[1]*(60-profile.level)/59+rates[2]*(profile.level-1)/59)
    local baseCrit=a.agi and rates and a.agi/agiRate
    put("crit",baseCrit and baseCrit+(totals.crit or 0)+(totals.melee_crit or 0),"percent")
    put("ranged_crit",baseCrit and baseCrit+(totals.crit or 0)+(totals.ranged_crit or 0),"percent")
    local sr=spellRates[profile.class]
    put("spell_crit",sr and a.int and sr[1]+a.int/(sr[2]+sr[3]*profile.level)+(totals.spell_crit or 0),"percent")
    put("hit",(totals.hit or 0)+(totals.melee_hit or 0),"percent");put("spell_hit",totals.spell_hit or 0,"percent")
    put("ranged_hit",(totals.hit or 0)+(totals.ranged_hit or 0),"percent")
    put("spell_haste",totals.spell_haste or 0,"percent")
    local spiritPower=(totals.spirit_power_pct or 0)==0 and 0 or a.spi and math.floor(a.spi*totals.spirit_power_pct/100)
    local spiritHealing=(totals.spirit_healing_pct or 0)==0 and 0 or a.spi and math.floor(a.spi*totals.spirit_healing_pct/100)
    put("spell_power",spiritPower and (totals.spell_power or 0)+spiritPower)
    put("healing",spiritHealing and (totals.healing or 0)+spiritHealing)
    for _,school in ipairs(schools) do
        put("power_"..school,v.spell_power.value and v.spell_power.value+(totals["power_"..school] or 0))
        put("crit_"..school,v.spell_crit.value and v.spell_crit.value+(totals["crit_"..school] or 0),"percent")
        put("res_"..school,totals["res_"..school] or 0)
    end
    if sr and a.spi then
        local perTick
        if profile.class=="MAGE" or profile.class=="PRIEST" then perTick=a.spi/4+12.5
        elseif profile.class=="SHAMAN" then perTick=a.spi/5+17
        else perTick=a.spi/5+15 end
        local spiritPer5=perTick*2.5*(profile.factors.spiritRegen or 1)
        put("regen",spiritPer5+(totals.mp5 or 0))
        put("regen_casting",spiritPer5*U.clamp(totals.casting_regen or 0,0,100)/100+(totals.mp5 or 0))
    else put("regen",nil);put("regen_casting",nil) end
    local main=loadout[16] and OBP.Data.items[loadout[16].item]
    local off=loadout[17] and OBP.Data.items[loadout[17].item]
    local ranged=loadout[18] and OBP.Data.items[loadout[18].item]
    local skill=S.WeaponSkill(main,profile,totals)
    local rskill=S.WeaponSkill(ranged,profile,totals)
    put("weapon_skill",skill);put("ranged_skill",rskill)
    if not main then v.weapon_skill.status="not_applicable" end
    if not ranged or ranged.classID~=2 then v.ranged_skill.status="not_applicable" end
    local function damage(prefix,item,power,scale,slot)
        if item and item.speed and item.damageMin and item.damageMax and power then
            local contribution=power/14*item.speed+(totals.physical_damage or 0)+(weaponDamage[slot] or 0)
            local multiplier=scale*(1+(totals.physical_damage_pct or 0)/100)*(weaponPct[slot] or 1)
            put(prefix.."_min",math.max(0,(item.damageMin+contribution)*multiplier))
            put(prefix.."_max",math.max(0,(item.damageMax+contribution)*multiplier))
            put(prefix.."_speed",item.speed/(1+(totals[prefix=="ranged" and "ranged_haste" or "haste"] or 0)/100))
        else
            put(prefix.."_min",nil);put(prefix.."_max",nil);put(prefix.."_speed",nil)
            if not item or item.classID~=2 then for _,key in ipairs({"_min","_max","_speed"}) do v[prefix..key].status="not_applicable" end end
        end
    end
    damage("melee",main,v.ap.value,1,16);damage("off",off,v.ap.value,0.5,17)
    local rangedAP=ranged and ranged.subclassID==19 and 0 or v.rap.value
    damage("ranged",ranged,rangedAP,1,18)
    local defense=profile.defense and profile.defense+(totals.defense or 0)+(totals.skill_95 or 0)
    put("defense",defense)
    local defenseBonus=defense and (defense-profile.level*5)*0.04
    local dodge=a.agi and rates and a.agi/agiRate+rates[3]+(totals.dodge or 0)
    -- Rogues/hunters/druids have different agility-to-dodge coefficients; don't reuse crit blindly.
    if profile.class=="ROGUE" and dodge then dodge=a.agi/(agiRate/2)+(totals.dodge or 0) end
    if profile.class=="HUNTER" and dodge then local rate=1.8*(60-profile.level)/59+26.5*(profile.level-1)/59;dodge=a.agi/rate+(totals.dodge or 0) end
    put("dodge",dodge and defenseBonus and math.max(0,dodge+defenseBonus),"percent")
    put("parry",profile.canParry and main and defenseBonus and math.max(0,5+defenseBonus+(totals.parry or 0)) or 0,"percent")
    local shield=off and off.inventoryType==14
    put("block",profile.canBlock and shield and defenseBonus and math.max(0,5+defenseBonus+(totals.block or 0)) or 0,"percent")
    put("avoidance",defenseBonus and v.dodge.value and math.max(0,5+defenseBonus)+v.dodge.value+v.parry.value,"percent")
    local bossDefenseDelta=defense and (63*5-profile.level*5)*0.04
    put("boss_dodge",bossDefenseDelta and v.dodge.value and math.max(0,v.dodge.value-bossDefenseDelta),"percent")
    put("boss_parry",bossDefenseDelta and v.parry.value>0 and math.max(0,v.parry.value-bossDefenseDelta) or 0,"percent")
    put("boss_block",bossDefenseDelta and v.block.value>0 and math.max(0,v.block.value-bossDefenseDelta) or 0,"percent")
    put("boss_avoidance",bossDefenseDelta and v.boss_dodge.value and math.max(0,5+defenseBonus-bossDefenseDelta)+v.boss_dodge.value+v.boss_parry.value,"percent")
    if skill then
        local diff=315-skill
        local baseMiss=5+math.max(0,diff)*(diff>10 and 0.2 or 0.1)
        local effectiveHit=diff>10 and math.max(0,v.hit.value-1) or v.hit.value
        local special=math.max(0,baseMiss-effectiveHit)
        local dual=off and off.classID==2
        local miss=math.max(0,baseMiss+(dual and 19 or 0)-effectiveHit)
        local dodgeBoss=math.max(0,5+diff*0.1)
        local glance=U.clamp(10+(63-profile.level)*10,0,40)
        local glanceLow=U.clamp(1.3-0.05*diff,0.01,0.91)
        local glanceHigh=U.clamp(1.2-0.03*diff,0.2,0.99)
        local cap=math.max(0,100-miss-dodgeBoss-glance)
        put("boss_miss",miss,"percent");put("boss_special_miss",special,"percent")
        put("boss_target_dodge",dodgeBoss,"percent");put("glancing_damage",(glanceLow+glanceHigh)*50,"percent")
        put("crit_cap",cap,"percent")
        put("effective_crit",v.crit.value and math.max(0,math.min(cap,v.crit.value-3)),"percent")
    else
        for _,key in ipairs({"boss_miss","boss_special_miss","boss_target_dodge","glancing_damage","crit_cap","effective_crit"}) do put(key,nil,"percent") end
    end
    result.catalogueVersion=OBP.Data.manifest and OBP.Data.manifest.version
    return result
end
S.Categories={"Base Stats","Melee","Melee vs Boss","Ranged","Spell","Schools","Defenses","Defenses vs Boss"}
S.Rows={
    ["Base Stats"]={{"Strength","str"},{"Agility","agi"},{"Stamina","sta"},{"Intellect","int"},{"Spirit","spi"},{"Armor","armor"}},
    Melee={{"Weapon Skill","weapon_skill"},{"Damage","melee_damage"},{"Attack Speed","melee_speed"},{"Attack Power","ap"},{"Hit","hit"},{"Crit","crit"}},
    ["Melee vs Boss"]={{"Weapon Skill","weapon_skill"},{"Miss Chance","boss_miss"},{"Boss Dodge","boss_target_dodge"},{"Glancing Damage","glancing_damage"},{"Crit Cap","crit_cap"},{"Effective Crit","effective_crit"}},
    Ranged={{"Weapon Skill","ranged_skill"},{"Damage","ranged_damage"},{"Attack Speed","ranged_speed"},{"Attack Power","rap"},{"Hit","ranged_hit"},{"Crit","ranged_crit"}},
    Spell={{"Damage","spell_power"},{"Hit","spell_hit"},{"Crit","spell_crit"},{"Healing","healing"},{"Regen (5s)","regen_pair"},{"Haste","spell_haste"}},
    Schools={{"Arcane","power_arcane"},{"Fire","power_fire"},{"Frost","power_frost"},{"Holy","power_holy"},{"Nature","power_nature"},{"Shadow","power_shadow"}},
    Defenses={{"Armor","armor"},{"Defense","defense"},{"Dodge","dodge"},{"Parry","parry"},{"Block","block"},{"Avoidance","avoidance"}},
    ["Defenses vs Boss"]={{"Armor","armor"},{"Defense","defense"},{"Dodge","boss_dodge"},{"Parry","boss_parry"},{"Block","boss_block"},{"Avoidance","boss_avoidance"}}
}
function S.Format(result,key)
    if key=="melee_damage" or key=="off_damage" or key=="ranged_damage" then
        local prefix=string.sub(key,1,string.len(key)-7)
        if result.values[prefix.."_min"] and result.values[prefix.."_min"].status=="not_applicable" then return "—" end
        return S.Format(result,prefix.."_min").." - "..S.Format(result,prefix.."_max")
    end
    if key=="regen_pair" then return S.Format(result,"regen").." / "..S.Format(result,"regen_casting") end
    local entry=result.values[key]
    if entry and entry.status=="not_applicable" then return "—" end
    if not entry or entry.status~="complete" or entry.value==nil then return "?" end
    if entry.unit=="percent" then return string.format("%.2f%%",entry.value) end
    if string.find(key,"_speed$") then return string.format("%.2fs",entry.value) end
    return tostring(math.floor(entry.value+0.5))
end
