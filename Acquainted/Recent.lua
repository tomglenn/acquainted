local _, ns = ...
local recent = {}
ns.Recent = recent
local LIMIT, MAX_PENDING = 50, 100
local pending = {}
local dirty = false

function recent.Now()
    return (GetServerTime or time)()
end
local function CleanText(value)
    if not ns.IsReadable(value) or type(value) ~= "string" then return nil end
    value = ns.WithoutColourCodes(value):gsub("|[TtAa].-|[ta]", ""):gsub("[\r\n]", " ")
    if value == "" or #value > 512 then return nil end
    return value
end
local function Trim(bucket)
    local entries = {}
    for guid, record in pairs(bucket) do entries[#entries + 1] = { guid = guid, record = record } end
    table.sort(entries, function(a, b)
        if a.record.lastSeen ~= b.record.lastSeen then return a.record.lastSeen > b.record.lastSeen end
        if a.record.order ~= b.record.order then return a.record.order > b.record.order end
        return a.guid < b.guid
    end)
    for index = LIMIT + 1, #entries do bucket[entries[index].guid] = nil end
end
function recent.Initialize(db)
    local saved = type(db.recent) == "table" and db.recent or {}
    db.recent = { group = {}, nearby = {}, sequence = 0 }
    pending, dirty = {}, false
    recent.generation = (recent.generation or 0) + 1
    for _, kind in ipairs({ "group", "nearby" }) do
        for guid, record in pairs(type(saved[kind]) == "table" and saved[kind] or {}) do
            if type(guid) == "string" and guid:sub(1, 7) == "Player-" and #guid <= 100
                and guid ~= UnitGUID("player") and not db.known[guid] and type(record) == "table" then
                local name, rpName = CleanText(record.name), CleanText(record.rpName)
                local stamp, order = record.lastSeen, record.order
                if name and type(stamp) == "number" and stamp == stamp and stamp >= 0 and stamp <= recent.Now()
                    and type(order) == "number" and order == order and order >= 0 and order < math.huge then
                    if kind == "group" or not db.recent.group[guid] then
                        db.recent[kind][guid] = { name = name, rpName = rpName, lastSeen = stamp, order = order,
                            source = kind == "nearby" and "nearby" or (record.source == "raid" and "raid" or "party") }
                        db.recent.sequence = math.max(db.recent.sequence, order)
                    end
                end
            end
        end
        Trim(db.recent[kind])
    end
end
function recent.Remove(guid)
    local saved = ns.db and ns.db.recent
    if not saved then return end
    if saved.group[guid] or saved.nearby[guid] then
        saved.group[guid], saved.nearby[guid] = nil, nil
        dirty = true
    end
end
function recent.PruneKnown()
    if not ns.db or not ns.db.recent then return end
    for _, bucket in ipairs({ ns.db.recent.group, ns.db.recent.nearby }) do
        for guid in pairs(bucket) do if ns.db.known[guid] then recent.Remove(guid) end end
    end
end
function recent.Clear()
    ns.db.recent = { group = {}, nearby = {}, sequence = 0 }
    pending, dirty = {}, true
    recent.generation = recent.generation + 1
end
local function RPName(unit)
    local addon = AddOn_TotalRP3
    if not addon or not addon.Player or type(addon.Player.CreateFromUnit) ~= "function" then return nil end
    local ok, name = pcall(function() return addon.Player.CreateFromUnit(unit):GetRoleplayingName() end)
    if ok then return CleanText(name) end
end
local function Capture(unit, source, retry)
    if not ns.IsEnabled() or not unit then return end
    local ok, guid, name, grouped = pcall(function()
        if not ns.IsPlayer(unit) or UnitIsUnit(unit, "player") then return end
        local id, fullName = ns.Identity(unit)
        return id, fullName, ns.IsGroupMember(unit)
    end)
    if not ok or not ns.IsReadable(guid) or type(guid) ~= "string" or guid:sub(1, 7) ~= "Player-" then return end
    if ns.db.known[guid] then pending[unit] = nil; recent.Remove(guid); return end
    name = CleanText(name)
    if not name then
        if not retry then
            local count = 0
            for _ in pairs(pending) do count = count + 1 end
            if count < MAX_PENDING then pending[unit] = { guid = guid, source = source, attempts = 0 } end
        end
        return
    end
    pending[unit] = nil
    local saved = ns.db.recent
    if source == "nearby" and grouped then
        local raidOK, raidIndex = pcall(UnitInRaid, unit)
        source = raidOK and ns.IsReadable(raidIndex) and raidIndex and "raid" or "party"
    end
    local kind = source == "nearby" and "nearby" or "group"
    -- Nearby traffic never evicts or reorders a former group member.
    if kind == "nearby" and saved.group[guid] then return end
    local rpName = RPName(unit)
    local old = saved[kind][guid]
    local prior = old or saved.nearby[guid]
    if prior and not rpName then rpName = prior.rpName end
    local stamp = recent.Now()
    if old and old.lastSeen == stamp and old.name == name and old.rpName == rpName and old.source == source then return end
    saved.sequence = saved.sequence + 1
    saved[kind][guid] = { name = name, rpName = rpName, lastSeen = stamp, order = saved.sequence, source = source }
    if kind == "group" then saved.nearby[guid] = nil end
    Trim(saved[kind])
    dirty = true
end
function recent.CaptureNearby(unit) Capture(unit, "nearby") end
function recent.CaptureGroup()
    if not ns.IsEnabled() then return end
    if IsInRaid() then
        for index = 1, (GetNumGroupMembers and GetNumGroupMembers() or 40) do Capture("raid" .. index, "raid") end
    else
        for index = 1, (GetNumSubgroupMembers and GetNumSubgroupMembers() or 4) do Capture("party" .. index, "party") end
    end
end
function recent.RetryPending()
    if not ns.IsEnabled() then pending = {}; return end
    for unit, record in pairs(pending) do
        record.attempts = record.attempts + 1
        local ok, guid = pcall(UnitGUID, unit)
        if not ok or not ns.IsReadable(guid) or guid ~= record.guid or record.attempts > 40 then pending[unit] = nil
        else Capture(unit, record.source, true) end
    end
end
function recent.ConsumeDirty()
    local changed = dirty
    dirty = false
    return changed
end
function recent.List(query)
    local result = { group = {}, nearby = {}, generation = recent.generation }
    query = (query or ""):lower()
    for _, kind in ipairs({ "group", "nearby" }) do
        for guid, record in pairs(ns.db.recent[kind]) do
            if not ns.db.known[guid] and (query == "" or record.name:lower():find(query, 1, true)
                or (record.rpName and record.rpName:lower():find(query, 1, true))) then
                result[kind][#result[kind] + 1] = { guid = guid, name = record.name, rpName = record.rpName,
                    lastSeen = record.lastSeen, order = record.order, source = record.source }
            end
        end
        table.sort(result[kind], function(a, b)
            if a.lastSeen ~= b.lastSeen then return a.lastSeen > b.lastSeen end
            if a.order ~= b.order then return a.order > b.order end
            return a.guid < b.guid
        end)
    end
    return result
end
function recent.Meet(guid, snapshot, generation)
    local saved = ns.db.recent
    local record = saved.group[guid] or saved.nearby[guid]
    -- Keep a displayed encounter actionable even if live history evicts it.
    -- Clearing history invalidates snapshots as well as stored records.
    if not record and generation == recent.generation and snapshot and snapshot.guid == guid then record = snapshot end
    if not record or ns.db.known[guid] then return false end
    local name = CleanText(record.name)
    if not name then return false end
    ns.SetRemembered(guid, name, false)
    return true
end
