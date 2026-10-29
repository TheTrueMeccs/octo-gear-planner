local U=OBP.Util
OBP.Talents={}
local T=OBP.Talents
function T.Class(profile)
    if profile and profile.classID then return profile.classID end
    if UnitClass then local _,class=UnitClass("player");return OBP.ClassIDs[class] end
end
function T.Default(profile)
    return {class=T.Class(profile),level=U.clamp(math.floor(profile and profile.level or (UnitLevel and UnitLevel("player")) or 10),10,60),ranks={}}
end
function T.Trees(build) return OBP.Data.talentTrees and OBP.Data.talentTrees[build.class] or {} end
function T.Spent(build,tab)
    local count=0
    for id,rank in pairs(build.ranks) do
        local talent=OBP.Data.talents and OBP.Data.talents[id]
        if not tab or (talent and talent.tab==tab) then count=count+rank end
    end
    return count
end
function T.Validate(build,profile)
    if type(build)~="table" or type(build.level)~="number" or build.level~=math.floor(build.level) or build.level<10 or build.level>60 or type(build.ranks)~="table" then return nil,"Invalid talent build." end
    for key in pairs(build) do if key~="class" and key~="level" and key~="ranks" then return nil,"Unexpected talent-build data." end end
    local class=T.Class(profile)
    if build.class~=class and class then return nil,"These talents belong to a different class." end
    local tabs={};for _,tab in ipairs(T.Trees(build)) do tabs[tab.id]=true end
    local spent=0
    for id,rank in pairs(build.ranks) do
        local talent=OBP.Data.talents and OBP.Data.talents[id]
        if type(id)~="number" or not talent or not tabs[talent.tab] or type(rank)~="number" or rank~=math.floor(rank) or rank<1 or rank>table.getn(talent.spells) then return nil,"Unknown talent or invalid rank." end
        spent=spent+rank
        if spent>build.level-9 then return nil,"Not enough talent points at this level." end
        for _,req in ipairs(talent.requires) do
            if (build.ranks[req.id] or 0)<req.rank then return nil,"Requires "..req.rank.." points in "..OBP.Data.talents[req.id].name.."." end
        end
        local below=0
        for other,n in pairs(build.ranks) do
            local def=OBP.Data.talents[other]
            if def and def.tab==talent.tab and def.row<talent.row and type(n)=="number" then below=below+n end
        end
        if below<talent.row*5 then return nil,"Requires "..talent.row*5 .." points in earlier tiers of this tree." end
    end
    return true
end
function T.Change(build,id,delta,profile)
    if delta~=1 and delta~=-1 then return nil,"Invalid talent change." end
    local nextBuild=U.copy(build)
    local rank=(nextBuild.ranks[id] or 0)+delta
    if rank<0 then return nil,"No points to remove." end
    nextBuild.ranks[id]=rank>0 and rank or nil
    local valid,reason=T.Validate(nextBuild,profile)
    if not valid then return nil,reason end
    return nextBuild
end
function T.Reset(build,tab)
    local out=U.copy(build)
    for id in pairs(out.ranks) do if not tab or OBP.Data.talents[id].tab==tab then out.ranks[id]=nil end end
    return out
end
function T.CopyCurrent(profile)
    if not GetNumTalentTabs or not GetNumTalents or not GetTalentInfo then return nil,"The client talent reader is unavailable." end
    local build=T.Default(profile)
    local trees=T.Trees(build)
    if table.getn(trees)~=GetNumTalentTabs() then return nil,"The client talent trees differ from the bundled definitions." end
    for tab,tree in ipairs(trees) do
        local matched={}
        for index=1,GetNumTalents(tab) do
            local name,_,row,column,rank,maxRank=GetTalentInfo(tab,index)
            local id
            for _,candidate in ipairs(tree.talents) do
                local def=OBP.Data.talents[candidate]
                if def.row+1==row and def.column+1==column then id=candidate end
            end
            if not id or matched[id] or maxRank~=table.getn(OBP.Data.talents[id].spells) or type(rank)~="number" then return nil,"The client talent layout differs from the bundled definitions: "..tostring(name) end
            if rank<0 or rank~=math.floor(rank) or rank>maxRank then return nil,"The client returned an invalid talent rank: "..tostring(name) end
            if GetTalentIDByIndex and GetTalentIDByIndex(tab,index)~=id then return nil,"The client talent identity differs from the bundled definition: "..tostring(name) end
            if rank>0 and GetTalentSpellID then
                local spell=GetTalentSpellID(tab,index,rank)
                if spell and spell~=OBP.Data.talents[id].spells[rank] then return nil,"The client talent rank differs from the bundled definition: "..tostring(name) end
            end
            matched[id]=true
            if rank>0 then build.ranks[id]=rank end
        end
        if GetNumTalents(tab)~=table.getn(tree.talents) then return nil,"The client talent count differs from the bundled definitions." end
    end
    local valid,reason=T.Validate(build,profile)
    if not valid then return nil,reason end
    return build
end
