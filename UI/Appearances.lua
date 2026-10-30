local U,K,C,L,P=OBP.Util,OBP.Compat,OBP.Catalogue,OBP.Loadout,OBP.Persistence
local UI=OBP.UI
local visualOrder={4,19,5,7,8,9,10,6,3,15,1,16,17,18}
local visualSlots={};for _,slot in ipairs(visualOrder) do visualSlots[slot]=true end
local MODEL_TOP=40
local MODEL_DOWN=8
local MODEL_ZOOM=1.3

local function layoutModel(card)
    local bottom=card.note:GetText()~="" and 22 or 8
    card.model:SetHeight(card:GetHeight()-MODEL_TOP-bottom)
    UI.CharacterBackdrop(card,card.model,8,MODEL_TOP+MODEL_DOWN)
end

local function previewPlan(card)
    local slot=card.slot
    local signature={tostring(slot),tostring(card.itemID),tostring(P.db.prefs.appearanceGear)}
    local links,missing={},{}
    local candidate=OBP.Data.items[card.itemID]
    local main=L.Item(P.working.loadout[16])
    local function add(entry)
        if not entry then return end
        local link=K.Link(entry)
        local cached=K.Cached(entry)
        table.insert(signature,link..":"..tostring(cached))
        if cached then table.insert(links,link)
        else missing[entry.item]=true;K.Request(entry.item) end
    end
    for _,other in ipairs(visualOrder) do
        local conflict=other==17 and slot==16 and candidate.inventoryType==17
            or other==16 and slot==17 and main and main.inventoryType==17
        if P.db.prefs.appearanceGear and other~=slot and not conflict then add(P.working.loadout[other]) end
        if other==slot then add({item=card.itemID}) end
    end
    return table.concat(signature,";"),links,missing
end

local function updatePreview(card)
    local key,links,missing=previewPlan(card)
    card.missing=missing
    if card.signature==key then return end
    local okay=pcall(function()
        if not card.initialized then
            card.model:SetUnit("player")
            card.initialized=true
        end
        card.model:Undress()
        for _,link in ipairs(links) do card.model:TryOn(link) end
        card.model:SetFacing(card.slot==15 and math.pi or 0)
        UI.ZoomModel(card.model,MODEL_ZOOM)
    end)
    if okay then
        card.signature=key
        card.note:SetText(not visualSlots[card.slot] and "No visible appearance" or next(missing) and "Loading appearance..." or "")
    else
        card.signature=nil;card.initialized=nil
        card.note:SetText("Preview unavailable")
    end
    layoutModel(card)
end

function UI.RefreshAppearanceOptions()
    UI.appearanceAllGear:SetChecked(P.db.prefs.appearanceGear)
end

function UI.SetAppearanceGear(planned)
    P.db.prefs.appearanceGear=planned and true or false
    UI.RefreshAppearanceOptions();UI.RenderAppearances()
end

function UI.BuildAppearances()
    UI.appearanceControls=CreateFrame("Frame",UI.Name("AppearanceOptions"),UI.main)
    UI.appearanceControls:SetHeight(24)
    UI.appearanceAllGear=UI.Check(UI.appearanceControls,"Show All Gear",function(f) UI.SetAppearanceGear(f:GetChecked()) end)
    UI.appearanceAllGear:SetPoint("LEFT",UI.appearanceControls,"LEFT",0,0)
    UI.Hint(UI.appearanceAllGear,"Checked: show your planned gear with each candidate item replacing its slot. Unchecked: show only the candidate item.")
    UI.appearanceCards={}
    for index=1,6 do
        local card=UI.Panel(UI.grid,170,180)
        UI.CharacterBackdrop(card)
        card.model=CreateFrame("DressUpModel",UI.Name("AppearanceModel"),card)
        card.model.appearancePreview=true;card.model:EnableMouse(false)
        card.model:SetPoint("TOPLEFT",card,"TOPLEFT",8,-MODEL_TOP-MODEL_DOWN)
        card.hit=CreateFrame("Button",UI.Name("AppearanceItem"),card)
        card.hit:SetAllPoints(card);card.hit:SetFrameLevel(card.model:GetFrameLevel()+1)
        card.icon=UI.Icon(card.hit,30);card.icon:SetPoint("TOPLEFT",card,"TOPLEFT",10,-8)
        card.name=UI.Text(card.hit,"",10,false);card.name:SetPoint("TOPLEFT",card.icon,"TOPRIGHT",8,0);card.name:SetHeight(30);card.name:SetJustifyV("TOP")
        card.note=UI.Text(card.hit,"",10,false);card.note:SetPoint("BOTTOM",card,"BOTTOM",0,7);card.note:SetHeight(13);card.note:SetJustifyH("CENTER")
        for _,button in ipairs({card.hit,card.icon}) do
            button:RegisterForClicks("LeftButtonUp","RightButtonUp")
            button:EnableMouseWheel(true)
            K.Script(button,"OnClick",function(_,mouse)
                if not card.itemID then return end
                if mouse=="RightButton" then
                    local item=OBP.Data.items[card.itemID]
                    UI.TextDialog(item.name.." — Sources",table.concat(UI.SourceLines(item),"\n"),"Sources")
                else UI.Assign(card.slot,card.itemID) end
            end)
            K.Script(button,"OnEnter",function(f) if card.itemID then card.icon:LockHighlight();UI.ItemTooltip(f,card.itemID) end end)
            K.Script(button,"OnLeave",function() card.icon:UnlockHighlight();UI.LeaveTooltip() end)
            K.Script(button,"OnMouseWheel",function(_,delta) UI.gridBar:SetValue(U.clamp(UI.scrollRow-(delta or 0)*2,0,UI.maxScroll or 0)) end)
        end
        K.Script(card.model,"OnShow",function() card.signature=nil;card.initialized=nil end)
        UI.appearanceCards[index]=card;card:Hide()
    end
    UI.appearanceControls:Hide();UI.RefreshAppearanceOptions()
end

function UI.LayoutAppearances(width,height)
    UI.appearanceControls:SetWidth(UI.appearanceAllGear:GetWidth()+2+UI.appearanceAllGear.label:GetStringWidth())
    UI.appearanceControls:ClearAllPoints();UI.appearanceControls:SetPoint("RIGHT",UI.viewButton,"LEFT",-8,0)
    local cardWidth=(width-51-16)/3
    local cardHeight=(height-24)/2
    for index,card in ipairs(UI.appearanceCards) do
        card:SetWidth(cardWidth);card:SetHeight(cardHeight)
        card:ClearAllPoints();card:SetPoint("TOPLEFT",UI.grid,"TOPLEFT",8+U.mod(index-1,3)*(cardWidth+8),-8-math.floor((index-1)/3)*(cardHeight+8))
        card.hit:SetAllPoints(card)
        card.name:SetWidth(cardWidth-58);card.note:SetWidth(cardWidth-16)
        card.model:SetWidth(cardWidth-16)
        UI.CharacterBackdrop(card);layoutModel(card)
    end
end

function UI.RenderAppearances()
    if not UI.appearanceCards then return end
    local appearance=P.db.prefs.browserView=="Appearance"
    if appearance then UI.appearanceControls:Show() else UI.appearanceControls:Hide();UI.appearanceDelay=nil end
    local selected=P.working.loadout[P.db.prefs.slot]
    for index,card in ipairs(UI.appearanceCards) do
        local id=appearance and UI.results and UI.results[index+UI.scrollRow*3]
        card.itemID=id;card.slot=P.db.prefs.slot
        if id then
            local item=OBP.Data.items[id]
            UI.PaintItem(card.icon,item,selected and selected.item==id)
            card.name:SetText(item.name);card.name:SetTextColor(UI.Color(item))
            if selected and selected.item==id then card:SetBackdropBorderColor(1,0.8,0.15,1)
            else card:SetBackdropBorderColor(0.55,0.52,0.45,1) end
            card:Show();updatePreview(card)
        else card:Hide();card.missing={} end
    end
end

function UI.AppearanceCache(id)
    for _,card in ipairs(UI.appearanceCards or {}) do
        if card.itemID and card.missing and (id and card.missing[id] or not id and next(card.missing)) then
            UI.appearanceDelay=0.1;return
        end
    end
end

function UI.UpdateAppearancePreviews(elapsed)
    if not UI.appearanceDelay or P.db.prefs.browserView~="Appearance" then return end
    UI.appearanceDelay=UI.appearanceDelay-(elapsed or 0)
    if UI.appearanceDelay<=0 then UI.appearanceDelay=nil;UI.RenderAppearances() end
end
