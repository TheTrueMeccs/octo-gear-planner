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
    -- The data-only legacy addon loads the most recently saved database even
    -- when this upgrade was installed while the previous version was running.
    if OBPDB==nil and OGPDB==nil and LoadAddOn then
        local okay,loaded,reason=pcall(LoadAddOn,"OctoGearPlanner")
        if not okay or (not loaded and reason~="MISSING") then
            U.message("Legacy saved data could not be loaded. Enable 'Octo Build Planner (legacy saved data)' in the addon list and reload before migrating.");return
        end
    end
    local db,reason=OBP.Persistence.Load(OBPDB or OGPDB)
    if not db then U.message(reason);return end
    OBPDB=db
    if not capture() then return end
    OBP.Catalogue.BuildIndex();K.StartQueue();OBP.UI.Create();initialized=true
    U.message("Loaded. Type /obp to plan gear and talents, or /obp diagnostics for compatibility details.")
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
SLASH_OCTOBUILDPLANNER1="/obp"
SLASH_OCTOBUILDPLANNER2="/octobuildplanner"
SLASH_OCTOBUILDPLANNER3="/ogp"
SLASH_OCTOBUILDPLANNER4="/octogearplanner"
SlashCmdList["OCTOBUILDPLANNER"]=function(text)
    if not initialized then initialize() end
    if not initialized then return end
    if U.trim(text)=="diagnostics" then OBP.UI.TextDialog("Octo Build Planner Diagnostics",K.Diagnostic(),"Diagnostics")
    else OBP.UI.Toggle() end
end
