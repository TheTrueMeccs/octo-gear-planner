local U,K,C,L,P,S=OBP.Util,OBP.Compat,OBP.Catalogue,OBP.Loadout,OBP.Persistence,OBP.Stats
local UI=OBP.UI
local PAPER_WIDTH,PAPER_HEIGHT,PAPER_SCALE=320,360,1.2*0.9
local PAPER_COMPACT=0.95
local CHARACTER_SCALE=0.95
local ENCHANT_SCALE,ENCHANT_GAP,ENCHANT_FONT=0.7,6,12
local FILTER_SCALE=0.9
local ADDON_BASE_SCALE=1.1
local ITEM_LAYOUT_SCALE=1.05*1.05
local GRID_COLUMNS,GRID_ICON,GRID_STEP=7,42*0.8*1.1*0.9*ITEM_LAYOUT_SCALE,48*0.8*1.1*0.9*ITEM_LAYOUT_SCALE
local LEFT=PAPER_WIDTH*PAPER_SCALE*PAPER_COMPACT*CHARACTER_SCALE
local CHARACTER_HEIGHT=(PAPER_HEIGHT*PAPER_SCALE+48*0.8*1.1)*1.1*0.9*1.05
local TITLE_HEIGHT=24
local OUTER_MARGIN=20
local TOOLBAR_TOP=OUTER_MARGIN+TITLE_HEIGHT+16
local CONTENT_HEIGHT,CONTENT_TOP=CHARACTER_HEIGHT*CHARACTER_SCALE,OUTER_MARGIN+TITLE_HEIGHT+52
local PAPER_TALL=(CHARACTER_HEIGHT-32)/(PAPER_HEIGHT*PAPER_SCALE)
local HEIGHT=CONTENT_TOP+CONTENT_HEIGHT+OUTER_MARGIN
local GRID_WIDTH=38+GRID_ICON+(GRID_COLUMNS-1)*GRID_STEP
local FILTER,GRID_X,FILTER_X,FULL_WIDTH
local filterGroups={
    {"Rarity",{{"Uncommon",2},{"Rare",3},{"Epic",4},{"Legendary",5}},"qualities"},
    {"Primary Stats",{{"Strength","str"},{"Agility","agi"},{"Stamina","sta"},{"Intellect","int"},{"Spirit","spi"}},"stats"},
    {"Spell",{{"Spell Damage","spell_power"},{"Arcane Spell Damage","power_arcane"},{"Fire Spell Damage","power_fire"},{"Frost Spell Damage","power_frost"},{"Holy Spell Damage","power_holy"},{"Nature Spell Damage","power_nature"},{"Shadow Spell Damage","power_shadow"},{"Spell Hit","spell_hit"},{"Spell Crit","spell_crit"},{"Healing Power","healing"},{"Mana per 5 sec","mp5"},{"Spell Haste","spell_haste"}},"stats"},
    {"Attack",{{"Attack Power","ap"},{"Ranged Attack Power","rap"},{"Melee Hit","hit"},{"Melee Crit","crit"},{"Attack Haste","haste"}},"stats"},
    {"Mitigation",{{"Armor","armor"},{"Defense","defense"},{"Dodge","dodge"},{"Parry","parry"},{"Block","block"},{"Arcane Resistance","res_arcane"},{"Fire Resistance","res_fire"},{"Frost Resistance","res_frost"},{"Nature Resistance","res_nature"},{"Shadow Resistance","res_shadow"}},"stats"},
    {"Aquisiton",C.AcquisitionOptions,"acquisition"}
}

function UI.MeasurePanels()
    local filterLabels={}
    for _,group in ipairs(filterGroups) do for _,option in ipairs(group[2]) do filterLabels[option[1]]=true end end
    for _,item in pairs(OBP.Data.items) do local _,_,name=C.ItemType(item);if name then filterLabels[name]=true end end
    local measure=UI.Text(UIParent,"",11,false);measure:Hide()
    local function widest(labels,size)
        measure:SetFont("Fonts\\FRIZQT__.TTF",size)
        local width=0
        for label in pairs(labels) do measure:SetText(label);width=math.max(width,measure:GetStringWidth()) end
        return width
    end
    -- Include the checkbox, text inset, a small gap and the full native track.
    FILTER=math.max(180,math.ceil(widest(filterLabels,11)+80))
    UI.filterWidth=FILTER
    GRID_X=OUTER_MARGIN+LEFT+11
    FILTER_X=GRID_X+GRID_WIDTH+11
    FULL_WIDTH=FILTER_X+FILTER+OUTER_MARGIN
end

function UI.Save(continuation)
    local function commit(name)
        local okay,reason=P.Save(name,OBP.profile)
        if not okay then UI.Error(reason);return end
        UI.Refresh();if continuation then continuation() end
    end
    if not P.db.active then
        UI.Dialog("Save New Set","Enter a name for this character's planned equipment.",{
            {text="Save",action=commit},{text="Cancel"}
        },{default=""})
    else commit() end
end
function UI.Guard(action)
    if not P.Dirty() then action();return end
    UI.Dialog("Unsaved Changes","Save the changes to this planned set before continuing?",{
        {text="Save",action=function() UI.Save(action) end},
        {text="Discard",action=function() P.Discard();UI.Refresh();action() end},
        {text="Cancel"}
    })
end
function UI.Close()
    UI.Guard(function()
        UI.allowClose=true;UI.main:Hide();UI.allowClose=false
    end)
end
function UI.NewSet()
    UI.Guard(function()
        UI.Dialog("Create New Set","A new set starts with empty slots. Enter a name:",{
            {text="Create",action=function(name)
                local okay,reason=P.Create(name,{},OBP.profile)
                if not okay then UI.Error(reason) else UI.Refresh() end
            end},{text="Cancel"}
        },{default=""})
    end)
end
function UI.Delete(id)
    local function confirm()
        local set=P.db.sets[id];if not set then return end
        UI.Dialog("Delete Set","Delete '"..set.name.."'? This removes the saved set from this character.",{
            {text="Delete",action=function() P.Delete(id);UI.Refresh() end},{text="Cancel"}
        })
    end
    if id==P.db.active then UI.Guard(confirm) else confirm() end
end
function UI.SetOptions()
    local list={}
    for _,id in ipairs(P.db.order) do
        local setID=id
        table.insert(list,{text=P.db.sets[id].name,action=function() UI.Guard(function() P.Select(setID);UI.Refresh() end) end,remove=function() UI.Delete(setID) end})
    end
    table.insert(list,{text="Create New",action=UI.NewSet})
    return list
end
function UI.Export()
    local text,reason=OBP.Sharing.Encode(P.working,OBP.profile)
    if not text then UI.Error(reason);return end
    UI.TextDialog("Export Set",text,"Export")
end
function UI.Import()
    UI.TextDialog("Import Set","","Import",function(text)
        local candidate,reason=OBP.Sharing.Decode(text,OBP.profile)
        if not candidate then UI.Error(reason);return end
        UI.Dialog("Confirm Import","Add '"..candidate.name.."' as a new set with "..OBP.Talents.Spent(candidate.talents).." talent points at budget level "..candidate.talents.level.."? Existing sets will not be overwritten.",{
            {text="Import",action=function()
                UI.Guard(function()
                    local okay,why=P.Import(candidate,OBP.profile)
                    if not okay then UI.Error(why) else UI.Refresh() end
                end)
            end},{text="Cancel"}
        })
    end)
end
function UI.Assign(slot,id,clearMain)
    local loadout,notices=L.Assign(P.working.loadout,slot,id,OBP.profile,clearMain)
    if not loadout then
        if notices=="CONFIRM_CLEAR_MAIN" then
            UI.Dialog("Replace Two-Handed Weapon","This off-hand item requires removing the planned two-handed weapon and its enchantment. Continue?",{
                {text="Replace",action=function() UI.Assign(slot,id,true) end},{text="Cancel"}
            })
        else UI.Error(notices) end
        return
    end
    P.Edit(loadout);UI.Refresh()
    for _,message in ipairs(notices) do U.message(message) end
end
function UI.Enchant(key)
    local entry=P.working.loadout[P.db.prefs.slot]
    if not entry then return end
    local selection=key
    if entry.enchant==key then selection=nil end
    local loadout,reason=L.Enchant(P.working.loadout,P.db.prefs.slot,selection,OBP.profile)
    if not loadout then UI.Error(reason);return end
    P.Edit(loadout);UI.Refresh()
end
function UI.CopyGear()
    local loadout,report=L.CopyCurrent(OBP.profile)
    if not loadout then UI.Error(report);return end
    P.Edit(loadout);UI.Refresh()
    U.message("Copied "..report.copied.." equipped items."..(report.skipped>0 and " Skipped "..report.skipped.." items not in the database." or ""))
end
function UI.SourceLines(item,limit)
    local entries,groups,seenEntries={},{},{}
    for source,chance in C.Sources(item) do
        local names,seen={},{}
        for _,id in ipairs(source.locations or {}) do
            local alias=OBP.Data.instanceAliases and OBP.Data.instanceAliases[id] or id
            local location=OBP.Data.instances[alias];if location and not seen[location] then table.insert(names,location);seen[location]=true end
        end
        local location=source.instance and OBP.Data.instances[source.instance]
        if location and not seen[location] then table.insert(names,location) end
        table.sort(names)
        local locations=table.concat(names,", ")
        -- Identical faction variants share one hover line, but distinct IDs
        -- remain available in the expanded source list.
        local identity=(source.kind or "")..":"..tostring(limit and source.kind=="reward-from" and source.name or source.id or source.name)..":"..locations..":"..tostring(chance)
        if not seenEntries[identity] then
            seenEntries[identity]=true
            local drop=source.kind=="dropped-by" or source.kind=="contained-in" or source.kind=="fished-in"
            local entry={source=source,chance=chance,locations=locations,drop=drop}
            table.insert(entries,entry)
            -- Hover summaries group repeated instance drops; the source dialog
            -- retains every individual relationship and its own probability.
            if limit and drop and locations~="" then
                local key=source.kind..":"..locations
                local group=groups[key]
                if not group then group={count=0,kind=source.kind,locations=locations};groups[key]=group end
                entry.group=group;group.count=group.count+1
                if chance==nil then group.unknown=true
                else group.min=math.min(group.min or chance,chance);group.max=math.max(group.max or chance,chance) end
            end
        end
    end
    local lines,detail={},false
    for _,entry in ipairs(entries) do
        local group=entry.group
        if not (group and group.count>=3 and group.shown) then
            local label="Source: "..entry.source.name
            if not limit and entry.source.side then label=label..(entry.source.side==1 and " (Alliance)" or " (Horde)") end
            local probability=entry.chance~=nil and string.format("%.4g%%",entry.chance) or "?"
            if group and group.count>=3 then
                group.shown=true;detail=true
                local noun=group.kind=="dropped-by" and "creatures" or group.kind=="contained-in" and "containers" or "fishing sources"
                label="Source: "..group.locations.." — "..group.count.." "..noun
                probability="?"
                if not group.unknown then
                    probability=string.format("%.4g%%",group.min)
                    if group.min~=group.max then probability=probability.."–"..string.format("%.4g%%",group.max) end
                    probability=probability..(group.kind=="dropped-by" and " per creature" or " per source")
                end
            elseif entry.locations~="" then label=label.." — "..entry.locations end
            if limit and table.getn(lines)+(entry.drop and 2 or 1)>limit then return lines,true end
            table.insert(lines,label)
            if entry.drop then table.insert(lines,"Drop Chance: "..probability) end
        end
    end
    if table.getn(lines)==0 then return {"Source: Unknown","Drop Chance: ?"} end
    return lines,detail
end
function UI.ItemTooltip(button,id,enchantKey)
    local item=OBP.Data.items[id]
    if not item then
        GameTooltip:SetOwner(button,"ANCHOR_RIGHT");GameTooltip:SetText("Unavailable item #"..tostring(id),1,0.35,0.2)
        GameTooltip:AddLine("This selection is preserved. Right-click its slot to clear it.",1,1,1,true);GameTooltip:Show();return
    end
    UI.hover={button=button,id=id,enchant=enchantKey}
    GameTooltip:SetOwner(button,"ANCHOR_RIGHT")
    if K.Cached(id) then GameTooltip:SetHyperlink(K.Link(id,enchantKey))
    else
        GameTooltip:ClearLines();GameTooltip:AddLine(item.name,UI.Color(item))
        for index,line in ipairs(item.tooltip or {}) do
            if index>1 and index<14 then GameTooltip:AddLine(line,0.9,0.9,0.9,true) end
        end
        if enchantKey and OBP.Data.enchants[enchantKey] then GameTooltip:AddLine(OBP.Data.enchants[enchantKey].name,0.1,1,0.1) end
        K.Request(id)
    end
    GameTooltip:AddLine(" ")
    local sources,moreSources=UI.SourceLines(item,6)
    for _,line in ipairs(sources) do GameTooltip:AddLine(line,1,0.82,0,true) end
    if moreSources then GameTooltip:AddLine("Right-click a browser item for individual sources.",0.7,0.7,0.7,true) end
    if table.getn(item.excluded or {})>0 or item.itemSet then GameTooltip:AddLine("Planned totals exclude set bonuses, procs and on-use effects.",0.65,0.65,0.65,true) end
    local eligible,reason=C.Eligible(item,OBP.profile)
    if not eligible then GameTooltip:AddLine(reason,1,0.2,0.2,true) end
    if table.getn(item.unsupported or {})>0 then GameTooltip:AddLine("Some item effects are not yet supported in calculated totals.",1,0.4,0.2,true) end
    GameTooltip:Show()
end
function UI.LeaveTooltip() UI.hover=nil;GameTooltip:Hide() end
function UI.RefreshCache(id)
    if UI.hover and (not id or UI.hover.id==id) then
        local hover=UI.hover;UI.ItemTooltip(hover.button,hover.id,hover.enchant)
    end
    if UI.main and UI.main:IsShown() and UI.modelMissing and ((id and UI.modelMissing[id]) or (not id and next(UI.modelMissing))) then UI.modelDelay=0.1 end
end
function UI.UpdateModel()
    if not UI.model then return end
    local signature,plan,missing,links={},{},{},{}
    for _,slot in ipairs({4,19,5,7,8,9,10,6,3,15,1,16,17,18}) do
        local entry=P.working.loadout[slot]
        if entry then
            local cached=K.Cached(entry.item);local link=K.Link(entry.item,entry.enchant)
            table.insert(plan,slot..":"..link)
            table.insert(signature,slot..":"..link..":"..tostring(cached))
            if cached then table.insert(links,{slot=slot,link=link}) else missing[entry.item]=true;K.Request(entry.item) end
        end
    end
    UI.modelMissing=missing
    local key=table.concat(signature,";")
    if UI.modelSignature==key then return end
    local planKey=table.concat(plan,";")
    local changed=UI.modelPlan~=planKey
    local rendered=changed and {} or U.copy(UI.modelRendered or {})
    local okay=pcall(function()
        if not UI.modelInitialized then UI.model:SetUnit("player");UI.modelInitialized=true end
        if changed and UI.model.Undress then UI.model:Undress() end
        for _,entry in ipairs(links) do
            if rendered[entry.slot]~=entry.link then UI.model:TryOn(entry.link);rendered[entry.slot]=entry.link end
        end
        UI.model:SetFacing(UI.facing or 0)
    end)
    if not okay then UI.modelNote:SetText("Preview unavailable")
    else UI.modelSignature=key;UI.modelPlan=planKey;UI.modelRendered=rendered;UI.modelNote:SetText("") end
end
function UI.StartRotation(direction)
    UI.rotation={direction=direction,held=true,elapsed=0}
end
function UI.ReleaseRotation()
    local rotation=UI.rotation
    if not rotation then return end
    -- A brief click animates a small turn; holding keeps moving until release.
    rotation.held=false;rotation.remaining=math.max(0,0.18-rotation.elapsed)
    if rotation.remaining==0 then UI.rotation=nil end
end
function UI.UpdateRotation(elapsed)
    local rotation=UI.rotation
    if not rotation then return end
    local step=math.max(0,elapsed or 0)
    if not rotation.held then step=math.min(step,rotation.remaining);rotation.remaining=rotation.remaining-step end
    rotation.elapsed=rotation.elapsed+step
    UI.facing=U.mod((UI.facing or 0)+rotation.direction*step*1.8,2*math.pi)
    if UI.facing<0 then UI.facing=UI.facing+2*math.pi end
    UI.model:SetFacing(UI.facing)
    if not rotation.held and rotation.remaining<=0 then UI.rotation=nil end
end
function UI.BuildPaperDoll()
    -- Scale the whole paper doll, including native artwork, model, slots and
    -- text, inside an unscaled layout frame so adjacent panels stay aligned.
    UI.characterScale=CHARACTER_SCALE
    local outer=CreateFrame("Frame",UI.Name("PaperLayout"),UI.main);UI.paper=outer
    outer:SetWidth(LEFT);outer:SetHeight(CONTENT_HEIGHT);outer:SetPoint("TOPLEFT",UI.main,"TOPLEFT",OUTER_MARGIN,-CONTENT_TOP)
    local pane=UI.Panel(outer,PAPER_WIDTH*PAPER_COMPACT,PAPER_HEIGHT*PAPER_TALL);UI.paperContent=pane
    pane:SetScale(PAPER_SCALE*CHARACTER_SCALE);pane:SetPoint("TOPLEFT",outer,"TOPLEFT",0,0)
    UI.CharacterBackdrop(pane)
    UI.slotButtons={}
    local left={1,2,3,15,5,4,19,9};local right={10,6,7,8,11,12,13,14}
    local function slotButton(slot,x,y)
        local f=UI.Icon(pane,36);f:SetScale(PAPER_COMPACT);f.slot=slot;f:SetPoint("TOPLEFT",pane,"TOPLEFT",x,y*PAPER_TALL/PAPER_COMPACT);UI.slotButtons[slot]=f
        K.Script(f,"OnClick",function(button,mouse)
            if mouse=="RightButton" then UI.Assign(button.slot,nil)
            else P.db.prefs.slot=button.slot;UI.Requery();UI.Refresh() end
        end)
        K.Script(f,"OnEnter",function(button)
            local entry=P.working.loadout[button.slot]
            if entry then UI.ItemTooltip(button,entry.item,entry.enchant)
            else GameTooltip:SetOwner(button,"ANCHOR_RIGHT");GameTooltip:SetText(OBP.Slots[button.slot].name.."\nLeft-click to browse; right-click to clear.",1,0.82,0,true) end
        end)
        K.Script(f,"OnLeave",UI.LeaveTooltip)
    end
    for i,slot in ipairs(left) do slotButton(slot,8,-10-(i-1)*35) end
    for i,slot in ipairs(right) do slotButton(slot,PAPER_WIDTH-44,-10-(i-1)*35) end
    for i,slot in ipairs({16,17,18}) do slotButton(slot,(PAPER_WIDTH-120)/2+(i-1)*42,-300) end
    UI.copyGear=UI.Button(pane,"Copy Current Gear",112,18,UI.CopyGear)
    UI.copyGear:GetFontString():SetFont("Fonts\\FRIZQT__.TTF",10)
    UI.copyGear:SetPoint("BOTTOMLEFT",pane,"BOTTOMLEFT",8,8)
    UI.modelView=CreateFrame("Frame",UI.Name("ModelView"),pane);UI.modelView:SetAllPoints(pane)
    UI.model=CreateFrame("DressUpModel","OBPCharacterModel",UI.modelView)
    UI.model:SetWidth(222*PAPER_COMPACT);UI.model:SetHeight(174*PAPER_TALL-24);UI.model:SetPoint("TOPLEFT",pane,"TOPLEFT",49*PAPER_COMPACT,-20*PAPER_TALL)
    UI.CharacterBackdrop(pane,UI.model,49*PAPER_COMPACT,20*PAPER_TALL)
    UI.modelNote=UI.Text(UI.modelView,"",10,false);UI.modelNote:SetPoint("CENTER",UI.model,"CENTER",0,0)
    UI.rotationButtons={}
    for i,direction in ipairs({-1,1}) do
        local button=CreateFrame("Button",UI.Name("Rotate"),UI.modelView);button:SetWidth(32);button:SetHeight(32);button:SetScale(PAPER_COMPACT);button:SetPoint("TOPLEFT",pane,"TOPLEFT",51+(i-1)*32,-10*PAPER_TALL/PAPER_COMPACT)
        local side=direction==-1 and "Left" or "Right"
        button:SetNormalTexture("Interface\\Buttons\\UI-Rotation"..side.."-Button-Up");button:SetPushedTexture("Interface\\Buttons\\UI-Rotation"..side.."-Button-Down");button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Round")
        local turn=-direction
        K.Script(button,"OnMouseDown",function(_,mouse) if mouse=="LeftButton" then UI.StartRotation(turn) end end)
        K.Script(button,"OnMouseUp",function(_,mouse) if mouse=="LeftButton" then UI.ReleaseRotation() end end)
        K.Script(button,"OnLeave",function() if UI.rotation and UI.rotation.held then UI.rotation=nil end end)
        K.Script(button,"OnHide",function() UI.rotation=nil end)
        UI.rotationButtons[i]=button
    end
    UI.enchantButton=UI.Button(UI.modelView,"Enchants",62,20,function() UI.SetModelView(true) end)
    UI.enchantButton:GetFontString():SetFont("Fonts\\FRIZQT__.TTF",10)
    UI.enchantButton:SetPoint("TOPLEFT",UI.model,"BOTTOMLEFT",0,-4)
    UI.resistances={};UI.resistanceIcons={}
    local slices={arcane=2,fire=0,frost=1,nature=3,shadow=4}
    for i,school in ipairs({"arcane","fire","frost","nature","shadow"}) do
        local frame=CreateFrame("Frame",UI.Name("Resistance"),UI.modelView);frame:SetWidth(32);frame:SetHeight(29);frame:SetScale(PAPER_COMPACT);frame:SetPoint("TOPRIGHT",pane,"TOPRIGHT",-48,(-13-(i-1)*29)*PAPER_TALL/PAPER_COMPACT);frame:EnableMouse(true)
        local icon=frame:CreateTexture(nil,"ARTWORK");icon:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-ResistanceIcons");icon:SetAllPoints(frame);icon:SetTexCoord(0,1,slices[school]*29/256,(slices[school]+1)*29/256);UI.resistanceIcons[school]=icon
        local label=UI.Text(frame,"0",10,false);label:SetPoint("BOTTOM",frame,"BOTTOM",0,3);UI.resistances[school]=label
        UI.Hint(frame,string.upper(string.sub(school,1,1))..string.sub(school,2).." Resistance — planned, unbuffed")
    end
    UI.statPanels={}
    for index=1,2 do
        local column=UI.StatPanel(pane,115,85);column:SetScale(PAPER_COMPACT);column:SetPoint("TOPLEFT",pane,"TOPLEFT",45+(index-1)*115,-222*PAPER_TALL/PAPER_COMPACT)
        column.preference=index==1 and "left" or "right"
        column.dropdown=UI.Dropdown(column,115,"",function()
            local list={}
            for _,name in ipairs(S.Categories) do
                local category=name
                table.insert(list,{text=name,checked=P.db.prefs[column.preference]==category,action=function() P.db.prefs[column.preference]=category;UI.UpdateStats() end})
            end
            return list
        end,true)
        column.dropdown:SetPoint("BOTTOMLEFT",column,"TOPLEFT",0,0);column.rows={}
        for row=1,6 do
            local f=CreateFrame("Frame",UI.Name("StatRow"),column);f:SetWidth(104);f:SetHeight(13);f:SetPoint("TOPLEFT",column,"TOPLEFT",6,-3-(row-1)*13);f:EnableMouse(true)
            f.value=UI.Text(f,"",11,false);f.value:SetFont("Fonts\\ARIALN.TTF",11);f.value:SetPoint("RIGHT",f,"RIGHT",0,0);f.value:SetJustifyH("RIGHT")
            f.label=UI.Text(f,"",11,true);f.label:SetFont("Fonts\\ARIALN.TTF",11);f.label:SetPoint("LEFT",f,"LEFT",0,0);f.label:SetPoint("RIGHT",f.value,"LEFT",-4,0);f.label:SetHeight(13)
            K.Script(f,"OnEnter",function(frame) UI.StatTooltip(frame) end)
            K.Script(f,"OnLeave",function() GameTooltip:Hide() end)
            column.rows[row]=f
        end
        UI.statPanels[index]=column
    end
end
function UI.StatTooltip(frame)
    local tip=S.Tooltip(frame.key,UI.statProfile or OBP.profile,UI.result)
    if not tip then GameTooltip:Hide();return end
    GameTooltip:SetOwner(frame,"ANCHOR_RIGHT");GameTooltip:SetText(tip.title,1,1,1,false)
    if tip.body and tip.body~="" then GameTooltip:AddLine(tip.body,1,0.82,0,true) end
    for _,row in ipairs(tip.rows or {}) do
        if row[2] then GameTooltip:AddDoubleLine(row[1],row[2],1,0.82,0,1,1,1)
        else GameTooltip:AddLine(row[1],1,1,1) end
    end
    GameTooltip:Show()
end
function UI.UpdateStats()
    UI.statProfile=OBP.Profile.ForTalents(OBP.profile,P.working.talents)
    UI.result=S.Evaluate(UI.statProfile,P.working.loadout)
    for _,column in ipairs(UI.statPanels) do
        local category=P.db.prefs[column.preference]
        if not S.Rows[category] then category=column.preference=="left" and "Base Stats" or "Spell";P.db.prefs[column.preference]=category end
        column.dropdown:SetText(category)
        for i,spec in ipairs(S.Rows[category]) do
            local row=column.rows[i];row.title,row.key=spec[1],spec[2]
            row.label:SetText(spec[1]..":");row.value:SetText(S.Format(UI.result,spec[2]))
        end
    end
    for school,label in pairs(UI.resistances) do label:SetText(S.Format(UI.result,"res_"..school)) end
end
function UI.ItemOptions(kind)
    local options={{text="All",always=true,action=function() P.db.prefs.filters[kind]=nil;UI.UpdateFilterLabels();UI.Requery() end}}
    local ids=U.keys(OBP.Data.instances)
    table.sort(ids,function(a,b) return OBP.Data.instances[a]<OBP.Data.instances[b] end)
    for _,id in ipairs(ids) do
        local instance=id
        table.insert(options,{text=OBP.Data.instances[id],action=function() P.db.prefs.filters.instance=instance;UI.UpdateFilterLabels();UI.Requery() end})
    end
    return options
end
UI.sortLabels={ilevel_desc="Item Lvl ↓",ilevel_asc="Item Lvl ↑",name_asc="Name A–Z",name_desc="Name Z–A",quality_desc="Rarity ↓",quality_asc="Rarity ↑",required_desc="Req. Lvl ↓",required_asc="Req. Lvl ↑"}
function UI.SortOptions()
    local out={}
    for _,spec in ipairs({{"ilevel_desc","Item Level: High to Low"},{"ilevel_asc","Item Level: Low to High"},{"name_asc","Name: A to Z"},{"name_desc","Name: Z to A"},{"quality_desc","Rarity: High to Low"},{"quality_asc","Rarity: Low to High"},{"required_desc","Required Level: High to Low"},{"required_asc","Required Level: Low to High"}}) do
        local mode=spec[1]
        table.insert(out,{text=spec[2],checked=P.db.prefs.sort==mode,action=function() P.db.prefs.sort=mode;UI.UpdateFilterLabels();UI.Requery() end})
    end
    return out
end
function UI.ApplyLevels()
    local a=U.integer(U.trim(UI.minLevel:GetText())=="" and "1" or U.trim(UI.minLevel:GetText()),1,60)
    local b=U.integer(U.trim(UI.maxLevel:GetText())=="" and "60" or U.trim(UI.maxLevel:GetText()),1,60)
    if not a or not b or a>b then
        UI.minLevel:SetText(tostring(P.db.prefs.filters.minLevel));UI.maxLevel:SetText(tostring(P.db.prefs.filters.maxLevel))
        U.message("Level range must be whole numbers from 1 to 60, with minimum no greater than maximum.");return
    end
    P.db.prefs.filters.minLevel=a;P.db.prefs.filters.maxLevel=b;UI.minLevel:SetText(tostring(a));UI.maxLevel:SetText(tostring(b));UI.Requery()
end
function UI.UpdateFilterLabels()
    local filters=P.db.prefs.filters
    UI.instance:SetText(filters.instance and OBP.Data.instances[filters.instance] or "All Instances")
    if UI.sortDropdown then UI.sortDropdown:SetText(UI.sortLabels[P.db.prefs.sort]) end
end
function UI.BuildBrowser()
    local x,width=GRID_X,GRID_WIDTH
    UI.browserWidth=width
    local available=width-22
    local searchWidth,sortWidth=available*0.6,available*0.4
    UI.sortDropdown=UI.Dropdown(UI.main,sortWidth,"",UI.SortOptions);UI.sortDropdown:SetPoint("TOPLEFT",UI.main,"TOPLEFT",x+6+searchWidth+10,-TOOLBAR_TOP);UI.sortDropdown:GetFontString():SetFont("Fonts\\FRIZQT__.TTF",10)
    UI.sortLabel=UI.Text(UI.main,"Sort",10,true);UI.sortLabel:SetPoint("BOTTOMLEFT",UI.sortDropdown,"TOPLEFT",6,4)
    UI.search=UI.Input(UI.main,searchWidth,P.db.prefs.filters.name);UI.search:SetPoint("TOPLEFT",UI.main,"TOPLEFT",x+6,-TOOLBAR_TOP);UI.search:SetMaxLetters(128)
    UI.searchLabel=UI.Text(UI.main,"Search",10,true);UI.searchLabel:SetPoint("BOTTOMLEFT",UI.search,"TOPLEFT",0,4)
    K.Script(UI.search,"OnTextChanged",function(f)
        P.db.prefs.filters.name=f:GetText();UI.searchDelay=0.12
    end)
    UI.grid=UI.Panel(UI.main,width,CONTENT_HEIGHT);UI.grid:SetPoint("TOPLEFT",UI.main,"TOPLEFT",x,-CONTENT_TOP)
    UI.CharacterBackdrop(UI.grid)
    UI.gridButtons={};UI.iconSize=GRID_ICON;UI.columns=GRID_COLUMNS;UI.visibleRows=math.floor((CONTENT_HEIGHT-16+4)/(GRID_ICON+4));UI.scrollRow=0
    -- Reserve the native 31-unit scrollbar frame plus an inner gap. Its
    -- recessed track and arrow caps stay wholly inside the panel border.
    UI.gridPitch=UI.columns>1 and (width-51-UI.iconSize)/(UI.columns-1) or GRID_STEP
    -- Fit complete rows with at least four units between icons and eight-unit outer margins.
    UI.gridRowPitch=(CONTENT_HEIGHT-16-UI.iconSize)/(UI.visibleRows-1)
    for index=1,UI.columns*UI.visibleRows do
        local button=UI.Icon(UI.grid,UI.iconSize);button:SetPoint("TOPLEFT",UI.grid,"TOPLEFT",8+U.mod(index-1,UI.columns)*UI.gridPitch,-8-math.floor((index-1)/UI.columns)*UI.gridRowPitch)
        K.Script(button,"OnClick",function(f,mouse)
            if not f.itemID then return end
            if mouse=="RightButton" then
                local item=OBP.Data.items[f.itemID];UI.TextDialog(item.name.." — Sources",table.concat(UI.SourceLines(item),"\n"),"Sources")
            else UI.Assign(P.db.prefs.slot,f.itemID) end
        end)
        K.Script(button,"OnEnter",function(f) if f.itemID then UI.ItemTooltip(f,f.itemID) end end)
        K.Script(button,"OnLeave",UI.LeaveTooltip)
        UI.gridButtons[index]=button
    end
    UI.gridEmpty=UI.Text(UI.grid,"No items match these filters.",12,false);UI.gridEmpty:SetPoint("CENTER",UI.grid,"CENTER",0,15)
    UI.gridClear=UI.Button(UI.grid,"Clear Filters",120,24,UI.ClearFilters);UI.gridClear:SetPoint("TOP",UI.gridEmpty,"BOTTOM",0,-14)
    UI.gridBar=UI.Scrollbar(UI.grid,CONTENT_HEIGHT-55,function(row) UI.scrollRow=row;UI.RenderGrid() end);UI.gridBar:SetPoint("TOPRIGHT",UI.grid,"TOPRIGHT",-13.5,-29)
    UI.grid:EnableMouseWheel(true);K.Script(UI.grid,"OnMouseWheel",function(_,delta) UI.gridBar:SetValue(U.clamp(UI.scrollRow-(delta or 0)*2,0,UI.maxScroll or 0)) end)
end
function UI.Requery()
    UI.results=C.Sort(C.Query(P.db.prefs.slot,P.db.prefs.filters,OBP.profile,P.db.prefs.hideUnusable),P.db.prefs.sort)
    UI.scrollRow=0;UI.maxScroll=math.max(0,math.ceil(table.getn(UI.results)/UI.columns)-UI.visibleRows)
    UI.gridBar:SetMinMaxValues(0,UI.maxScroll);UI.gridBar:SetValue(0);UI.RenderGrid()
    UI.RefreshFilterChecks()
end
function UI.RenderGrid()
    local selected=P.working.loadout[P.db.prefs.slot]
    for index,button in ipairs(UI.gridButtons) do
        local id=UI.results and UI.results[index+UI.scrollRow*UI.columns]
        button.itemID=id
        if id then UI.PaintItem(button,OBP.Data.items[id],selected and selected.item==id);button:Show() else button:Hide() end
    end
    if not UI.results or table.getn(UI.results)==0 then UI.gridEmpty:Show();UI.gridClear:Show() else UI.gridEmpty:Hide();UI.gridClear:Hide() end
end
function UI.ClearFilters()
    P.db.prefs.filters=P.DefaultFilters();UI.search:SetText("");UI.minLevel:SetText("1");UI.maxLevel:SetText("60");UI.UpdateFilterLabels();UI.RefreshFilterChecks();UI.Requery()
end
function UI.BuildSidePanels()
    UI.filterFrame=UI.Panel(UI.main,FILTER,CONTENT_HEIGHT);UI.filterFrame:SetPoint("TOPLEFT",UI.main,"TOPLEFT",FILTER_X,-CONTENT_TOP)
    UI.CharacterBackdrop(UI.filterFrame)
    -- Scale the whole filter interface together while filling the existing panel.
    local controls=CreateFrame("Frame",UI.Name("FilterControls"),UI.filterFrame);UI.filterControls=controls
    local width,height=FILTER/FILTER_SCALE,CONTENT_HEIGHT/FILTER_SCALE
    controls:SetScale(FILTER_SCALE);controls:SetWidth(width);controls:SetHeight(height);controls:SetPoint("TOPLEFT",UI.filterFrame,"TOPLEFT",0,0)
    UI.filterTitle=UI.Text(controls,"Filters",16,true);UI.filterTitle:SetPoint("TOP",controls,"TOP",0,-12);UI.filterTitle:SetJustifyH("CENTER")
    local filterHeight=height-216
    UI.instanceLabel=UI.Text(controls,"Instance",11,true)
    local labelLeft=18
    local fieldLeft=math.max(74,math.ceil(UI.instanceLabel:GetStringWidth())+30)
    -- Native InputBoxTemplate artwork extends five units left of its frame.
    local inputLeft=fieldLeft+5
    local function rowLabel(label,top)
        label:SetPoint("TOPLEFT",controls,"TOPLEFT",labelLeft,-top);label:SetWidth(fieldLeft-labelLeft-12);label:SetHeight(24);label:SetJustifyV("MIDDLE")
    end
    UI.instance=UI.Dropdown(controls,width-fieldLeft-12,"All Instances",function() return UI.ItemOptions("instance") end,false,true);UI.instance:SetHeight(24*0.95);UI.instance:SetPoint("TOPLEFT",controls,"TOPLEFT",fieldLeft,-50-24*0.05/2)
    -- Native button textures contain two padded columns on either side of
    -- their silver edge. Crop those so the visible border fills the frame.
    for _,getter in ipairs({"GetNormalTexture","GetPushedTexture","GetDisabledTexture"}) do
        local texture=UI.instance[getter](UI.instance)
        if texture then texture:SetTexCoord(2/128,78/128,0,22/32) end
    end
    rowLabel(UI.instanceLabel,50)
    local instanceText=UI.instance:GetFontString()
    instanceText:ClearAllPoints();instanceText:SetPoint("LEFT",UI.instance,"LEFT",24,0);instanceText:SetPoint("RIGHT",UI.instance,"RIGHT",-24,0);instanceText:SetJustifyH("CENTER");instanceText:SetFont("Fonts\\FRIZQT__.TTF",11)
    UI.levelLabel=UI.Text(controls,"Level",11,true);rowLabel(UI.levelLabel,86)
    UI.minLevel=UI.Input(controls,27,tostring(P.db.prefs.filters.minLevel));UI.minLevel:SetPoint("TOPLEFT",controls,"TOPLEFT",inputLeft,-86)
    local dash=UI.Text(controls,"–",11,false);dash:SetPoint("LEFT",UI.minLevel,"RIGHT",5,0)
    UI.maxLevel=UI.Input(controls,27,tostring(P.db.prefs.filters.maxLevel));UI.maxLevel:SetPoint("TOPLEFT",controls,"TOPLEFT",inputLeft+43,-86)
    for _,field in ipairs({UI.minLevel,UI.maxLevel}) do
        K.Script(field,"OnEnterPressed",function(f) UI.ApplyLevels();f:ClearFocus() end)
        K.Script(field,"OnEditFocusLost",UI.ApplyLevels)
        K.Script(field,"OnEscapePressed",function(f) f:ClearFocus() end)
    end
    local label=UI.Text(controls,"Search",11,true);UI.filterSearchLabel=label;rowLabel(label,122)
    UI.filterSearch=UI.Input(controls,width-inputLeft-12,"");UI.filterSearch:SetPoint("TOPLEFT",controls,"TOPLEFT",inputLeft,-122);UI.filterSearch:SetMaxLetters(80)
    UI.filterBody=CreateFrame("ScrollFrame",UI.Name("FilterBody"),controls);UI.filterBody:SetPoint("TOPLEFT",controls,"TOPLEFT",12,-160);UI.filterBody:SetWidth(width-54);UI.filterBody:SetHeight(filterHeight)
    local content=CreateFrame("Frame",UI.Name("FilterContent"),UI.filterBody);UI.filterContent=content;content:SetWidth(width-54);content:SetHeight(1100);UI.filterBody:SetScrollChild(content)
    UI.typeTitle=UI.Text(content,"",14,true);UI.typeChecks={}
    UI.filterChecks={};UI.filterGroups={}
    for _,group in ipairs(filterGroups) do
        local section={name=group[1],title=UI.Text(content,group[1],14,true),checks={}};table.insert(UI.filterGroups,section)
        for _,option in ipairs(group[2]) do
            local check=UI.Check(content,option[1],function(f)
                local selected=P.db.prefs.filters[f.group]
                if f.group=="stats" or f.group=="qualities" or f.group=="acquisition" then
                    local state=selected[f.key]
                    if state==true then selected[f.key]=-1 elseif state==-1 then selected[f.key]=nil else selected[f.key]=true end
                else selected[f.key]=f:GetChecked() and true or nil end
                UI.Requery()
            end)
            if group[3]=="stats" or group[3]=="qualities" or group[3]=="acquisition" then
                check.excludeMark=UI.Text(check,"X",15,false);check.excludeMark:SetPoint("CENTER",check,"CENTER",0,0);check.excludeMark:SetTextColor(1,0.15,0.15);check.excludeMark:Hide()
                UI.Hint(check,group[3]=="qualities" and "Click to cycle: include this rarity, exclude this rarity, clear." or group[3]=="acquisition" and "Click to cycle: include this acquisition type, exclude this acquisition type, clear." or "Click to cycle: require this stat, exclude this stat, clear.")
            end
            check.group,check.key=group[3],option[2];table.insert(section.checks,check);table.insert(UI.filterChecks,check)
        end
    end
    UI.filterEmpty=UI.Text(content,"No filters match this search.",12,false);UI.filterEmpty:SetPoint("TOPLEFT",content,"TOPLEFT",0,0);UI.filterEmpty:SetWidth(width-54);UI.filterEmpty:SetHeight(42);UI.filterEmpty:Hide()
    UI.filterBar=UI.Scrollbar(controls,filterHeight-39,function(n) UI.filterBody:SetVerticalScroll(n) end);UI.filterBar:SetPoint("TOPRIGHT",controls,"TOPRIGHT",-13.5,-181)
    K.Script(UI.filterSearch,"OnTextChanged",function() UI.filterContext=nil;UI.RefreshFilterChecks() end)
    UI.filterBody:EnableMouseWheel(true);K.Script(UI.filterBody,"OnMouseWheel",function(_,delta) UI.filterBar:SetValue(U.clamp(UI.filterBar:GetValue()-(delta or 0)*32,0,UI.filterMax or 0)) end)
    UI.filterClear=UI.Button(controls,"Clear Filters",120,25,UI.ClearFilters);UI.filterClear:SetPoint("BOTTOM",controls,"BOTTOM",0,15)
    -- Replace only the model viewport; equipment slots and stat panels are
    -- siblings outside both views and remain available during enchant editing.
    local pane=UI.paperContent
    local width,height=UI.model:GetWidth(),184*PAPER_TALL
    UI.enchantFrame=CreateFrame("Frame",UI.Name("ModelEnchantments"),pane)
    UI.enchantFrame:SetWidth(width);UI.enchantFrame:SetHeight(height);UI.enchantFrame:SetPoint("TOPLEFT",pane,"TOPLEFT",49*PAPER_COMPACT,-10*PAPER_TALL)
    UI.CharacterBackdrop(pane,UI.enchantFrame,49*PAPER_COMPACT,10*PAPER_TALL)
    UI.enchantBack=UI.Button(UI.enchantFrame,"Back",48,20,function() UI.SetModelView(false) end);UI.enchantBack:GetFontString():SetFont("Fonts\\FRIZQT__.TTF",10);UI.enchantBack:SetPoint("TOPLEFT",UI.model,"BOTTOMLEFT",0,-4)
    -- Fill the viewport with editing controls, reserving a bottom strip for
    -- Back at the same lower-left position as the model-view Enchants button.
    local content=CreateFrame("Frame",UI.Name("EnchantmentControls"),UI.enchantFrame);UI.enchantContent=content
    local contentWidth,contentHeight=width/ENCHANT_SCALE,(height-32)/ENCHANT_SCALE
    content:SetScale(ENCHANT_SCALE);content:SetWidth(contentWidth);content:SetHeight(contentHeight);content:SetPoint("TOPLEFT",UI.enchantFrame,"TOPLEFT",0,-8/ENCHANT_SCALE)
    local searchLabel=UI.Text(content,"Search",10,true);UI.enchantSearchLabel=searchLabel;searchLabel:SetPoint("TOPLEFT",content,"TOPLEFT",6,-6)
    UI.enchantSearch=UI.Input(content,contentWidth-60,"");UI.enchantSearch:SetPoint("TOPLEFT",content,"TOPLEFT",48,0);UI.enchantSearch:SetMaxLetters(80)
    UI.enchantRows={};UI.enchantOffset=0
    UI.enchantMeasure=UI.Text(content,"",ENCHANT_FONT,false);UI.enchantMeasure:SetWidth(contentWidth-70);UI.enchantMeasure:Hide()
    UI.enchantListTop=36;UI.enchantListHeight=contentHeight-44
    for index=1,math.floor(UI.enchantListHeight/30) do
        local check=UI.Check(content,"",function(f) if f.key then UI.Enchant(f.key) end end)
        check.label:ClearAllPoints();check.label:SetPoint("TOPLEFT",check,"TOPRIGHT",2,-4);check.label:SetWidth(contentWidth-70);check.label:SetFont("Fonts\\FRIZQT__.TTF",ENCHANT_FONT);check.label:SetJustifyV("TOP")
        check.bonus=UI.Text(check,"",ENCHANT_FONT,false);check.bonus:SetTextColor(0.2,1,0.2);check.bonus:SetPoint("TOPLEFT",check.label,"BOTTOMLEFT",0,-2);check.bonus:SetWidth(contentWidth-70);check.bonus:SetJustifyV("TOP")
        K.Script(check,"OnEnter",function(f)
            local enchant=f.key and OBP.Data.enchants[f.key];if not enchant then return end
            GameTooltip:SetOwner(f,"ANCHOR_LEFT");GameTooltip:SetText(enchant.name,1,0.82,0)
            GameTooltip:AddLine(enchant.description or enchant.bonus,1,1,1,true)
            for _,text in ipairs(enchant.excluded or {}) do GameTooltip:AddLine(text,0.7,0.7,0.7,true) end
            for _,text in ipairs(enchant.unsupported or {}) do GameTooltip:AddLine(text,1,0.4,0.2,true) end
            GameTooltip:Show()
        end)
        K.Script(check,"OnLeave",function() GameTooltip:Hide() end)
        UI.enchantRows[index]=check
    end
    UI.enchantEmpty=UI.Text(content,"Select an item to see compatible enchantments.",10,false);UI.enchantEmpty:SetPoint("TOPLEFT",content,"TOPLEFT",6,-40);UI.enchantEmpty:SetWidth(contentWidth-48);UI.enchantEmpty:SetHeight(54)
    UI.enchantBar=UI.Scrollbar(content,UI.enchantListHeight-39,function(n) UI.enchantOffset=n;UI.RenderEnchantments() end);UI.enchantBar:SetPoint("TOPRIGHT",content,"TOPRIGHT",-11.5,-UI.enchantListTop-21)
    K.Script(UI.enchantSearch,"OnTextChanged",function() UI.enchantOffset=0;UI.enchantBar:SetValue(0);UI.RenderEnchantments() end)
    UI.enchantFrame:EnableMouseWheel(true);K.Script(UI.enchantFrame,"OnMouseWheel",function(_,delta) UI.enchantBar:SetValue(U.clamp(UI.enchantOffset-(delta or 0),0,UI.enchantMax or 0)) end)
    UI.SetModelView(false)
    UI.UpdateFilterLabels()
    UI.RefreshFilterChecks()
end
function UI.SetModelView(enchantments)
    if not UI.enchantFrame then return end
    UI.enchantMode=enchantments and true or false;UI.rotation=nil;GameTooltip:Hide()
    if UI.menu then UI.menu:Hide() end
    if UI.enchantMode then UI.modelView:Hide();UI.enchantFrame:Show();UI.RenderEnchantments()
    else UI.enchantSearch:ClearFocus();UI.enchantFrame:Hide();UI.modelView:Show() end
end
function UI.RefreshFilterChecks()
    if not UI.typeTitle then return end
    local group,title,options=C.TypeOptions(P.db.prefs.slot,OBP.profile,P.db.prefs.hideUnusable)
    local content,y=UI.filterContent,0
    local query=string.lower(U.trim(UI.filterSearch:GetText()))
    local function matches(text) return query=="" or string.find(string.lower(text or ""),query,1,true) end
    UI.typeGroup=group
    -- Rarity is the first scroll section, below Instance, Level and Search.
    local rarity=UI.filterGroups[1]
    local rarityVisible=false
    for _,check in ipairs(rarity.checks) do if matches(rarity.name) or matches(check.label:GetText()) then rarityVisible=true end end
    if rarityVisible then
        rarity.title:ClearAllPoints();rarity.title:SetPoint("TOPLEFT",content,"TOPLEFT",0,0);rarity.title:Show();y=26
        for _,check in ipairs(rarity.checks) do
            if matches(rarity.name) or matches(check.label:GetText()) then check:ClearAllPoints();check:SetPoint("TOPLEFT",content,"TOPLEFT",0,-y);check:Show();y=y+24 else check:Hide() end
        end
        y=y+14
    else rarity.title:Hide();for _,check in ipairs(rarity.checks) do check:Hide() end end
    local showTypes=false
    for _,option in ipairs(options) do if matches(title) or matches(option.text) then showTypes=true end end
    if showTypes then UI.typeTitle:SetText(title);UI.typeTitle:ClearAllPoints();UI.typeTitle:SetPoint("TOPLEFT",content,"TOPLEFT",0,-y);UI.typeTitle:Show();y=y+26
    else UI.typeTitle:Hide() end
    for index=1,math.max(table.getn(options),table.getn(UI.typeChecks)) do
        local option=options[index];local check=UI.typeChecks[index]
        if option then
            if not check then
                check=UI.Check(content,"",function(f) P.db.prefs.filters[f.group][f.key]=f:GetChecked() and true or nil;UI.Requery() end)
                UI.typeChecks[index]=check
            end
            check.group,check.key=group,option.key;check.label:SetText(option.text);check:SetChecked(P.db.prefs.filters[group][option.key])
            if matches(title) or matches(option.text) then check:ClearAllPoints();check:SetPoint("TOPLEFT",content,"TOPLEFT",0,-y);check:Show();y=y+24
            else check:Hide() end
        elseif check then check:Hide() end
    end
    if showTypes then y=y+14 end
    for sectionIndex=2,table.getn(UI.filterGroups) do
        local section=UI.filterGroups[sectionIndex]
        local show=false
        for _,check in ipairs(section.checks) do if matches(section.name) or matches(check.label:GetText()) then show=true end end
        if show then
            section.title:ClearAllPoints();section.title:SetPoint("TOPLEFT",content,"TOPLEFT",0,-y);section.title:Show();y=y+26
            for _,check in ipairs(section.checks) do
                if matches(section.name) or matches(check.label:GetText()) then check:ClearAllPoints();check:SetPoint("TOPLEFT",content,"TOPLEFT",0,-y);check:Show();y=y+24
                else check:Hide() end
            end
            y=y+14
        else section.title:Hide();for _,check in ipairs(section.checks) do check:Hide() end end
    end
    if y==0 then UI.filterEmpty:Show();y=32 else UI.filterEmpty:Hide() end
    content:SetHeight(y);UI.filterMax=math.max(0,y-UI.filterBody:GetHeight());UI.filterBar:SetMinMaxValues(0,UI.filterMax)
    local context=tostring(P.db.prefs.slot)..":"..tostring(P.db.prefs.hideUnusable)..":"..tostring(group)
    UI.filterBar:SetValue(context~=UI.filterContext and 0 or U.clamp(UI.filterBar:GetValue(),0,UI.filterMax));UI.filterContext=context
    for _,check in ipairs(UI.filterChecks or {}) do
        local state=P.db.prefs.filters[check.group][check.key]
        check:SetChecked(state==true)
        if check.excludeMark then if state==-1 then check.excludeMark:Show() else check.excludeMark:Hide() end end
    end
end
function UI.EnchantmentBonus(enchant)
    local bonus=enchant.bonus or "No static bonus"
    local labels,amounts=U.match(bonus,"^(.-)%s+%+([%d%./%-]+)$")
    if labels and string.find(labels,"/",1,true) then
        local names,values,lines={},{},{}
        for _,part in ipairs(U.split(labels,"/")) do table.insert(names,U.trim(part)) end
        for _,part in ipairs(U.split(amounts,"/")) do table.insert(values,U.trim(part)) end
        if table.getn(names)==table.getn(values) then
            for i,name in ipairs(names) do table.insert(lines,name.." +"..values[i]) end
            return table.concat(lines,"\n")
        end
    end
    bonus=string.gsub(bonus,"%s*/%s*","\n")
    return (string.gsub(bonus,",%s*%+","\n+"))
end
function UI.RenderEnchantments()
    local entry=P.working.loadout[P.db.prefs.slot];local item=entry and OBP.Data.items[entry.item]
    local keys=C.Enchantments(item,OBP.profile)
    local query=string.lower(U.trim(UI.enchantSearch:GetText()))
    UI.enchantKeys={}
    for _,key in ipairs(keys) do
        local enchant=OBP.Data.enchants[key]
        if query=="" or string.find(string.lower(enchant.name.." "..(enchant.bonus or "")),query,1,true) then table.insert(UI.enchantKeys,key) end
    end
    local metrics={}
    local available=UI.enchantListHeight
    local function height(text)
        UI.enchantMeasure:SetText(text);UI.enchantMeasure:SetHeight(0)
        return math.max(math.ceil(ENCHANT_FONT*1.2)*table.getn(U.split(text,"\n")),UI.enchantMeasure:GetHeight())
    end
    for _,key in ipairs(UI.enchantKeys) do
        local enchant=OBP.Data.enchants[key];local bonus=UI.EnchantmentBonus(enchant)
        local nameHeight=height(enchant.name);local bonusHeight=height(bonus)
        table.insert(metrics,{bonus=bonus,nameHeight=nameHeight,bonusHeight=bonusHeight,height=math.max(24,4+nameHeight+2+bonusHeight)})
    end
    local first,used=table.getn(metrics)+1,0
    for i=table.getn(metrics),1,-1 do
        local needed=metrics[i].height+(used>0 and ENCHANT_GAP or 0)
        if used>0 and used+needed>available then break end
        used=used+needed;first=i
    end
    UI.enchantMax=math.max(0,first-1)
    UI.enchantOffset=U.clamp(UI.enchantOffset,0,UI.enchantMax);UI.enchantBar:SetMinMaxValues(0,UI.enchantMax)
    local y=0
    for index,check in ipairs(UI.enchantRows) do
        local position=index+UI.enchantOffset;local key=UI.enchantKeys[position];local metric=metrics[position]
        if key and (y==0 or y+metric.height<=available) then
            local enchant=OBP.Data.enchants[key];check.key=key;check.label:SetText(enchant.name);check.bonus:SetText(metric.bonus);check:SetChecked(entry and entry.enchant==key)
            check.label:SetHeight(metric.nameHeight);check.bonus:SetHeight(metric.bonusHeight);check.entryHeight=metric.height
            check:ClearAllPoints();check:SetPoint("TOPLEFT",UI.enchantContent,"TOPLEFT",4,-UI.enchantListTop-y);check:Show();y=y+metric.height+ENCHANT_GAP
        else check.key=nil;check:Hide();y=available+1 end
    end
    if table.getn(UI.enchantKeys)==0 then UI.enchantEmpty:SetText(not item and "Select an item to see compatible enchantments." or query~="" and "No enchantments match this search." or "No compatible permanent enchantments are known for this item.");UI.enchantEmpty:Show()
    else UI.enchantEmpty:Hide() end
end
function UI.UpdateScaleSettings()
    if not UI.settings then return end
    local settings=UI.settings
    local requested=math.floor(P.db.prefs.uiScale*100+0.5)
    local actual=math.floor(UI.main:GetScale()/ADDON_BASE_SCALE*100+0.5)
    settings.scaleLabel:SetText("Addon scale: "..requested.."%"..(actual<requested and " (screen fit: "..actual.."%)" or ""))
    UI.scaleSync=true;settings.scaleSlider:SetValue(requested);UI.scaleSync=nil
end
function UI.ApplyScale(keepPosition)
    local frame=UI.main
    if not frame then return end
    local x,y
    if keepPosition and frame:GetLeft() and frame:GetBottom() then
        x=(frame:GetLeft()+frame:GetWidth()/2)*frame:GetScale()
        y=(frame:GetBottom()+frame:GetHeight()/2)*frame:GetScale()
    end
    local scale=math.min(ADDON_BASE_SCALE*P.db.prefs.uiScale,(UIParent:GetWidth()-24)/frame:GetWidth(),(UIParent:GetHeight()-24)/frame:GetHeight())
    frame:SetScale(scale)
    if x and y then
        local halfWidth,halfHeight=frame:GetWidth()*scale/2,frame:GetHeight()*scale/2
        x=U.clamp(x,12+halfWidth,UIParent:GetWidth()-12-halfWidth)
        y=U.clamp(y,12+halfHeight,UIParent:GetHeight()-12-halfHeight)
        frame:ClearAllPoints();frame:SetPoint("CENTER",UIParent,"BOTTOMLEFT",x/scale,y/scale)
        P.db.prefs.position={x=x/scale-frame:GetWidth()/2,y=y/scale-frame:GetHeight()/2,scale=scale}
    end
    -- Settings stays steady under the cursor while dragging its slider, then
    -- takes the chosen scale on release. Other addon windows update immediately.
    if UI.settings and not UI.scaleDragging then UI.ScaleWindow(UI.settings) end
    if UI.dialogPool then UI.ScaleWindow(UI.dialogPool) end
    if UI.textDialogPool then UI.ScaleWindow(UI.textDialogPool) end
    if UI.menu then UI.menu:Hide() end
    UI.UpdateScaleSettings()
end
function UI.SetAddonScale(percent)
    if type(percent)~="number" or percent~=percent or math.abs(percent)==math.huge then return end
    P.db.prefs.uiScale=U.clamp(math.floor(percent+0.5),50,150)/100
    UI.ApplyScale(true)
end
function UI.Settings()
    if not UI.settings then
        local frame=UI.Panel(UIParent,360,265);UI.settings=frame;frame:SetPoint("CENTER",UIParent,"CENTER",0,60);frame:SetFrameStrata("DIALOG");frame:EnableMouse(true)
        local title=UI.Text(frame,"Octo Gear Planner Settings",16,true);title:SetPoint("TOPLEFT",frame,"TOPLEFT",18,-18)
        frame.hide=UI.Check(frame,"Hide items my character can never use",function(f)
            P.db.prefs.hideUnusable=f:GetChecked() and true or false;UI.Requery()
        end);frame.hide:SetPoint("TOPLEFT",frame,"TOPLEFT",18,-56);frame.hide.label:SetWidth(290);frame.hide.label:SetHeight(30)
        local note=UI.Text(frame,"Higher-level items and skills your class can learn remain visible.",11,false);note:SetPoint("TOPLEFT",frame,"TOPLEFT",22,-90);note:SetWidth(316)
        frame.scaleLabel=UI.Text(frame,"",11,true);frame.scaleLabel:SetPoint("TOPLEFT",frame,"TOPLEFT",22,-128)
        local slider=CreateFrame("Slider",UI.Name("AddonScale"),frame,"OptionsSliderTemplate");frame.scaleSlider=slider
        slider:SetWidth(304);slider:SetHeight(16);slider:SetPoint("TOPLEFT",frame,"TOPLEFT",28,-153)
        UI.scaleSync=true;slider:SetMinMaxValues(50,150);slider:SetValueStep(1);slider:SetValue(P.db.prefs.uiScale*100);UI.scaleSync=nil
        for _,spec in ipairs({{"Low","50%"},{"High","150%"}}) do local label=_G and _G[slider:GetName()..spec[1]];if label then label:SetText(spec[2]) end end
        local sliderText=_G and _G[slider:GetName().."Text"];if sliderText then sliderText:Hide() end
        K.Script(slider,"OnValueChanged",function(f,value) if not UI.scaleSync then UI.SetAddonScale(value or f:GetValue()) end end)
        K.Script(slider,"OnMouseDown",function() UI.scaleDragging=true end)
        K.Script(slider,"OnMouseUp",function() UI.scaleDragging=nil;UI.ScaleWindow(frame) end)
        K.Script(frame,"OnHide",function() UI.scaleDragging=nil end)
        local scaleNote=UI.Text(frame,"Automatically limited to fit your screen.",11,false);scaleNote:SetPoint("TOPLEFT",frame,"TOPLEFT",22,-190);scaleNote:SetWidth(316)
        frame.resetScale=UI.Button(frame,"Reset",80,25,function() UI.SetAddonScale(100) end);frame.resetScale:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",18,16)
        local close=UI.Button(frame,"Close",100,25,function() frame:Hide() end);close:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-18,16)
        if UISpecialFrames then table.insert(UISpecialFrames,frame:GetName()) end
    end
    UI.ScaleWindow(UI.settings);UI.UpdateScaleSettings();UI.settings.hide:SetChecked(P.db.prefs.hideUnusable);UI.settings:Show()
end
function UI.Refresh()
    if not UI.main then return end
    UI.setDropdown:SetText((P.working.name~="" and P.working.name or "Unsaved Set")..(P.Dirty() and " *" or ""))
    for slot,button in pairs(UI.slotButtons) do
        local entry=P.working.loadout[slot];local item=entry and OBP.Data.items[entry.item]
        UI.PaintItem(button,item,slot==P.db.prefs.slot,entry and "Interface\\Icons\\INV_Misc_QuestionMark" or "Interface\\PaperDoll\\UI-PaperDoll-Slot-"..OBP.Slots[slot].texture)
    end
    UI.UpdateStats();UI.UpdateModel();UI.RenderGrid();UI.RefreshFilterChecks()
    UI.RefreshTalents()
    UI.RenderEnchantments()
end
function UI.Create()
    UI.MeasurePanels()
    -- Keep panel geometry fixed and apply the saved scale to the whole window.
    local frame=UI.Panel(UIParent,FULL_WIDTH,HEIGHT,true);UI.main=frame
    UI.title=UI.Text(frame,"Octo Gear Planner",16,true);UI.title:SetPoint("TOP",frame,"TOP",0,2-OUTER_MARGIN);UI.title:SetJustifyH("CENTER")
    frame:SetFrameStrata("HIGH");frame:SetMovable(true);frame:EnableMouse(true);frame:RegisterForDrag("LeftButton");frame:SetClampedToScreen(true)
    UI.ApplyScale();frame:SetPoint("CENTER",UIParent,"CENTER",0,0)
    local pos=P.db.prefs.position
    if pos then
        local savedScale=pos.scale or math.min(1,(UIParent:GetWidth()-24)/FULL_WIDTH,(UIParent:GetHeight()-24)/HEIGHT)
        local ratio=savedScale/frame:GetScale();frame:ClearAllPoints();frame:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",pos.x*ratio,pos.y*ratio)
    end
    K.Script(frame,"OnDragStart",function(f) f:StartMoving() end)
    K.Script(frame,"OnDragStop",function(f) f:StopMovingOrSizing();P.db.prefs.position={x=f:GetLeft(),y=f:GetBottom(),scale=f:GetScale()} end)
    local close=UI.Button(frame,"X",25,24,UI.Close);UI.closeButton=close;close:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-OUTER_MARGIN,-OUTER_MARGIN)
    local settings=UI.Button(frame,"Settings",80,24,UI.Settings);UI.settingsButton=settings;settings:SetPoint("RIGHT",close,"LEFT",-7,0)
    UI.setDropdown=UI.Dropdown(frame,124,"Unsaved Set",UI.SetOptions)
    local save=UI.Button(frame,"Save",48,24,function() UI.Save() end);save:SetPoint("LEFT",UI.setDropdown,"RIGHT",5,0)
    local import=UI.Button(frame,"Import",54,24,UI.Import);import:SetPoint("LEFT",save,"RIGHT",5,0)
    local export=UI.Button(frame,"Export",54,24,UI.Export);export:SetPoint("LEFT",import,"RIGHT",5,0)
    UI.setControls={UI.setDropdown,save,import,export}
    for _,control in ipairs(UI.setControls) do
        local text=control:GetFontString()
        local font,size,flags
        if text.GetFont then font,size,flags=text:GetFont() end
        text:SetFont(font or "Fonts\\FRIZQT__.TTF",(size or 12)*0.85,flags or "")
    end
    local controlsWidth=UI.setDropdown:GetWidth()+save:GetWidth()+import:GetWidth()+export:GetWidth()+15
    UI.setDropdown:SetPoint("TOPLEFT",frame,"TOPLEFT",OUTER_MARGIN+(LEFT-controlsWidth)/2,-TOOLBAR_TOP)
    UI.setLabel=UI.Text(frame,"Builds",10,true);UI.setLabel:SetPoint("BOTTOMLEFT",UI.setDropdown,"TOPLEFT",6,4)
    UI.BuildPaperDoll();UI.BuildTalentPanel();UI.BuildBrowser();UI.BuildSidePanels()
    if UISpecialFrames then table.insert(UISpecialFrames,frame:GetName()) end
    K.Script(frame,"OnHide",function()
        UI.rotation=nil
        if UI.menu then UI.menu:Hide() end
        UI.LeaveTooltip()
        if not UI.allowClose and P.Dirty() then frame:Show();UI.Close() end
    end)
    K.Script(frame,"OnUpdate",function(_,elapsed)
        UI.UpdateRotation(elapsed)
        if UI.modelDelay then
            UI.modelDelay=UI.modelDelay-(elapsed or 0)
            if UI.modelDelay<=0 then UI.modelDelay=nil;UI.UpdateModel() end
        end
        if UI.searchDelay then
            UI.searchDelay=UI.searchDelay-(elapsed or 0)
            if UI.searchDelay<=0 then UI.searchDelay=nil;UI.Requery() end
        end
    end)
    UI.allowClose=true;frame:Hide();UI.allowClose=false
    UI.Requery();UI.Refresh()
    -- The native function otherwise hides every special frame in one Escape press.
    local closeSpecial=CloseSpecialWindows
    CloseSpecialWindows=function()
        if UI.dialog and UI.dialog:IsShown() then UI.dialog:Hide();return 1 end
        if UI.menu and UI.menu:IsShown() then UI.menu:Hide();return 1 end
        if UI.settings and UI.settings:IsShown() then UI.settings:Hide();return 1 end
        if UI.main:IsShown() then
            UI.Close()
            return 1
        end
        if closeSpecial then return closeSpecial() end
    end
end
function UI.Toggle()
    if UI.main:IsShown() then UI.Close() else UI.main:Show();UI.Requery();UI.Refresh() end
end
