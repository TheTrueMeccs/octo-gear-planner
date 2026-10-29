local U,C = OBP.Util,OBP.Catalogue
OBP.Loadout = {}
local L = OBP.Loadout
function L.Validate(loadout, profile)
    if type(loadout) ~= "table" then return nil,"Invalid equipment data." end
    local counts, count = {}, 0
    for slot, entry in pairs(loadout) do
        count = count + 1
        if count > 19 or not OBP.Slots[slot] or type(entry) ~= "table" then return nil,"Invalid equipment slot." end
        local item = OBP.Data.items[entry.item]
        if not item then return nil,"Item "..tostring(entry.item).." is unavailable in this database." end
        if not C.Fits(item, slot) then return nil,item.name.." cannot go in "..OBP.Slots[slot].name.."." end
        local eligible, reason = C.Eligible(item, profile)
        if not eligible then return nil,reason end
        counts[entry.item] = (counts[entry.item] or 0) + 1
        if item.unique and counts[entry.item] > item.unique then return nil,item.name.." is unique." end
        if entry.enchant then
            local enchant = OBP.Data.enchants[entry.enchant]
            if not C.EnchantFits(enchant,item,profile) then return nil,"This enchantment is not compatible with "..item.name.."." end
        end
    end
    if loadout[16] and loadout[17] and OBP.Data.items[loadout[16].item].inventoryType == 17 then
        return nil,"A two-handed weapon conflicts with the off hand."
    end
    if loadout[17] then
        local inv = OBP.Data.items[loadout[17].item].inventoryType
        if (inv == 13 or inv == 22) and profile and not profile.dualWield then return nil,"Dual wield is not learned on this character." end
    end
    return true
end
function L.Assign(loadout, slot, itemID, profile, clearMain)
    local out, notices = U.copy(loadout), {}
    if not OBP.Slots[slot] then return nil,"Invalid slot." end
    if not itemID then out[slot] = nil; return out,notices end
    local item = OBP.Data.items[itemID]
    if not item or not C.Fits(item,slot) then return nil,"That item does not fit this slot." end
    if slot == 17 and out[16] and OBP.Data.items[out[16].item] and OBP.Data.items[out[16].item].inventoryType == 17 then
        if not clearMain then return nil,"CONFIRM_CLEAR_MAIN" end
        out[16] = nil
        table.insert(notices,"The two-handed weapon was removed.")
    end
    if slot == 16 and item.inventoryType == 17 and out[17] then
        out[17] = nil
        table.insert(notices,"The off hand and its enchantment were removed.")
    end
    local old = out[slot]
    out[slot] = {item=itemID}
    if old and old.enchant then
        if C.EnchantFits(OBP.Data.enchants[old.enchant],item,profile) then out[slot].enchant = old.enchant
        else table.insert(notices,"The old enchantment does not fit this item and was removed.") end
    end
    local valid, reason = L.Validate(out,profile)
    if not valid then return nil,reason end
    return out,notices
end
function L.Enchant(loadout, slot, key, profile)
    if not loadout[slot] then return nil,"Select a planned item first." end
    local out = U.copy(loadout)
    out[slot].enchant = key
    local valid, reason = L.Validate(out,profile)
    if not valid then return nil,reason end
    return out
end
function L.CopyCurrent(profile)
    if type(GetInventoryItemLink)~="function" then return nil,"Current equipment cannot be read on this client." end
    local out,report={}, {copied=0,skipped=0}
    local enchantKeys=U.keys(OBP.Data.enchants)
    for _,slot in ipairs(U.keys(OBP.Slots)) do
        local link=GetInventoryItemLink("player",slot)
        if link then
            local id=tonumber(U.match(link,"item:(%d+)"))
            local item=id and OBP.Data.items[id]
            if item then
                local entry={item=id}
                local _,applied=U.match(link,"item:(%d+):(%d+)")
                applied=tonumber(applied)
                if applied and applied>0 then
                    for _,key in ipairs(enchantKeys) do
                        local enchant=OBP.Data.enchants[key]
                        if enchant.enchantID==applied and C.EnchantFits(enchant,item,profile) then entry.enchant=key;break end
                    end
                end
                out[slot]=entry;report.copied=report.copied+1
            else report.skipped=report.skipped+1 end
        end
    end
    local valid,reason=L.Validate(out,profile)
    if not valid then return nil,reason end
    return out,report
end
