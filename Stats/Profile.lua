local U = OBP.Util
OBP.Profile = {revision=0}
local P=OBP.Profile
local attrs={"str","agi","sta","int","spi"}
local schoolBits={holy=2,fire=4,nature=8,frost=16,shadow=32,arcane=64}
local simpleAuras={[34]="health",[35]="mana",[47]="parry",[49]="dodge",[51]="block",[52]="crit",[54]="hit",[55]="spell_hit",[57]="spell_crit",[65]="spell_haste",[85]="mp5",[99]="ap",[124]="rap",[134]="casting_regen",[135]="healing",[138]="haste",[140]="ranged_haste",[158]="block_value"}
local irrelevant={[0]=true,[3]=true,[4]=true,[6]=true,[10]=true,[27]=true,[36]=true,[37]=true,[38]=true,[41]=true,[42]=true,[44]=true,[56]=true,[58]=true,[60]=true,[64]=true,[72]=true,[77]=true,[78]=true,[82]=true,[90]=true,[103]=true,[107]=true,[108]=true,[111]=true,[117]=true,[121]=true,[147]=true,[148]=true,[149]=true,[154]=true,[155]=true,[156]=true,[163]=true,[170]=true,[183]=true}
-- These bonuses require a creature type. The planner's generic and level-63
-- target contexts do not assume one, so they cannot contribute to those rows.
local targetSpecific={[59]=true,[102]=true,[131]=true,[168]=true,[169]=true,[180]=true}
local function add(t,key,amount) t[key]=(t[key] or 0)+amount end
local function multiplier(t,key,amount) t[key]=(t[key] or 1)*(1+amount/100) end
local function effects(id)
    if not C_Spell or not C_Spell.GetSpellEffectInfo then return nil end
    local okay,fx=pcall(C_Spell.GetSpellEffectInfo,id)
    if not okay or type(fx)~="table" then return nil end
    return fx
end
function P.Magnitude(effect,id,level,allowScaling)
    local delta=0
    if (effect.pointsPerLevel or 0)~=0 or (effect.dicePerLevel or 0)~=0 then
        if not allowScaling then return nil end
        local spellLevel,maxLevel
        if C_Spell and C_Spell.GetSpellLevelInfo then local a,_,b=C_Spell.GetSpellLevelInfo(id);spellLevel,maxLevel=a,b end
        local data=OBP.Data.talentSpells and OBP.Data.talentSpells[id]
        if not spellLevel and data then spellLevel,maxLevel=data.spellLevel,data.maxLevel end
        if not spellLevel then return nil end
        delta=math.max(spellLevel,math.min(level,maxLevel and maxLevel>0 and maxLevel or level))-spellLevel
    end
    if (effect.dieSides or 0)+delta*(effect.dicePerLevel or 0)>1 then return nil end
    return (effect.basePoints or 0)+(effect.baseDice or 0)+delta*(effect.pointsPerLevel or 0)
end
local function passive(id)
    if C_Spell and C_Spell.IsSpellPassive then local ok,value=pcall(C_Spell.IsSpellPassive,id);return ok and value end
    if IsPassiveSpell then local ok,value=pcall(IsPassiveSpell,id);return ok and value end
    return false
end
local function description(id)
    local reader=GetSpellDescription or (C_Spell and C_Spell.GetSpellDescription)
    if reader then local ok,value=pcall(reader,id);if ok then return string.lower(value or "") end end
    return ""
end
local function pctEffects(fx,base,total,stacks,id,level,allowScaling)
    local supported=true
    for _,effect in ipairs(fx or {}) do
        local kind=effect.auraName
        if kind==80 or kind==137 then
            local amount=P.Magnitude(effect,id,level,allowScaling)
            if amount then
            local n=amount*(stacks or 1)
            for index,key in ipairs(attrs) do
                if effect.miscValue==index-1 or (effect.miscValue or 0)<0 then multiplier(kind==80 and base or total,key,n) end
            end
            else supported=false end
        end
    end
    return supported
end
function P.ApplyPassive(profile,id,planned)
    local data=planned and OBP.Data.talentSpells and OBP.Data.talentSpells[id]
    if planned and (not data or not data.passive) then return end
    local fx=data and data.effects or effects(id)
    if not fx then table.insert(planned and profile.notes or profile.unknown,"Passive "..id.." has unavailable effects.");return end
    local rule=data or (OBP.Data.passiveRules and OBP.Data.passiveRules[id])
    local defaultStance=profile.class=="WARRIOR" and 17 or 0
    local active=true
    if rule then
        if rule.stances and rule.stances~=0 and not U.maskAllows(rule.stances,defaultStance) then active=false end
        if rule.stancesNot and rule.stancesNot~=0 and U.maskAllows(rule.stancesNot,defaultStance) then active=false end
        if (rule.creatureMask or 0)~=0 or (rule.targetState or 0)~=0 or (rule.casterState or 0)~=0 then active=false end
    end
    if active then
    local desc=data and string.lower(data.description or "") or description(id)
    local conditional=string.find(desc,"while") or string.find(desc,"against") or string.find(desc,"after") or string.find(desc,"when ") or string.find(desc,"frozen")
    if (not planned or not conditional) and not pctEffects(fx,profile.basePct,profile.totalPct,1,id,profile.level,true) then table.insert(planned and profile.notes or profile.unknown,"Passive "..id.." has an unresolved attribute multiplier.") end
    for _,effect in ipairs(fx or {}) do
        local aura,n,misc=effect.auraName,P.Magnitude(effect,id,profile.level,true),effect.miscValue or 0
        if aura~=0 and aura~=80 and aura~=137 then
            if irrelevant[aura] or aura==88 or aura==116 or aura==133 or (planned and (aura==71 or ((aura==55 or aura==57) and misc~=0 and misc~=-1 and misc~=126 and misc~=127))) then
                -- Utility, threat, and health-only passives do not affect displayed rows.
            elseif targetSpecific[aura] then
                table.insert(profile.notes,"Passive "..id.." has a creature-specific bonus; excluded for an unspecified target.")
            elseif not n then table.insert(planned and profile.notes or profile.unknown,"Passive "..id.." has an unresolved magnitude for aura "..aura)
            elseif rule and rule.itemClass and rule.itemClass>=0 then
                if aura==52 or aura==54 or aura==47 or aura==138 or aura==79 or (aura==13 and misc==1) then
                    table.insert(profile.scoped,{aura=aura,amount=n,schoolMask=misc,itemClass=rule.itemClass,subclassMask=rule.subclassMask,inventoryMask=rule.inventoryMask})
                else table.insert(planned and profile.notes or profile.unknown,"Weapon-dependent passive "..id.." requires a loadout rule: "..aura) end
            elseif conditional and aura~=134 then
                if not irrelevant[aura] then table.insert(profile.notes,"Conditional passive "..id.." excluded in the default context.") end
            elseif aura==29 then
                for index,key in ipairs(attrs) do if misc==index-1 or misc<0 then add(profile.flat,key,n) end end
            elseif aura==22 or aura==83 then
                for school,bit in pairs(schoolBits) do if U.mod(math.floor(misc/bit),2)==1 then add(profile.flat,"res_"..school,n) end end
                if U.mod(misc,2)==1 then add(profile.flat,"armor",n) end
            elseif aura==13 then
                if misc==1 then add(profile.flat,"physical_damage",n)
                else for school,bit in pairs(schoolBits) do if U.mod(math.floor(misc/bit),2)==1 then add(profile.flat,"power_"..school,n) end end end
            elseif aura==30 or aura==98 then add(profile.flat,"skill_"..misc,n)
            elseif aura==71 then for school,bit in pairs(schoolBits) do if U.mod(math.floor(misc/bit),2)==1 then add(profile.flat,"crit_"..school,n) end end
            elseif aura==79 then
                if U.mod(misc,2)==1 then add(profile.flat,"physical_damage_pct",n) end
                -- School damage percentages change spell damage, not bonus spell power.
            elseif aura==142 and misc==1 then multiplier(profile.factors,"itemArmor",n)
            elseif aura==166 then multiplier(profile.factors,"ap",n)
            elseif aura==167 then multiplier(profile.factors,"rap",n)
            elseif aura==110 then multiplier(profile.factors,"spiritRegen",n)
            elseif aura==174 then add(profile.flat,"spirit_power_pct",n)
            elseif aura==175 then add(profile.flat,"spirit_healing_pct",n)
            elseif simpleAuras[aura] then add(profile.flat,simpleAuras[aura],n)
            elseif not irrelevant[aura] then table.insert(planned and profile.notes or profile.unknown,"Passive "..id.." has unsupported aura "..aura) end
        end
    end
    end
end
function P.Capture()
    local _,class=UnitClass("player")
    local _,race=UnitRace("player")
    local profile={class=class,race=race,classID=OBP.ClassIDs[class],raceID=OBP.RaceIDs[race],
        level=UnitLevel("player"),base={},skills={},professions={},flat={},basePct={},totalPct={},
        factors={},notes={},unknown={},learned={},scoped={},faction=UnitFactionGroup and UnitFactionGroup("player")}
    local learnedIDs,passiveIDs={},{}
    if GetNumSpellTabs then
        for tab=1,GetNumSpellTabs() do
            local _,_,offset,count=GetSpellTabInfo(tab)
            for index=offset+1,offset+count do
                local name=GetSpellName(index,"spell")
                if name then profile.learned[name]=true end
                local id
                if GetSpellBookItemInfo then local _,value=GetSpellBookItemInfo(index,"spell");id=value end
                if not id and C_SpellBook and C_SpellBook.GetSpellBookItemInfo then local info=C_SpellBook.GetSpellBookItemInfo(index,0);id=info and info.spellID end
                if not id and GetSpellInfo then local _,_,_,_,_,_,_,_,_,value=GetSpellInfo(index,"spell");id=value end
                if not id and GetSpellLink then local link=GetSpellLink(index,"spell");id=tonumber(U.match(link,"spell:(%d+)")) end
                if type(id)=="number" then learnedIDs[id]=true end
            end
        end
    end
    if GetTalentSpellID and GetNumTalentTabs then
        for tab=1,GetNumTalentTabs() do
            for index=1,GetNumTalents(tab) do
                local _,_,_,_,rank=GetTalentInfo(tab,index)
                if rank and rank>0 then local id=GetTalentSpellID(tab,index,rank);if id then learnedIDs[id]=true end end
            end
        end
    end
    for id in pairs(learnedIDs) do if passive(id) then passiveIDs[id]=true end end
    profile.dualWield=profile.learned["Dual Wield"] or (IsSpellKnown and IsSpellKnown(674)) or false
    profile.canParry=profile.learned["Parry"] or (IsSpellKnown and IsSpellKnown(3127)) or false
    profile.canBlock=profile.learned["Block"] or (IsSpellKnown and IsSpellKnown(107)) or false
    if GetNumSkillLines then
        for index=1,GetNumSkillLines() do
            local name,isHeader,_,rank,_,modifier=GetSkillLineInfo(index)
            if name and not isHeader then profile.skills[name]=rank;profile.professions[name]=rank end
        end
    end
    -- Remove ALL observed attribute multipliers before deriving the create-stat component.
    -- Reapply only learned passives to the hypothetical loadout. Never subtract real gear.
    local allBase,allTotal,observed={},{},{}
    local baselineSupported=true
    local auraAPI=C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    if auraAPI then
        for _,filter in ipairs({"HELPFUL","HARMFUL"}) do
            for i=1,256 do
                local aura=auraAPI("player",i,filter)
                if not aura then break end
                if aura.spellId then
                    observed[aura.spellId]=true
                    local fx=effects(aura.spellId)
                    if not fx then baselineSupported=false;table.insert(profile.notes,"Cannot inspect active aura "..aura.spellId.." for attribute multipliers.") end
                    if not pctEffects(fx,allBase,allTotal,math.max(1,aura.applications or 1),aura.spellId,profile.level,false) then
                        baselineSupported=false;table.insert(profile.notes,"Active aura "..aura.spellId.." has an unresolved percentage attribute modifier.")
                    end
                end
            end
        end
    end
    profile.sourcePassives=U.copy(passiveIDs)
    profile.normalizationNotes=U.copy(profile.notes)
    for id in pairs(passiveIDs) do
        local fx=effects(id)
        if not fx then baselineSupported=false end
        if not observed[id] and not pctEffects(fx,allBase,allTotal,1,id,profile.level,true) then baselineSupported=false end
        P.ApplyPassive(profile,id,false)
    end
    local noteStart=table.getn(profile.notes)
    if not auraAPI or not (C_Spell and C_Spell.GetSpellEffectInfo) then
        table.insert(profile.notes,"Attribute baseline unavailable: ClassicAPI aura/effect readers are required for normalization.")
    elseif not baselineSupported then
        table.insert(profile.notes,"Attribute baseline unavailable: an attribute modifier could not be resolved; the client APIs are present.")
    else
        for index,key in ipairs(attrs) do
            local _,effective,positive,negative=UnitStat("player",index)
            if effective and positive and negative then
                local scale=(allBase[key] or 1)*(allTotal[key] or 1)
                if scale>0 then
                    -- The server truncates the effective value; a valid integral create stat
                    -- must be within this inversion interval. Ambiguous inputs stay unknown.
                    local lo=(effective-positive-negative)/scale
                    local hi=(effective-positive-negative+1)/scale
                    local candidate=math.ceil(lo-0.0001)
                    if candidate>=0 and candidate<hi-0.0001 and candidate+1>=hi-0.0001 then profile.base[key]=candidate
                    else table.insert(profile.notes,"Ambiguous "..key.." baseline; values depending on it are unavailable.") end
                end
            end
        end
    end
    for i=noteStart+1,table.getn(profile.notes) do table.insert(profile.normalizationNotes,profile.notes[i]) end
    profile.defense=profile.skills["Defense"]
    P.revision=P.revision+1;profile.revision=P.revision
    return profile
end

function P.ForTalents(profile,build)
    if not profile.sourcePassives then return profile end
    local out=U.copy(profile)
    out.flat={};out.basePct={};out.totalPct={};out.factors={};out.scoped={};out.unknown={};out.notes=U.copy(profile.normalizationNotes or {})
    for id in pairs(profile.sourcePassives) do
        if not (OBP.Data.talentSpells and OBP.Data.talentSpells[id]) then P.ApplyPassive(out,id,false) end
    end
    for id,rank in pairs(build.ranks) do
        local talent=OBP.Data.talents[id]
        if talent and talent.spells[rank] then P.ApplyPassive(out,talent.spells[rank],true) end
    end
    return out
end
