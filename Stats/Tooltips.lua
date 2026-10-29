-- BCS wording with planned values; never call its live-character stat readers.
local S=OBP.Stats
local U=OBP.Util
local aliases={weapon_skill="MELEE_WEAPON_SKILL",ranged_skill="RANGED_WEAPON_SKILL",hit="MELEE_HIT",ranged_hit="RANGED_HIT",crit="MELEE_CRIT",ranged_crit="RANGED_CRIT",boss_miss="MELEE_MISS_VS_BOSS",boss_target_dodge="MELEE_DODGE_VS_BOSS",glancing_damage="MELEE_GLANCE_VS_BOSS",effective_crit="MELEE_EFF_CRIT_VS_BOSS",spell_hit="SPELL_HIT",spell_crit="SPELL_CRIT",spell_haste="SPELL_HASTE",defense="DEFENSE",dodge="PLAYER_DODGE",boss_dodge="PLAYER_DODGE",parry="PLAYER_PARRY",boss_parry="PLAYER_PARRY",block="PLAYER_BLOCK",boss_block="PLAYER_BLOCK",avoidance="TOTAL_AVOIDANCE",boss_avoidance="TOTAL_AVOIDANCE"}
local attributes={str="STRENGTH",agi="AGILITY",sta="STAMINA",int="INTELLECT",spi="SPIRIT"}
local attributeNames={str="Strength",agi="Agility",sta="Stamina",int="Intellect",spi="Spirit"}
local function native(key) return _G[key] or S.NativeTooltipText[key] end
local function fmt(template,...)
    local args,index={...},0
    local text=string.gsub(template or "","%%%%","\001")
    text=string.gsub(text,"%%[%d%.%-]*[dfs]",function(token)
        index=index+1
        if args[index]==nil then return "?" end
        return string.format(token,args[index])
    end)
    return (string.gsub(text,"\001",function() return "%" end))
end
function S.Tooltip(key,profile,result)
    if not key or not result then return end
    local text=S.TooltipText
    local function number(k)
        local entry=result.values[k]
        return entry and entry.status=="complete" and entry.value or nil
    end
    if attributes[key] then
        local stat=attributes[key]
        local body=native((profile.class or "DEFAULT").."_"..stat.."_TOOLTIP") or native("DEFAULT_"..stat.."_TOOLTIP")
        local n=number(key)
        local title="|cffffffff"..attributeNames[key].." "..(n and tostring(math.floor(n+0.5)) or "?")
        local base=profile.base[key] and math.floor(profile.base[key]*(profile.basePct[key] or 1)*(profile.totalPct[key] or 1)+0.00001)
        local bonus=n and base and n-base
        if bonus and bonus~=0 then
            title=title.." ("..base.."|r"..(bonus>0 and (_G.GREEN_FONT_COLOR_CODE or "|cff20ff20").."+"..bonus or (_G.RED_FONT_COLOR_CODE or "|cffff2020").." "..bonus).."|r|cffffffff)"
        end
        title=title.."|r"
        return {title=title,body=body}
    end
    local alias=aliases[key]
    if alias then return {title=fmt(text[alias.."_TOOLTIP"]),body=fmt(text[alias.."_TOOLTIP_SUB"])} end
    if key=="crit_cap" then return end -- BCS leaves this row without a tooltip.
    if key=="armor" then
        local armor=number(key)
        local reduction=armor and 100*armor/(armor+85*profile.level+400)
        return {title="|cffffffff"..native("ARMOR").." "..S.Format(result,key).."|r",body=fmt(native("ARMOR_TOOLTIP"),profile.level,reduction)}
    end
    if key=="ap" or key=="rap" then
        local prefix=key=="ap" and "MELEE" or "RANGED"
        local power=number(key)
        return {title="|cffffffff"..native(prefix.."_ATTACK_POWER").." "..S.Format(result,key).."|r",body=fmt(native(prefix.."_ATTACK_POWER_TOOLTIP"),power and power/14)}
    end
    if key=="spell_power" then return {title=fmt(text.SPELL_POWER_TOOLTIP,number(key)),body=text.SPELL_POWER_TOOLTIP_SUB} end
    if key=="healing" then
        local total,general=number(key),number("spell_power")
        local extra=total and general and total-general
        local title=extra and extra~=0 and fmt(text.SPELL_HEALING_POWER_SECONDARY_TOOLTIP,total,general,extra) or fmt(text.SPELL_HEALING_POWER_TOOLTIP,total)
        return {title=title,body=text.SPELL_HEALING_POWER_TOOLTIP_SUB}
    end
    local school=U.match(key,"^power_(%a+)$")
    if school then
        local total,general=number(key),number("spell_power")
        local extra=total and general and total-general
        local name=string.upper(string.sub(school,1,1))..string.sub(school,2)
        local title=extra and extra>0 and fmt(text.SPELL_SCHOOL_SECONDARY_TOOLTIP,name,total,general,extra) or fmt(text.SPELL_SCHOOL_TOOLTIP,name,total)
        return {title=title,body=fmt(text.SPELL_SCHOOL_TOOLTIP_SUB,school)}
    end
    if key=="regen_pair" then
        local regen,casting=number("regen"),number("regen_casting")
        local mp5=result.totals.mp5 or 0
        local base=regen and (regen-mp5)*0.4
        return {title=fmt(text.SPELL_MANA_REGEN_TOOLTIP,regen and regen*0.4,casting and casting*0.4),body=fmt(text.SPELL_MANA_REGEN_TOOLTIP_SUB,base,result.totals.casting_regen or 0,mp5,mp5*0.4)}
    end
    if key=="melee_damage" or key=="melee_speed" or key=="ranged_damage" or key=="ranged_speed" then
        local ranged=string.find(key,"^ranged")~=nil
        local tip={title=native(ranged and "INVTYPE_RANGED" or "INVTYPE_WEAPONMAINHAND"),rows={}}
        local function weapon(prefix)
            local speed,low,high=number(prefix.."_speed"),number(prefix.."_min"),number(prefix.."_max")
            table.insert(tip.rows,{native("ATTACK_SPEED_COLON"),fmt("%.2f",speed)})
            table.insert(tip.rows,{native("DAMAGE_COLON"),S.Format(result,prefix.."_damage")})
            table.insert(tip.rows,{native("DAMAGE_PER_SECOND"),fmt("%.1f",low and high and speed and (low+high)/2/speed)})
        end
        weapon(ranged and "ranged" or "melee")
        if not ranged and number("off_speed") then table.insert(tip.rows,{"\n"});table.insert(tip.rows,{native("INVTYPE_WEAPONOFFHAND")});weapon("off") end
        local haste=result.totals[ranged and "ranged_haste" or "haste"] or 0
        if haste>0 then table.insert(tip.rows,{"\n"});table.insert(tip.rows,{text.HASTE_COLON,fmt("%d%%",haste)}) end
        return tip
    end
end
