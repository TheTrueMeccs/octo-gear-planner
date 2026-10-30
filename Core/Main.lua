local U,K=OBP.Util,OBP.Compat
local initialized=false
local driver=CreateFrame("Frame","OBPEventDriver",UIParent)
local pending=false
local function capture()
    local okay,profile=pcall(OBP.Profile.Capture)
    if okay then OBP.profile=profile
    else U.message("Character profile could not be read: "..tostring(profile));return false end
    return true
end
local function initialize()
    if initialized then return end
    -- The former name may hold newer builds than the original gear-planner
    -- save. Import it once, then always prefer this addon's own saved data.
    local migrated=type(OGPDB)=="table" and OGPDB.gearPlannerNameMigration==true
    if not migrated and OBPDB==nil and LoadAddOn then
        local okay,loaded,reason=pcall(LoadAddOn,"OctoBuildPlanner")
        if not okay or (not loaded and reason~="MISSING") then
            U.message("Saved data could not be loaded. Enable 'Octo Gear Planner (saved data from former name)' in the addon list and reload before migrating.");return
        end
    end
    local db,reason=OBP.Persistence.Load(migrated and OGPDB or OBPDB or OGPDB)
    if not db then U.message(reason);return end
    db.gearPlannerNameMigration=true;OGPDB=db
    if not capture() then return end
    OBP.Catalogue.BuildIndex();K.StartQueue();OBP.UI.Create();initialized=true
    U.message("Loaded. Type /ogp to plan gear and talents, or /ogp diagnostics for compatibility details.")
end
K.Script(driver,"OnEvent",function(_,eventName,a)
    if eventName=="PLAYER_LOGIN" then initialize()
    elseif eventName=="PLAYER_LOGOUT" and initialized then OBP.Persistence.Sync()
    elseif initialized then
        if eventName=="GET_ITEM_INFO_RECEIVED" or eventName=="ITEM_DATA_LOAD_RESULT" then OBP.UI.RefreshCache(tonumber(a))
        elseif not string.find(eventName,"^UNIT_") or a==nil or a=="player" then pending=0.15 end
    end
end)
K.Script(driver,"OnUpdate",function(_,elapsed)
    if pending then
        pending=pending-(elapsed or 0)
        if pending<=0 then
            pending=false
            if capture() and OBP.UI.main:IsShown() then OBP.UI.Requery();OBP.UI.Refresh() end
        end
    end
end)
for _,name in ipairs({"PLAYER_LOGIN","PLAYER_LOGOUT","PLAYER_ENTERING_WORLD","PLAYER_LEVEL_UP","UNIT_STATS","UNIT_AURA","PLAYER_AURAS_CHANGED","UNIT_INVENTORY_CHANGED","CHARACTER_POINTS_CHANGED","SKILL_LINES_CHANGED","SPELLS_CHANGED","UPDATE_SHAPESHIFT_FORM","GET_ITEM_INFO_RECEIVED","ITEM_DATA_LOAD_RESULT"}) do pcall(driver.RegisterEvent,driver,name) end
SLASH_OCTOGEARPLANNER1="/ogp"
SLASH_OCTOGEARPLANNER2="/octogearplanner"
SlashCmdList["OCTOGEARPLANNER"]=function(text)
    if not initialized then initialize() end
    if not initialized then return end
    if U.trim(text)=="diagnostics" then OBP.UI.TextDialog("Octo Gear Planner Diagnostics",K.Diagnostic(),"Diagnostics")
    else OBP.UI.Toggle() end
end
