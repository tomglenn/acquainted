local _, ns = ...
local MAX_BYTES, MAX_PEOPLE, MAX_TEXT = 1024 * 1024, 10000, 512
ns.transferLimit = MAX_BYTES

-- An inert, versioned text format. Import never evaluates Lua or imports options.
local function Encode(value)
    return (value:gsub("[^%w %-]", function(char) return string.format("%%%02X", char:byte()) end))
end
local function Decode(value)
    if value:gsub("%%%x%x", ""):find("%%") then return nil end
    local decoded = value:gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end)
    if #decoded > MAX_TEXT or decoded:find("[%z\1-\31\127]") then return nil end
    return decoded
end
local function ValidGUID(guid)
    return #guid <= 100 and guid:match("^Player%-%d+%-%x+$") ~= nil
end
local function Parse(text)
    if type(text) ~= "string" or #text > MAX_BYTES then return nil, "Transfer text is too large (maximum 1 MiB)." end
    text = text:gsub("\r\n", "\n"):gsub("^\n+", ""):gsub("\n+$", "")
    local header, body = text:match("^([^\n]+)\n?(.*)$")
    if header ~= "ACQUAINTED:1" then return nil, "Expected an Acquainted version 1 export." end
    local records, count = {}, 0
    for line in body:gmatch("[^\n]+") do
        local guid, encodedName, encodedNickname = line:match("^([^\t]+)\t([^\t]+)\t([^\t]*)$")
        if not guid or not ValidGUID(guid) or records[guid] then return nil, "Invalid or duplicate character GUID." end
        local name, nickname = Decode(encodedName), Decode(encodedNickname)
        if not name or not name:find("%S") or not nickname then return nil, "Invalid name or nickname in export." end
        count = count + 1
        if count > MAX_PEOPLE then return nil, "Too many acquaintances (maximum 10,000)." end
        records[guid] = { name = name, nickname = nickname ~= "" and nickname or nil }
    end
    return records, count
end

function ns.ExportPeople()
    local ids, lines = {}, { "ACQUAINTED:1" }
    for guid in pairs(ns.db.known) do ids[#ids + 1] = guid end
    table.sort(ids)
    for _, guid in ipairs(ids) do
        local person = ns.db.known[guid]
        lines[#lines + 1] = guid .. "\t" .. Encode(person.name) .. "\t" .. Encode(person.nickname or "")
    end
    local text = table.concat(lines, "\n")
    local valid, err = Parse(text)
    if not valid then return nil, err end
    return text
end

function ns.PreviewImport(text)
    local records, count = Parse(text)
    if not records then return nil, count end
    local result = { count = count, added = 0, existing = 0, conflicts = 0, removed = 0 }
    for guid, person in pairs(records) do
        local current = ns.db.known[guid]
        if not current then result.added = result.added + 1
        else
            result.existing = result.existing + 1
            if current.nickname ~= person.nickname then result.conflicts = result.conflicts + 1 end
        end
    end
    for guid in pairs(ns.db.known) do
        if not records[guid] then result.removed = result.removed + 1 end
    end
    return result
end

function ns.ImportPeople(text, replace, overwrite)
    -- Validate the entire payload before any mutation, including on commit.
    local records, count = Parse(text)
    if not records then return false, count end
    if replace then ns.db.known = records
    else
        for guid, person in pairs(records) do
            if not ns.db.known[guid] or overwrite then ns.db.known[guid] = person end
        end
    end
    if ns.ClearRememberedUndo then ns.ClearRememberedUndo() end
    ns.PeopleChanged()
    return true, count
end
