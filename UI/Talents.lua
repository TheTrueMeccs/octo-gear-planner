local U,K,T,P,UI=OBP.Util,OBP.Compat,OBP.Talents,OBP.Persistence,OBP.UI
local ICON=32*1.1
local function location(canvas,talent) return canvas.columnStart+talent.column*canvas.columnStep,18+talent.row*canvas.tierStep end
local function thinButton(parent,label,width,callback,size)
    local button=UI.Button(parent,label,width,18,callback)
    button:GetFontString():SetFont("Fonts\\FRIZQT__.TTF",size or 10)
    return button
end
local function commit(build)
    local valid,reason=P.EditTalents(build,OBP.profile)
    if not valid then UI.Error(reason);return end
    UI.Refresh()
end
local function confirm(title,message,action)
    local build,active,name=U.copy(P.working.talents),P.db.active,P.working.name
    UI.Dialog(title,message,{{text="Continue",action=function()
        if P.db.active~=active or P.working.name~=name or not U.equal(P.working.talents,build) then UI.Error("The selected talent build changed. Please try again.");return end
        action()
    end},{text="Cancel"}})
end
function UI.SetTalentLevel(level)
    level=U.clamp(math.floor(level+0.5),10,60)
    local build=P.working.talents
    if level==build.level then return end
    if T.Spent(build)>level-9 then
        UI.RefreshTalents()
        if UI.dialog and UI.dialog.talentLevelProposal then return end
        local snapshot,active,name=U.copy(build),P.db.active,P.working.name
        local dialog=UI.Dialog("Reset Talent Build?","Level "..level.." allows "..level-9 .." talent points. Reset all allocated talents to use this level?",{
            {text="Reset Build",action=function()
                if P.db.active~=active or P.working.name~=name or not U.equal(P.working.talents,snapshot) then UI.Error("The selected talent build changed. Please try again.");return end
                local out=T.Reset(snapshot);out.level=level;commit(out)
            end},{text="Cancel",action=UI.RefreshTalents}
        },{cancel=UI.RefreshTalents,hidden=true})
        dialog.talentLevelProposal=true
    else local out=U.copy(build);out.level=level;commit(out) end
end
function UI.ResetTalents(tab)
    if T.Spent(P.working.talents,tab)==0 then return end
    confirm("Reset Talents",tab and "Remove every point from the selected talent tree?" or "Remove every point from all three talent trees?",function() commit(T.Reset(P.working.talents,tab)) end)
end
function UI.CopyTalents()
    local build,reason=T.CopyCurrent(OBP.profile)
    if not build then UI.Error(reason);return end
    if U.equal(build,P.working.talents) then return end
    if T.Spent(P.working.talents)>0 then
        confirm("Copy Current Talents","Replace this planned talent build with your current talents and character level?",function() commit(build) end)
    else commit(build) end
end
function UI.TalentTooltip(button)
    local talent=OBP.Data.talents[button.talentID]
    if not talent then return end
    local rank=P.working.talents.ranks[talent.id] or 0
    GameTooltip:SetOwner(button,"ANCHOR_RIGHT")
    local spell=talent.spells[math.max(1,rank)]
    local okay
    if GameTooltip.SetSpellByID then okay=pcall(GameTooltip.SetSpellByID,GameTooltip,spell)
    else okay=pcall(GameTooltip.SetHyperlink,GameTooltip,"spell:"..spell) end
    if not okay then GameTooltip:SetText(talent.name,1,0.82,0,true) end
    GameTooltip:AddLine("Rank "..rank.."/"..table.getn(talent.spells),1,1,1)
    if rank>0 and rank<table.getn(talent.spells) then
        local nextSpell=talent.spells[rank+1]
        local desc
        local reader=GetSpellDescription or (C_Spell and C_Spell.GetSpellDescription)
        if reader then local ok,text=pcall(reader,nextSpell);if ok then desc=text end end
        if desc and desc~="" then GameTooltip:AddLine("Next rank:",1,1,1);GameTooltip:AddLine(desc,1,0.82,0,true) end
    end
    local available,reason=T.Change(P.working.talents,talent.id,1,OBP.profile)
    if not available and rank<table.getn(talent.spells) then GameTooltip:AddLine(reason,1,0.2,0.2,true) end
    GameTooltip:AddLine("Left-click to add; right-click to remove.",0.7,0.7,0.7,true)
    GameTooltip:Show()
end
local function branch(canvas,parent,child)
    local px,py=location(canvas,parent);local cx,cy=location(canvas,child)
    local connection={textures={},parent=parent.id,child=child.id}
    local function line(x,y,w,h)
        local tex=canvas:CreateTexture(nil,"BORDER");tex:SetTexture("Interface\\TalentFrame\\UI-TalentBranches")
        if w==2 then x=x-15;w=32;tex.branchUV={0,0.125,0,0.484375,0.515625}
        else y=y-15;h=32;tex.branchUV={0.2578125,0.3828125,0,0.5,0.5} end
        tex:SetPoint("TOPLEFT",canvas,"TOPLEFT",x,-y);tex:SetWidth(w);tex:SetHeight(h);table.insert(connection.textures,tex)
    end
    local middle=(py+cy+ICON)/2
    if py==cy then line(math.min(px,cx)+ICON/2,py+ICON/2-1,math.abs(cx-px),2)
    else
        line(px+ICON/2-1,py+ICON/2,2,middle-py-ICON/2+1)
        if px~=cx then line(math.min(px,cx)+ICON/2,middle-1,math.abs(cx-px)+1,2) end
        line(cx+ICON/2-1,middle,2,cy-middle)
    end
    local arrow=canvas:CreateTexture(nil,"ARTWORK");connection.arrow=arrow
    arrow:SetTexture("Interface\\TalentFrame\\UI-TalentArrows");arrow:SetWidth(32);arrow:SetHeight(32)
    if py==cy then
        arrow:SetPoint("TOPLEFT",canvas,"TOPLEFT",cx>px and cx-21 or cx+ICON-11,-cy-ICON/2+16)
        connection.coords=cx>px and {1,0.5} or {0.5,1}
    else arrow:SetPoint("TOPLEFT",canvas,"TOPLEFT",cx+ICON/2-16,-cy+21);connection.coords={0,0.5} end
    return connection
end
function UI.BuildTalentPanel()
    local scale=UI.characterScale
    local width,height=UI.paper:GetWidth()/scale,UI.paperContent:GetHeight()*UI.paperContent:GetScale()/scale
    local panel=UI.Panel(UI.paper,width,height);UI.talentPanel=panel;panel:SetScale(scale);panel:SetPoint("TOPLEFT",UI.paper,"TOPLEFT",0,0)
    local level=UI.Text(panel,"",10,true);UI.talentLevelLabel=level;level:SetPoint("TOPLEFT",panel,"TOPLEFT",12,-12)
    UI.resetAllTalents=thinButton(panel,"Reset All",64,function() UI.ResetTalents() end);UI.resetAllTalents:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-10,-8)
    UI.resetTalentTree=thinButton(panel,"Reset Tree",70,function() local tree=T.Trees(P.working.talents)[P.db.prefs.talentTab];if tree then UI.ResetTalents(tree.id) end end)
    UI.resetTalentTree:SetPoint("RIGHT",UI.resetAllTalents,"LEFT",-4,0)
    local slider=CreateFrame("Slider",UI.Name("TalentLevel"),panel,"OptionsSliderTemplate");UI.talentLevel=slider
    slider:SetWidth(width-222);slider:SetHeight(12);slider:SetPoint("TOPLEFT",panel,"TOPLEFT",66,-11)
    slider:SetMinMaxValues(10,60);slider:SetValueStep(1)
    for _,suffix in ipairs({"Low","High","Text"}) do local label=_G and _G[slider:GetName()..suffix];if label then label:Hide() end end
    K.Script(slider,"OnValueChanged",function(f,n) if not UI.talentSync then UI.SetTalentLevel(n or f:GetValue()) end end)
    local canvas=CreateFrame("Frame",UI.Name("TalentTree"),panel);UI.talentCanvas=canvas
    canvas:SetWidth(width-16);canvas:SetHeight(height-66);canvas:SetPoint("TOPLEFT",panel,"TOPLEFT",8,-34)
    -- Enlarge icons and use two more units at each end of the tree. Keep
    -- the complete rank badges above the footer controls and fit all seven tiers.
    canvas.tierStep=(canvas:GetHeight()-18-ICON-16-22)/6
    canvas.columnStep=ICON+2*(canvas.tierStep-ICON)
    canvas.columnStart=(canvas:GetWidth()-3*canvas.columnStep-ICON)/2
    local points=UI.Text(canvas,"",10,true);UI.talentPoints=points;points:SetPoint("BOTTOMLEFT",canvas,"BOTTOMLEFT",6,6)
    points:SetWidth(canvas:GetWidth()-150);points:SetHeight(12)
    UI.copyTalents=thinButton(canvas,"Copy Current Talents",126,UI.CopyTalents,9);UI.copyTalents:SetPoint("BOTTOMRIGHT",canvas,"BOTTOMRIGHT",-6,3)
    UI.Hint(UI.copyTalents,"Copy your current talents and character level into this planned set.")
    canvas.backgrounds={}
    -- Native art has transparent padding; refresh fits its opaque dimensions
    -- to the full canvas width, leaving the footer below it black.
    for _,suffix in ipairs({"TopLeft","TopRight","BottomLeft","BottomRight"}) do
        local texture=canvas:CreateTexture(nil,"BACKGROUND");texture.suffix=suffix;table.insert(canvas.backgrounds,texture)
    end
    canvas.footer=canvas:CreateTexture(nil,"BORDER");canvas.footer:SetTexture("Interface\\Buttons\\WHITE8x8");canvas.footer:SetVertexColor(0,0,0,1);canvas.footer:SetWidth(canvas:GetWidth());canvas.footer:SetHeight(28);canvas.footer:SetPoint("BOTTOMLEFT",canvas,"BOTTOMLEFT",0,0)
    UI.talentButtons={};UI.talentBranches={}
    local trees=T.Trees(P.working.talents)
    for _,tree in ipairs(trees) do
        for _,id in ipairs(tree.talents) do
            local talent=OBP.Data.talents[id]
            local button=CreateFrame("Button",UI.Name("Talent"),canvas);UI.talentButtons[id]=button;button.talentID=id
            local x,y=location(canvas,talent);button:SetWidth(ICON);button:SetHeight(ICON);button:SetPoint("TOPLEFT",canvas,"TOPLEFT",x,-y);button:RegisterForClicks("LeftButtonUp","RightButtonUp")
            button.icon=button:CreateTexture(nil,"ARTWORK");button.icon:SetAllPoints(button);button.icon:SetTexture(talent.icon)
            -- Match the native 37-unit talent button's 64-unit slot/normal art
            -- at the enlarged icon size, keeping the status frame close to the bevel.
            local artSize=ICON*64/37
            button.slot=button:CreateTexture(nil,"BACKGROUND");button.slot:SetTexture("Interface\\Buttons\\UI-EmptySlot-White");button.slot:SetWidth(artSize);button.slot:SetHeight(artSize);button.slot:SetPoint("CENTER",button,"CENTER",0,0)
            button:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
            local normal=button:GetNormalTexture();normal:ClearAllPoints();normal:SetWidth(artSize);normal:SetHeight(artSize);normal:SetPoint("CENTER",button,"CENTER",0,-ICON/37)
            button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
            local badge=CreateFrame("Frame",UI.Name("TalentRank"),button);button.rankBadge=badge;badge:SetWidth(32);badge:SetHeight(32);badge:SetPoint("CENTER",button,"BOTTOMRIGHT",0,0)
            local border=badge:CreateTexture(nil,"BACKGROUND");border:SetAllPoints(badge);border:SetTexture("Interface\\TalentFrame\\TalentFrame-RankBorder")
            button.rank=UI.Text(badge,"",10,false);button.rank:SetPoint("CENTER",badge,"CENTER",0,0)
            K.Script(button,"OnClick",function(f,mouse)
                local out,reason=T.Change(P.working.talents,f.talentID,mouse=="RightButton" and -1 or 1,OBP.profile)
                if out then commit(out);UI.TalentTooltip(f) else U.message(reason) end
            end)
            K.Script(button,"OnEnter",UI.TalentTooltip);K.Script(button,"OnLeave",function() GameTooltip:Hide() end)
            for _,req in ipairs(talent.requires) do local line=branch(canvas,OBP.Data.talents[req.id],talent);line.tab=tree.id;line.required=req.rank;table.insert(UI.talentBranches,line) end
        end
    end
    UI.talentSpecs={}
    for i,tree in ipairs(trees) do
        local index=i
        local button=thinButton(panel,tree.name,(width-32)/3,function() P.db.prefs.talentTab=index;GameTooltip:Hide();UI.RefreshTalents() end,9)
        button:SetPoint("BOTTOMLEFT",panel,"BOTTOMLEFT",10+(i-1)*((width-32)/3+6),8);UI.talentSpecs[i]=button
    end
    local navigation=CreateFrame("Frame",UI.Name("CharacterNavigation"),UI.paper);UI.characterNavigation=navigation
    navigation:SetScale(scale);navigation:SetWidth(width);navigation:SetHeight(32);navigation:SetPoint("BOTTOMLEFT",UI.paper,"BOTTOMLEFT",0,0)
    local navWidth,navHeight=110,22
    UI.characterTab=UI.Button(navigation,"Character",navWidth,navHeight,function() UI.SetCharacterPage("Character") end);UI.characterTab:SetPoint("BOTTOMLEFT",navigation,"BOTTOMLEFT",(width-2*navWidth-10)/2,5)
    UI.talentsTab=UI.Button(navigation,"Talents",navWidth,navHeight,function() UI.SetCharacterPage("Talents") end);UI.talentsTab:SetPoint("LEFT",UI.characterTab,"RIGHT",10,0)
    UI.SetCharacterPage(P.db.prefs.characterPage)
end
function UI.RefreshTalents()
    if not UI.talentPanel then return end
    local build=P.working.talents
    local trees=T.Trees(build);local selected=P.db.prefs.talentTab or 1
    local tree=trees[selected]
    UI.talentSync=true;UI.talentLevel:SetValue(build.level);UI.talentSync=nil
    UI.talentLevelLabel:SetText("Level "..build.level)
    UI.talentPoints:SetText("Points remaining: "..build.level-9-T.Spent(build))
    if not tree then return end
    local canvas=UI.talentCanvas
    local rightWidth=tree.background=="RogueAssassination" and 43 or 44
    local artScale=canvas:GetWidth()/(256+rightWidth)
    for _,texture in ipairs(canvas.backgrounds) do
        local right=string.find(texture.suffix,"Right")~=nil
        local bottom=string.find(texture.suffix,"Bottom")~=nil
        local x,y=right and 256 or 0,bottom and 256 or 0
        local w,h=right and rightWidth or 256,bottom and 75 or 256
        local visibleHeight=math.min(h*artScale,canvas:GetHeight()-28-y*artScale)
        texture:SetTexture("Interface\\TalentFrame\\"..tree.background.."-"..texture.suffix)
        texture:SetWidth(w*artScale);texture:SetHeight(math.max(0,visibleHeight));texture:ClearAllPoints();texture:SetPoint("TOPLEFT",canvas,"TOPLEFT",x*artScale,-y*artScale)
        texture:SetTexCoord(0,right and rightWidth/64 or 1,0,(bottom and 75/128 or 1)*math.max(0,visibleHeight)/(h*artScale))
        if visibleHeight>0 then texture:Show() else texture:Hide() end
    end
    for id,button in pairs(UI.talentButtons) do
        local talent=OBP.Data.talents[id]
        if talent.tab==tree.id then
            local rank=build.ranks[id] or 0
            local available=T.Change(build,id,1,OBP.profile)
            local r,g,b=1,0.82,0
            if rank==table.getn(talent.spells) then r,g,b=1,0.82,0 elseif available or rank>0 then r,g,b=0.1,1,0.1 else r,g,b=0.5,0.5,0.5 end
            button.rank:SetText(tostring(rank));button.rank:SetTextColor(r,g,b)
            button.slot:SetVertexColor(r,g,b)
            if rank>0 or available then button.rankBadge:Show() else button.rankBadge:Hide() end
            local locked=not available and rank==0
            if button.icon.SetDesaturated then pcall(button.icon.SetDesaturated,button.icon,locked and true or false) end
            local shade=locked and 0.65 or 1
            button.icon:SetVertexColor(shade,shade,shade,1)
            button:Show()
        else button:Hide() end
    end
    for i,button in ipairs(UI.talentSpecs) do button:SetText(trees[i].name.." ("..T.Spent(build,trees[i].id)..")");UI.SetActive(button,i==selected) end
    for _,line in ipairs(UI.talentBranches) do
        local visible=line.tab==tree.id
        local met=(build.ranks[line.parent] or 0)>=line.required
        for _,texture in ipairs(line.textures) do
            local uv=texture.branchUV
            texture:SetTexCoord(uv[1],uv[2],met and uv[3] or uv[3]+uv[5],met and uv[4] or uv[4]+uv[5])
            if visible then texture:Show() else texture:Hide() end
        end
        line.arrow:SetTexCoord(line.coords[1],line.coords[2],met and 0 or 0.5,met and 0.5 or 1)
        if visible then line.arrow:Show() else line.arrow:Hide() end
    end
end
function UI.SetCharacterPage(page)
    if page~="Talents" then page="Character" end
    P.db.prefs.characterPage=page;UI.rotation=nil;GameTooltip:Hide()
    if page=="Talents" then UI.SetModelView(false) end
    if page=="Character" then UI.paperContent:Show();UI.talentPanel:Hide() else UI.paperContent:Hide();UI.talentPanel:Show() end
    UI.SetActive(UI.characterTab,page=="Character");UI.SetActive(UI.talentsTab,page=="Talents")
    UI.RefreshTalents()
end
