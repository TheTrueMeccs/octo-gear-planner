local U,K=OBP.Util,OBP.Compat
OBP.UI={serial=0}
local UI=OBP.UI
function UI.Name(prefix) UI.serial=UI.serial+1;return "OBP"..prefix..UI.serial end
function UI.ScaleWindow(frame)
    if UI.main then frame:SetScale(UI.main:GetScale()) end
    frame:SetClampedToScreen(true)
end
function UI.Panel(parent,width,height,transparent)
    local f=CreateFrame("Frame",UI.Name("Panel"),parent)
    f:SetWidth(width);f:SetHeight(height)
    -- Keep dialogs dark and opaque; the main back layer uses native transparency.
    f:SetBackdrop({bgFile=transparent and "Interface\\DialogFrame\\UI-DialogBox-Background" or "Interface\\Buttons\\WHITE8x8",edgeFile=transparent and "Interface\\DialogFrame\\UI-DialogBox-Border" or "Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=transparent and 32 or 8,edgeSize=transparent and 32 or 16,insets={left=transparent and 5 or 4,right=transparent and 5 or 4,top=transparent and 5 or 4,bottom=transparent and 5 or 4}})
    f:SetBackdropColor(0.035,0.035,0.035,1);f:SetBackdropBorderColor(0.55,0.52,0.45,1)
    if transparent then
        -- Match AtlasCFM's native quest-frame edge and gold tint. A half-opaque
        -- dark layer halves the transparency remaining in the native texture.
        f:SetBackdropBorderColor(0.80,0.60,0.25,1)
        f.backgroundShade=f:CreateTexture(nil,"BACKGROUND");f.backgroundShade:SetTexture("Interface\\Buttons\\WHITE8x8");f.backgroundShade:SetVertexColor(0.035,0.035,0.035,0.5)
        f.backgroundShade:SetPoint("TOPLEFT",f,"TOPLEFT",5,-5);f.backgroundShade:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-5,5)
    end
    return f
end
function UI.Text(parent,text,size,gold)
    local f=parent:CreateFontString(nil,"OVERLAY",gold and "GameFontNormal" or "GameFontHighlight")
    f:SetFont("Fonts\\FRIZQT__.TTF",size or 12)
    f:SetJustifyH("LEFT");f:SetText(text or "")
    return f
end
function UI.Button(parent,label,width,height,callback)
    local f=CreateFrame("Button",UI.Name("Button"),parent,"UIPanelButtonTemplate")
    f:SetWidth(width or 80);f:SetHeight(height or 24);f:SetText(label)
    if callback then K.Script(f,"OnClick",callback) end
    return f
end
function UI.Input(parent,width,text)
    local f=CreateFrame("EditBox",UI.Name("Input"),parent,"InputBoxTemplate")
    f:SetWidth(width);f:SetHeight(24);f:SetAutoFocus(false);f:SetText(text or "")
    return f
end
function UI.Check(parent,label,callback)
    local f=CreateFrame("CheckButton",UI.Name("Check"),parent,"UICheckButtonTemplate")
    f:SetWidth(24);f:SetHeight(24)
    f.label=UI.Text(f,label,11,false);f.label:SetPoint("LEFT",f,"RIGHT",2,0)
    if callback then K.Script(f,"OnClick",callback) end
    return f
end
function UI.Scrollbar(parent,height,callback)
    local f=CreateFrame("Slider",UI.Name("Scroll"),parent,"UIPanelScrollBarTemplate")
    -- Replace the template's parent:SetVerticalScroll handler before SetValue or
    -- SetMinMaxValues can run it. Our parent can be an ordinary panel.
    local ready=false
    K.Script(f,"OnValueChanged",function(frame,n) if ready then callback(math.floor((n or frame:GetValue())+0.5)) end end)
    f:SetWidth(16);f:SetHeight(height);f:SetMinMaxValues(0,0);f:SetValueStep(1);f:SetValue(0)
    -- Native talent-panel track: preserve the arrow cradles and stretch only
    -- the straight middle rails. Include the template's external arrow buttons.
    local fill=f:CreateTexture(nil,"BACKGROUND");f.trackFill=fill
    fill:SetTexture("Interface\\Buttons\\WHITE8x8");fill:SetVertexColor(0,0,0,1)
    fill:SetWidth(25);fill:SetHeight(height+37);fill:SetPoint("TOPLEFT",f,"TOPLEFT",-5,20)
    f.trackArt={}
    for _,part in ipairs({
        {0,24,0,31/64,0,24/256},
        {24,height-9,0,31/64,24/256,232/256},
        {height+15,24,33/64,1,82/256,106/256}
    }) do
        local texture=f:CreateTexture(nil,"BORDER");texture:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-ScrollBar")
        texture:SetWidth(31);texture:SetHeight(part[2]);texture:SetPoint("TOPLEFT",f,"TOPLEFT",-8,21-part[1]);texture:SetTexCoord(part[3],part[4],part[5],part[6])
        table.insert(f.trackArt,texture)
    end
    ready=true
    return f
end
function UI.Hint(frame,text)
    K.Script(frame,"OnEnter",function(f)
        GameTooltip:SetOwner(f,"ANCHOR_RIGHT");GameTooltip:SetText(text,1,0.82,0,true)
    end)
    K.Script(frame,"OnLeave",function() GameTooltip:Hide() end)
end
function UI.Color(item)
    if GetItemQualityColor then local r,g,b=GetItemQualityColor(item and item.quality or 1);return r,g,b end
    return 1,1,1
end
function UI.Icon(parent,size)
    local f=CreateFrame("Button",UI.Name("Item"),parent)
    f:SetWidth(size);f:SetHeight(size);f:RegisterForClicks("LeftButtonUp","RightButtonUp")
    f.icon=f:CreateTexture(nil,"ARTWORK");f.icon:SetAllPoints(f)
    -- Classic item-button artwork uses a padded 64px texture for a 36px icon.
    -- Keep that ratio so its visible bevel/glow lands on the icon's edge.
    local artSize=size*64/36
    f.frameTexture=f:CreateTexture(nil,"OVERLAY");f.frameTexture:SetTexture("Interface\\Buttons\\UI-Quickslot2");f.frameTexture:SetWidth(artSize);f.frameTexture:SetHeight(artSize);f.frameTexture:SetPoint("CENTER",f,"CENTER",0,0)
    -- A thicker native rounded edge makes quality visible against busy icons.
    f.rarity=CreateFrame("Frame",UI.Name("QualityBorder"),f);f.rarity:SetFrameLevel(f:GetFrameLevel()+1)
    f.rarity:SetWidth(size+2);f.rarity:SetHeight(size+2);f.rarity:SetPoint("CENTER",f,"CENTER",0,0)
    f.rarity:SetBackdrop({edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=16,insets={left=0,right=0,top=0,bottom=0}})
    f:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    -- ActionButton-Border has substantial transparent padding. A square check
    -- highlight fills exactly the same rectangle as the slot and hover texture.
    f.selection=f:CreateTexture(nil,"OVERLAY");f.selection:SetAllPoints(f);f.selection:SetTexture("Interface\\Buttons\\CheckButtonHilight");f.selection:SetBlendMode("ADD");f.selection:SetVertexColor(1,0.8,0.15,1);f.selection:Hide()
    return f
end
function UI.PaintItem(button,item,selected,emptyTexture)
    local texture=item and item.icon or emptyTexture or "Interface\\Icons\\INV_Misc_QuestionMark"
    if not string.find(texture,"\\",1,true) then texture="Interface\\Icons\\"..texture end
    button.icon:SetTexture(texture)
    button.icon:SetTexCoord(0,1,0,1)
    if item then
        local r,g,b=UI.Color(item)
        button.rarity:SetBackdropBorderColor(math.min(1,r*1.25),math.min(1,g*1.25),math.min(1,b*1.25),1)
        button.rarity:Show()
    else button.rarity:Hide() end
    if selected then button.selection:Show() else button.selection:Hide() end
end
function UI.Dropdown(parent,width,label,provider,compact,searchable)
    local button
    if compact then
        -- Same native label-frame artwork used by BetterCharacterStats' dropdowns.
        button=CreateFrame("Button",UI.Name("StatDropdown"),parent);button:SetWidth(width);button:SetHeight(24)
        button.statLabel=UI.Text(button,label,9,false);button:SetFontString(button.statLabel)
        button.chrome={}
        for _,part in ipairs({{0,9,16/128,25/128},{9,width-18,25/128,103/128},{width-9,9,103/128,112/128}}) do
            local texture=button:CreateTexture(nil,"BACKGROUND");texture:SetTexture("Interface\\Glues\\CharacterCreate\\CharacterCreate-LabelFrame")
            texture:SetWidth(part[2]);texture:SetHeight(24);texture:SetPoint("TOPLEFT",button,"TOPLEFT",part[1],0);texture:SetTexCoord(part[3],part[4],19/64,45/64);table.insert(button.chrome,texture)
        end
        button:EnableMouse(false)
    else button=UI.Button(parent,label,width,24) end
    button.provider=provider;button.searchable=searchable
    if compact then
        local arrow=CreateFrame("Button",UI.Name("StatArrow"),button);button.arrowButton=arrow
        arrow:SetWidth(24);arrow:SetHeight(24);arrow:SetPoint("RIGHT",button,"RIGHT",-1,0);arrow:EnableMouse(true);arrow:RegisterForClicks("LeftButtonUp")
        arrow:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up");arrow:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down");arrow:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
        button.arrow=arrow:GetNormalTexture();button.arrow:SetAllPoints(arrow)
        K.Script(arrow,"OnClick",function() UI.StatMenu(button,button.provider()) end)
    else
        button.arrow=button:CreateTexture(nil,"OVERLAY");button.arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up");button.arrow:SetWidth(16);button.arrow:SetHeight(16);button.arrow:SetPoint("RIGHT",button,"RIGHT",-6,0)
        K.Script(button,"OnClick",function(f) UI.Menu(f,f.provider(),f.searchable) end)
    end
    local text=button:GetFontString()
    text:ClearAllPoints();text:SetPoint("LEFT",button,"LEFT",compact and 8 or 9,0);text:SetPoint("RIGHT",button.arrow,"LEFT",-2,0);text:SetJustifyH("LEFT")
    text:SetHeight(compact and 18 or 16);text:SetJustifyV("MIDDLE")
    if compact then
        text:ClearAllPoints();text:SetPoint("LEFT",button,"LEFT",11,1);text:SetPoint("RIGHT",button.arrow,"LEFT",-4,1);text:SetFont("Fonts\\FRIZQT__.TTF",9)
    end
    return button
end
function UI.SetActive(button,active)
    button.active=active
    if active then button:LockHighlight() else button:UnlockHighlight() end
end
function UI.ZoomModel(model,zoom)
    if not model.SetCamDistanceScale then return false end
    UI.modelCameras=UI.modelCameras or {}
    local camera=UI.modelCameras[model] or {}
    UI.modelCameras[model]=camera
    local scale,width,height=model:GetEffectiveScale(),model:GetWidth(),model:GetHeight()
    local resized=camera.scale~=scale or camera.width~=width or camera.height~=height
    camera.zoom=zoom
    -- PlayerModel configures its camera when the mesh finishes loading.
    -- ClassicAPI retains this distance setting through that configuration.
    if model.SetPortraitZoom then model:SetPortraitZoom(0) end
    model:SetCamDistanceScale(1/zoom)
    -- The native camera is a frozen copy of the scaled model's camera.
    -- Resizing changes the model transform but leaves that copy stale.
    -- Rebuild it at the new scale; changing the zoom as well scales twice.
    if resized and model.RefreshCamera then model:RefreshCamera() end
    camera.scale,camera.width,camera.height=scale,width,height
    return true
end
function UI.RefreshModelCameras()
    for model,camera in pairs(UI.modelCameras or {}) do UI.ZoomModel(model,camera.zoom) end
end
function UI.CharacterBackdrop(frame,owner,x,y)
    -- One opaque interior sample avoids the transparent/baked edges in the
    -- other character-frame quadrants. BORDER keeps it above the dark backdrop.
    local inset=8
    local width,height=frame:GetWidth()-2*inset,frame:GetHeight()-2*inset
    owner=owner or frame;x=x or 0;y=y or 0
    local existing=owner.characterArt and owner.characterArt[1]
    owner.characterArt={}
    local l,t=math.max(inset,x),math.max(inset,y)
    local r,b=math.min(inset+width,x+owner:GetWidth()),math.min(inset+height,y+owner:GetHeight())
    if r>l and b>t then
        local texture=existing or owner:CreateTexture(nil,(owner==UI.model or owner.appearancePreview) and "BACKGROUND" or "BORDER")
        texture:ClearAllPoints();texture:Show()
        texture:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-TopLeft")
        texture:SetWidth(r-l);texture:SetHeight(b-t);texture:SetPoint("TOPLEFT",owner,"TOPLEFT",l-x,y-t)
        texture:SetTexCoord(22/256+(234/256)*(l-inset)/width,22/256+(234/256)*(r-inset)/width,80/256+(176/256)*(t-inset)/height,80/256+(176/256)*(b-inset)/height)
        table.insert(owner.characterArt,texture)
    elseif existing then existing:Hide() end
end
function UI.StatPanel(parent,width,height)
    local frame=CreateFrame("Frame",UI.Name("StatPanel"),parent);frame:SetWidth(width);frame:SetHeight(height)
    for _,part in ipairs({{0,16,0,0.125},{16,height-32,0.125,0.1953125},{height-16,16,0.484375,0.609375}}) do
        local texture=frame:CreateTexture(nil,"BACKGROUND");texture:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-StatBackground")
        texture:SetWidth(width);texture:SetHeight(part[2]);texture:SetPoint("TOPLEFT",frame,"TOPLEFT",0,-part[1]);texture:SetTexCoord(0,0.8984375,part[3],part[4])
    end
    return frame
end
function UI.StatMenu(anchor,options)
    if UI.menu and UI.menu.anchor==anchor and UI.menu:IsShown() then UI.menu:Hide();return end
    if UI.menu then UI.menu:Hide() end
    local menu=UI.statMenuPool
    if not menu then
        menu=CreateFrame("Frame",UI.Name("StatMenu"),UIParent);UI.statMenuPool=menu;menu.rows={}
        -- Native dropdown-list artwork and plain checked entries, as used by
        -- BetterCharacterStats, rather than the planner's red action buttons.
        menu:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=32,insets={left=11,right=12,top=12,bottom=11}})
        menu:SetBackdropColor(0,0,0,1);menu:SetFrameStrata("FULLSCREEN_DIALOG");menu:SetClampedToScreen(true);menu:EnableMouse(true)
        K.Script(menu,"OnHide",function(f)
            GameTooltip:Hide()
            if f.anchor and f.anchor.arrow then f.anchor.arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up") end
            if UISpecialFrames then for i=table.getn(UISpecialFrames),1,-1 do if UISpecialFrames[i]==f:GetName() then table.remove(UISpecialFrames,i) end end end
            if UI.menu==f then UI.menu=nil end
        end)
    end
    UI.menu=menu;menu.anchor=anchor
    menu:SetScale(anchor:GetEffectiveScale()/UIParent:GetEffectiveScale())
    menu:SetWidth(152);menu:SetHeight(24+table.getn(options)*18);menu:ClearAllPoints();menu:SetPoint("TOPLEFT",anchor,"BOTTOMLEFT",0,0)
    for i,row in ipairs(menu.rows) do row:Hide() end
    for i,option in ipairs(options) do
        local row=menu.rows[i]
        if not row then
            row=CreateFrame("Button",UI.Name("StatChoice"),menu);menu.rows[i]=row;row:SetWidth(132);row:SetHeight(18)
            row.label=UI.Text(row,"",12,false);row.label:SetPoint("LEFT",row,"LEFT",24,0);row.label:SetPoint("RIGHT",row,"RIGHT",-4,0);row.label:SetHeight(16)
            row.check=row:CreateTexture(nil,"ARTWORK");row.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check");row.check:SetWidth(24);row.check:SetHeight(24);row.check:SetPoint("LEFT",row,"LEFT",0,0)
            row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            K.Script(row,"OnClick",function(f) local action=f.option and f.option.action;menu:Hide();if action then action() end end)
        end
        row.option=option;row.label:SetText(option.text);row:ClearAllPoints();row:SetPoint("TOPLEFT",menu,"TOPLEFT",10,-12-(i-1)*18)
        if option.checked then row.check:Show() else row.check:Hide() end
        row:Show()
    end
    anchor.arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
    if UISpecialFrames then table.insert(UISpecialFrames,menu:GetName()) end
    menu:Show()
end
function UI.Menu(anchor,options,searchable)
    if UI.menu and UI.menu.anchor==anchor and UI.menu:IsShown() then UI.menu:Hide();return end
    if UI.menu then UI.menu:Hide() end
    local menu=UI.menuPool or UI.Panel(UIParent,200,30)
    UI.menuPool=menu;UI.menu=menu;menu.anchor=anchor;menu.searchable=searchable
    local width=math.max(200,anchor:GetWidth()+30)
    if searchable then
        if not menu.measure then menu.measure=menu:CreateFontString(nil,"OVERLAY","GameFontNormal");menu.measure:Hide() end
        local longest=0
        for _,option in ipairs(options) do menu.measure:SetText(option.text);longest=math.max(longest,menu.measure:GetStringWidth()) end
        width=math.min(UIParent:GetWidth()-24,math.max(150,math.ceil(longest)+32))
    end
    menu:SetWidth(width);menu:ClearAllPoints();menu:SetFrameStrata("FULLSCREEN_DIALOG");menu:SetPoint("TOPLEFT",anchor,"BOTTOMLEFT",0,-2);menu:EnableMouse(true);menu:EnableMouseWheel(true)
    menu.options,menu.offset,menu.rows=options,0,menu.rows or {}
    if not menu.search then
        menu.searchLabel=UI.Text(menu,"Search",11,true);menu.searchLabel:SetPoint("TOPLEFT",menu,"TOPLEFT",10,-15)
        menu.search=UI.Input(menu,190,"");menu.search:SetPoint("TOPLEFT",menu,"TOPLEFT",65,-8);menu.search:SetMaxLetters(80)
        menu.empty=UI.Text(menu,"No matching instances.",11,false);menu.empty:SetPoint("TOPLEFT",menu,"TOPLEFT",10,-48)
        K.Script(menu.search,"OnTextChanged",function() if menu.filter then menu.filter() end end)
        K.Script(menu.search,"OnEscapePressed",function() menu:Hide() end)
    end
    menu.search:SetWidth(menu:GetWidth()-80)
    if searchable then menu.search:Show();menu.searchLabel:Show() else menu.search:Hide();menu.searchLabel:Hide();menu.search:ClearFocus() end
    local top=searchable and 43 or 6
    local function render()
        menu.count=math.min(12,table.getn(menu.filtered));menu:SetHeight(top+math.max(1,menu.count)*23+6)
        for i,row in ipairs(menu.rows) do
            local option=menu.filtered[i+menu.offset];row.option=option
            row:ClearAllPoints();row:SetPoint("TOPLEFT",menu,"TOPLEFT",7,-top-(i-1)*23)
            if option then
                row:SetText(option.text);row:Show()
                row:SetWidth(menu:GetWidth()-14-(option.remove and 26 or 0))
                row.remove.option=option
                if option.remove then row.remove:Show() else row.remove:Hide() end
            else row:Hide();row.remove:Hide() end
        end
        if table.getn(menu.filtered)==0 then menu.empty:Show() else menu.empty:Hide() end
    end
    for i=1,12 do
        local row=menu.rows[i]
        if not row then
        row=UI.Button(menu,"",menu:GetWidth()-14,22,function(f)
            local option=f.option;menu:Hide();if option and option.action then option.action() end
        end)
        row.remove=UI.Button(menu,"X",20,20,function(f)
            local option=f.option;menu:Hide();if option and option.remove then option.remove() end
        end)
        row.remove:SetPoint("LEFT",row,"RIGHT",4,0)
        menu.rows[i]=row
        end
        row:SetWidth(menu:GetWidth()-14)
    end
    menu.filter=function()
        local query=searchable and string.lower(U.trim(menu.search:GetText())) or ""
        menu.filtered={};menu.offset=0
        for _,option in ipairs(menu.options) do
            if query=="" or option.always or string.find(string.lower(option.text),query,1,true) then table.insert(menu.filtered,option) end
        end
        render()
    end
    K.Script(menu,"OnMouseWheel",function(_,delta) menu.offset=U.clamp(menu.offset-(delta or 0),0,math.max(0,table.getn(menu.filtered)-menu.count));render() end)
    if UISpecialFrames then table.insert(UISpecialFrames,menu:GetName()) end
    K.Script(menu,"OnHide",function(f)
        f.search:ClearFocus()
        if UISpecialFrames then for i=table.getn(UISpecialFrames),1,-1 do if UISpecialFrames[i]==f:GetName() then table.remove(UISpecialFrames,i) end end end
        if UI.menu==f then UI.menu=nil end
    end)
    menu.search:SetText("");menu.filter();menu:Show();if searchable then menu.search:SetFocus() end
end
function UI.DismissDialog()
    if UI.dialog then UI.dialog.resolved=true;UI.dialog:Hide();UI.dialog=nil end
end
function UI.Dialog(title,message,choices,input)
    UI.DismissDialog()
    if UI.menu then UI.menu:Hide() end
    local dialog=UI.dialogPool or UI.Panel(UIParent,360,205)
    UI.ScaleWindow(dialog)
    UI.dialogPool=dialog;dialog.resolved=false;dialog.inputOptions=input;dialog.talentLevelProposal=nil
    local hasInput=input and not input.hidden
    dialog:SetHeight(hasInput and 232 or 205)
    UI.dialog=dialog;dialog:SetFrameStrata("FULLSCREEN_DIALOG");dialog:SetPoint("CENTER",UIParent,"CENTER",0,30);dialog:EnableMouse(true)
    if not dialog.title then
        dialog.title=UI.Text(dialog,"",16,true);dialog.title:SetPoint("TOPLEFT",dialog,"TOPLEFT",18,-18);dialog.title:SetWidth(324);dialog.title:SetHeight(22)
        dialog.message=UI.Text(dialog,"",12,false);dialog.message:SetPoint("TOPLEFT",dialog,"TOPLEFT",18,-52);dialog.message:SetWidth(324);dialog.message:SetHeight(90);dialog.message:SetJustifyV("TOP")
        dialog.input=UI.Input(dialog,310,"");dialog.input:SetPoint("TOPLEFT",dialog,"TOPLEFT",25,-142);dialog.input:SetMaxLetters(64)
        dialog.buttons={}
    end
    dialog.title:SetText(title);dialog.message:SetText(message)
    if hasInput then dialog.input:SetText(input.default or "");dialog.input:Show() else dialog.input:Hide();dialog.input:ClearFocus() end
    local count=table.getn(choices)
    local width=math.min(100,(320-(count-1)*8)/count)
    local left=(dialog:GetWidth()-count*width-(count-1)*8)/2
    for _,button in ipairs(dialog.buttons) do button:Hide() end
    for i,choice in ipairs(choices) do
        local button=dialog.buttons[i] or UI.Button(dialog,"",width,25,function(f)
            local d=f:GetParent();local action=f.choice.action;local text=d.input and d.input:GetText()
            UI.DismissDialog();if action then action(text) end
        end)
        dialog.buttons[i]=button;button:SetWidth(width);button:SetText(choice.text);button:ClearAllPoints();button.choice=choice;button:SetPoint("BOTTOMLEFT",dialog,"BOTTOMLEFT",left+(i-1)*(width+8),17);button:Show()
    end
    if UISpecialFrames then table.insert(UISpecialFrames,dialog:GetName()) end
    K.Script(dialog,"OnHide",function(f)
        if UISpecialFrames then for i=table.getn(UISpecialFrames),1,-1 do if UISpecialFrames[i]==f:GetName() then table.remove(UISpecialFrames,i) end end end
        if not f.resolved and input and input.cancel then input.cancel() end
        if UI.dialog==f then UI.dialog=nil end
    end)
    dialog:Show();if hasInput then dialog.input:SetFocus() end
    return dialog
end
function UI.Error(message)
    UI.Dialog("Octo Gear Planner",message,{{text="OK"}})
end
function UI.TextDialog(title,text,mode,callback)
    UI.DismissDialog()
    local dialog=UI.textDialogPool or UI.Panel(UIParent,480,370)
    UI.ScaleWindow(dialog)
    UI.textDialogPool=dialog
    UI.dialog=dialog;dialog:SetFrameStrata("FULLSCREEN_DIALOG");dialog:SetPoint("CENTER",UIParent,"CENTER",0,15);dialog:EnableMouse(true)
    if not dialog.edit then
    local label=UI.Text(dialog,"",16,true);dialog.title=label;label:SetPoint("TOPLEFT",dialog,"TOPLEFT",18,-18);label:SetWidth(444);label:SetHeight(22)
    local hint=UI.Text(dialog,"",11,false);dialog.hint=hint
    hint:SetPoint("TOPLEFT",dialog,"TOPLEFT",18,-47);hint:SetWidth(444)
    local scroll=CreateFrame("ScrollFrame",UI.Name("TextScroll"),dialog)
    scroll:SetPoint("TOPLEFT",dialog,"TOPLEFT",22,-75);scroll:SetWidth(410);scroll:SetHeight(225)
    local edit=CreateFrame("EditBox",UI.Name("TextBox"),scroll)
    dialog.edit=edit;dialog.scroll=scroll
    edit:SetMultiLine(true);edit:SetWidth(404);edit:SetHeight(225);edit:SetAutoFocus(false);edit:SetFontObject(GameFontHighlightSmall);scroll:SetScrollChild(edit)
    local bar=UI.Scrollbar(dialog,195,function(n) scroll:SetVerticalScroll(n) end)
    bar:SetPoint("TOPRIGHT",dialog,"TOPRIGHT",-25,-90)
    K.Script(edit,"OnTextChanged",function(f)
        local extent=math.max(0,f:GetHeight()-scroll:GetHeight());bar:SetMinMaxValues(0,extent)
    end)
    K.Script(edit,"OnEscapePressed",function() UI.DismissDialog() end)
    scroll:EnableMouseWheel(true);K.Script(scroll,"OnMouseWheel",function(_,delta) bar:SetValue(U.clamp(bar:GetValue()-(delta or 0)*30,0,math.max(0,edit:GetHeight()-225))) end)
    local close=UI.Button(dialog,"Close",110,26,function() UI.DismissDialog() end);close:SetPoint("BOTTOMRIGHT",dialog,"BOTTOMRIGHT",-20,20)
    dialog.accept=UI.Button(dialog,"Import",110,26,function() local candidate=edit:GetText();local action=dialog.callback;UI.DismissDialog();if action then action(candidate) end end)
    dialog.accept:SetPoint("RIGHT",close,"LEFT",-10,0)
    end
    dialog.callback=callback;dialog.title:SetText(title)
    dialog.hint:SetText(mode=="Import" and "Paste a complete export string, then choose Import." or "Click the text and press Ctrl+C to copy.")
    dialog.edit:SetMaxLetters(mode=="Import" and 8192 or math.max(8192,string.len(text or "")));dialog.edit:SetText(text or "");dialog.scroll:SetVerticalScroll(0)
    if mode=="Import" then dialog.accept:Show() else dialog.accept:Hide() end
    if UISpecialFrames then table.insert(UISpecialFrames,dialog:GetName()) end
    K.Script(dialog,"OnHide",function(f)
        if UISpecialFrames then for i=table.getn(UISpecialFrames),1,-1 do if UISpecialFrames[i]==f:GetName() then table.remove(UISpecialFrames,i) end end end
        if UI.dialog==f then UI.dialog=nil end
    end)
    dialog:Show();dialog.edit:SetFocus();if mode~="Import" then dialog.edit:HighlightText() end
    return dialog
end
