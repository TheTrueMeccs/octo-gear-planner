-- OctoGearPlanner: no dependency on another addon or its globals.
OBP = { version = "0.2.51", Data = { items = {}, enchants = {}, instances = {} } }
OBP.Util = {}
local U = OBP.Util
U.mod = math.mod or math.fmod

function U.copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for k, v in pairs(value) do result[k] = U.copy(v) end
    return result
end

function U.equal(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not U.equal(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

function U.keys(value)
    local keys = {}
    for key in pairs(value) do table.insert(keys, key) end
    table.sort(keys)
    return keys
end

function U.trim(text) return (string.gsub(string.gsub(text or "", "^%s+", ""), "%s+$", "")) end
function U.clamp(value, low, high) return math.max(low, math.min(high, value)) end
function U.match(text, pattern)
    local _, _, a, b, c, d = string.find(text or "", pattern)
    return a, b, c, d
end
function U.split(text, separator)
    local values, start = {}, 1
    while true do
        local first, last = string.find(text, separator, start, true)
        if not first then table.insert(values, string.sub(text, start)); return values end
        table.insert(values, string.sub(text, start, first - 1))
        start = last + 1
    end
end
function U.integer(text, low, high)
    if type(text) ~= "string" or string.len(text) > 10 or not string.find(text, "^%d+$") then return nil end
    local n = tonumber(text)
    if not n or n ~= math.floor(n) or n < low or n > high or tostring(n) ~= text then return nil end
    return n
end
function U.maskAllows(mask, id)
    if mask == nil or mask == -1 then return true end
    if not id then return nil end
    return U.mod(math.floor(mask / (2 ^ (id - 1))), 2) == 1
end

function U.utf8(text)
    local i, n = 1, string.len(text)
    while i <= n do
        local c = string.byte(text, i)
        local length, code, minimum = 1, c, 0
        if c >= 194 and c <= 223 then length, code, minimum = 2, c - 192, 128
        elseif c >= 224 and c <= 239 then length, code, minimum = 3, c - 224, 2048
        elseif c >= 240 and c <= 244 then length, code, minimum = 4, c - 240, 65536
        elseif c >= 128 then return false end
        if i + length - 1 > n then return false end
        for offset = 1, length - 1 do
            local nextByte = string.byte(text, i + offset)
            if nextByte < 128 or nextByte > 191 then return false end
            code = code * 64 + nextByte - 128
        end
        if code < minimum or code > 1114111 or (code >= 55296 and code <= 57343) then return false end
        i = i + length
    end
    return true
end
function U.name(text)
    if type(text) ~= "string" then return nil, "Enter a set name." end
    text = U.trim(text)
    if text == "" or string.len(text) > 64 then return nil, "Use a name between 1 and 64 UTF-8 bytes." end
    if string.find(text, "[%c|]") or not U.utf8(text) then return nil, "The set name contains invalid characters." end
    return text
end
function U.hex(text)
    return (string.gsub(text, ".", function(c) return string.format("%02X", string.byte(c)) end))
end
function U.unhex(text, limit)
    if string.len(text) == 0 or string.len(text) > limit * 2 or U.mod(string.len(text), 2) ~= 0 or string.find(text, "[^0-9A-F]") then return nil end
    return (string.gsub(text, "..", function(pair) return string.char(tonumber(pair, 16)) end))
end
function U.adler(text)
    local a, b = 1, 0
    for i = 1, string.len(text) do
        a = U.mod(a + string.byte(text, i), 65521)
        b = U.mod(b + a, 65521)
    end
    local n, parts = b * 65536 + a, {}
    for i = 4, 1, -1 do
        parts[i] = string.format("%02X", U.mod(n, 256))
        n = math.floor(n / 256)
    end
    return table.concat(parts)
end
function U.message(text)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Octo Gear Planner:|r " .. tostring(text)) end
end

OBP.Slots = {
    [1] = {name="Head", inventory={1}, texture="Head"},
    [2] = {name="Neck", inventory={2}, texture="Neck"},
    [3] = {name="Shoulders", inventory={3}, texture="Shoulder"},
    [4] = {name="Shirt", inventory={4}, texture="Shirt"},
    [5] = {name="Chest", inventory={5,20}, texture="Chest"},
    [6] = {name="Waist", inventory={6}, texture="Waist"},
    [7] = {name="Legs", inventory={7}, texture="Legs"},
    [8] = {name="Feet", inventory={8}, texture="Feet"},
    [9] = {name="Wrists", inventory={9}, texture="Wrists"},
    [10] = {name="Hands", inventory={10}, texture="Hands"},
    [11] = {name="Finger 1", inventory={11}, texture="Finger"},
    [12] = {name="Finger 2", inventory={11}, texture="Finger"},
    [13] = {name="Trinket 1", inventory={12}, texture="Trinket"},
    [14] = {name="Trinket 2", inventory={12}, texture="Trinket"},
    [15] = {name="Back", inventory={16}, texture="Chest"},
    [16] = {name="Main Hand", inventory={13,17,21}, texture="MainHand"},
    [17] = {name="Off Hand", inventory={13,14,22,23}, texture="SecondaryHand"},
    [18] = {name="Ranged / Relic", inventory={15,25,26,28}, texture="Ranged"}
    ,[19] = {name="Tabard", inventory={19}, texture="Tabard"}
}
OBP.ClassIDs = { WARRIOR=1,PALADIN=2,HUNTER=3,ROGUE=4,PRIEST=5,SHAMAN=7,MAGE=8,WARLOCK=9,DRUID=11 }
OBP.RaceIDs = { Human=1,Orc=2,Dwarf=3,NightElf=4,Scourge=5,Undead=5,Tauren=6,Gnome=7,Troll=8,Goblin=9,HighElf=10 }
