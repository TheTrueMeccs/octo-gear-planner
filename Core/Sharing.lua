local U = OBP.Util
OBP.Sharing = {}
local S = OBP.Sharing
function S.Encode(working,profile)
    local name,reason = U.name(working.name=="" and "Untitled" or working.name)
    if not name then return nil,reason end
    local valid,why = OBP.Loadout.Validate(working.loadout,profile)
    if not valid then return nil,why end
    local build=working.talents or OBP.Talents.Default(profile)
    local buildValid,buildReason=OBP.Talents.Validate(build,profile)
    if not buildValid then return nil,buildReason end
    local talents={}
    for _,id in ipairs(U.keys(build.ranks)) do table.insert(talents,id..":"..build.ranks[id]) end
    local entries,instances = {},false
    for _,entry in pairs(working.loadout) do if entry.link or entry.applied then instances=true end end
    for _,slot in ipairs(U.keys(working.loadout)) do
        local entry = working.loadout[slot]
        local enchant = entry.enchant and OBP.Data.enchants[entry.enchant]
        local applied=enchant and enchant.enchantID or entry.applied or 0
        local textEntry=slot..":"..entry.item..":"..(entry.enchant or "0")..":"..applied
        if instances then textEntry=textEntry..":"..(entry.link and U.hex(entry.link) or "0") end
        table.insert(entries,textEntry)
    end
    -- Pipes are escape characters in native WoW edit boxes. The new envelope
    -- keeps every delimiter clipboard-safe without changing item identities.
    local payload = (instances and "OGP4~" or "OGP3~")..U.hex(name).."~"..U.hex(OBP.Data.manifest.version).."~"..table.concat(entries,";").."~"..build.class.."~"..build.level.."~"..table.concat(talents,";")
    return payload.."~"..U.adler(payload)
end
function S.Decode(text,profile)
    if type(text)~="string" then return nil,"Paste an export string." end
    text=U.trim(text)
    if string.len(text)>8192 then return nil,"The import is too long." end
    text=string.gsub(text,"%s","")
    local version=string.sub(text,1,4)
    local modern=version=="OGP3" or version=="OGP4"
    local separator=(version=="OGP2" or modern) and "~" or "|"
    local fields = U.split(text,separator)
    -- Adjacent pipes also encode a legitimate empty equipment field in OGP1.
    -- Unescape WoW's doubled pipes only when the original envelope is not valid.
    if version=="OGP1" and table.getn(fields)~=5 then fields=U.split(string.gsub(text,"||","|"),separator) end
    if (version~="OGP1" and version~="OGP2" and not modern) or fields[1]~=version or table.getn(fields)~=(modern and 8 or 5) then return nil,"Unsupported or malformed export format." end
    local last=table.getn(fields)
    local payload=table.concat(fields,separator,1,last-1)
    if fields[last]~=U.adler(payload) then return nil,"The export checksum does not match. Copy the complete string again." end
    local decodedName=U.unhex(fields[2],64)
    local name,reason = U.name(decodedName)
    if not name or name~=decodedName then return nil,reason or "Invalid set name." end
    local catalogue=U.unhex(fields[3],64)
    if not catalogue or string.find(catalogue,"[^ -~]") then return nil,"Invalid catalogue version." end
    local loadout,entries = {},fields[4]=="" and {} or U.split(fields[4],";")
    if table.getn(entries)>19 then return nil,"Too many equipment slots." end
    for _,textEntry in ipairs(entries) do
        local parts=U.split(textEntry,":")
        if table.getn(parts)~=(version=="OGP4" and 5 or 4) then return nil,"Malformed item entry." end
        local slot=U.integer(parts[1],1,19)
        local id=U.integer(parts[2],1,4294967295)
        local applied=U.integer(parts[4],0,4294967295)
        if not slot or not id or not applied or loadout[slot] then return nil,"Invalid or duplicate equipment slot/identifier." end
        local key=parts[3]
        if key=="0" then
            if applied~=0 and version~="OGP4" then return nil,"An enchantment identifier has no matching enhancement." end
        else
            local prefix,number=string.sub(key,1,1),string.sub(key,2)
            if (prefix~="s" and prefix~="i") or not U.integer(number,1,4294967295) then return nil,"Invalid enhancement key." end
            local enchant=OBP.Data.enchants[key]
            if not enchant or enchant.enchantID~=applied then return nil,"Unknown or mismatched enhancement: "..key end
        end
        local entry={item=id}
        if version=="OGP4" and parts[5]~="0" then
            local link=U.unhex(parts[5],128)
            local linkID,linkEnchant,_,_,canonical=OBP.EquippedItems.Parse(link)
            if linkID~=id or linkEnchant~=0 or canonical~=link then return nil,"Invalid copied item identity." end
            local why
            entry,why=OBP.EquippedItems.Capture(link,slot)
            if not entry then return nil,why end
        end
        entry.enchant=key~="0" and key or nil
        entry.applied=key=="0" and applied>0 and applied or nil
        loadout[slot]=entry
    end
    local okay,why=OBP.Loadout.Validate(loadout,profile)
    if not okay then return nil,why end
    local build=OBP.Talents.Default(profile)
    if modern then
        build.class=U.integer(fields[5],1,11);build.level=U.integer(fields[6],10,60)
        if not build.class or not build.level then return nil,"Invalid talent class or level." end
        local ranks=fields[7]=="" and {} or U.split(fields[7],";")
        if table.getn(ranks)>100 then return nil,"Too many talents." end
        for _,entry in ipairs(ranks) do
            local parts=U.split(entry,":")
            if table.getn(parts)~=2 then return nil,"Malformed talent entry." end
            local id,rank=U.integer(parts[1],1,4294967295),U.integer(parts[2],1,9)
            if not id or not rank or build.ranks[id] then return nil,"Invalid or duplicate talent rank." end
            build.ranks[id]=rank
        end
        local validBuild,reasonBuild=OBP.Talents.Validate(build,profile)
        if not validBuild then return nil,reasonBuild end
    end
    return {name=name,loadout=loadout,catalogue=catalogue,talents=build}
end
