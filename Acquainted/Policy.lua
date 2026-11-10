local _, ns = ...
ns.defaults = {
    enabled = true, showFriends = false, showWoWFriends = false, showBattleNetFriends = false,
    showCommunities = false, showGuild = true, showGroup = true,
    useTRPRelations = true, useRPNames = true, affectEnemies = false, onlyWhileIC = false,
    showGuildName = true, showPetNames = true, fontSize = 22, nameOffset = -40,
    metColour = "FFD100", hideMet = false, hideUnmet = false, showUnmetGuildName = false,
    unmetDisplay = "name", overlayOnly = false,
    unmetFontSize = 14, unmetNameOffset = -40, unmetColour = "999999",
}
-- Display order is also custom-colour priority. Inherited Met colour never
-- masks a lower-priority custom colour, including for manually met players.
ns.recognitionCategories = {
    { id = "guild", label = "Guild members", option = "showGuild" },
    { id = "wowFriend", label = "WoW Friends", option = "showWoWFriends" },
    { id = "battleNetFriend", label = "Battle.net friends", option = "showBattleNetFriends" },
    { id = "characterFriend", label = "Character friends", option = "showFriends" },
    { id = "trpRelation", label = "Total RP 3 relationships", option = "useTRPRelations" },
    { id = "community", label = "Selected communities", option = "showCommunities" },
    { id = "group", label = "Party and raid members", option = "showGroup" },
}
ns.colourKeys = { metColour = true, unmetColour = true }
ns.colourModeKeys = {}
for _, category in ipairs(ns.recognitionCategories) do
    category.modeKey, category.colourKey = category.id .. "ColourMode", category.id .. "Colour"
    ns.defaults[category.modeKey], ns.defaults[category.colourKey] = "met", "FFD100"
    ns.colourModeKeys[category.modeKey], ns.colourKeys[category.colourKey] = true, true
end
ns.optionRanges = {
    fontSize = { 8, 48 }, unmetFontSize = { 8, 48 },
    nameOffset = { -200, 100 }, unmetNameOffset = { -200, 100 },
}

function ns.NormalizeHex(value)
    if type(value) ~= "string" then return nil end
    value = value:gsub("^#", "")
    if value:match("^%x%x%x%x%x%x$") then return value:upper() end
end

function ns.NormalizeOption(key, value)
    if ns.defaults[key] == nil or type(value) ~= type(ns.defaults[key]) then return nil end
    if key == "unmetDisplay" and value ~= "name" and value ~= "label" and value ~= "icon" then return nil end
    if ns.colourModeKeys[key] and value ~= "met" and value ~= "custom" then return nil end
    if ns.colourKeys[key] then return ns.NormalizeHex(value) end
    local range = ns.optionRanges[key]
    if range then
        if value ~= value or value == math.huge or value == -math.huge then return nil end
        return math.max(range[1], math.min(range[2], math.floor(value)))
    end
    return value
end

function ns.ColourRGB(hex)
    return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

function ns.ColourHex(r, g, b)
    local function Byte(value) return math.floor(math.max(0, math.min(1, value)) * 255 + 0.5) end
    return string.format("%02X%02X%02X", Byte(r), Byte(g), Byte(b))
end

function ns.Appearance(known, options)
    local size = known and options.fontSize or options.unmetFontSize
    local height = known and options.nameOffset or options.unmetNameOffset
    local colour = known and options.metColour or options.unmetColour
    return size, height, ns.ColourRGB(colour)
end

-- Plater owns its own unitFrame and text. Never manage its native display.
function ns.UseOverlay(options)
    return options.overlayOnly or type(Plater) == "table"
end

-- Instances use existing native settings; accessible outsider plates can still
-- be styled. Group recognition is handled per player, not as a global pause.
function ns.NativeSettingsReason()
    if IsInInstance and IsInInstance() then return "instance" end
end

-- Use TRP3's own status interpretation, including its default IC state.
-- A present but unready API pauses displays until the next service pass.
function ns.ICPauseReason(options)
    if not options.onlyWhileIC then return nil end
    local addon = AddOn_TotalRP3
    if not addon and not TRP3_API then return nil end
    local ok, inCharacter = pcall(function()
        local player = addon.Player.GetCurrentUser()
        return player:IsInCharacter()
    end)
    if not ok or not ns.IsReadable(inCharacter) or type(inCharacter) ~= "boolean" then return "unavailable" end
    if not inCharacter then return "ooc" end
end

function ns.PlayerLabel(known, options, name)
    if known then
        if not options.hideMet then return name end
    elseif not options.hideUnmet then
        if options.unmetDisplay == "label" then return "Unmet" end
        if options.unmetDisplay == "icon" then return "|TInterface\\AddOns\\Acquainted\\Media\\Unmet:0|t" end
        return name
    end
end

function ns.ShowGuild(known, options)
    if known then return not options.hideMet and options.showGuildName end
    return not options.hideUnmet and options.unmetDisplay == "name" and options.showUnmetGuildName
end

function ns.WithoutColourCodes(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[%w_]+:", ""):gsub("|r", ""))
end
function ns.IsReadable(value)
    return not (issecretvalue and issecretvalue(value))
end
function ns.IsPlayer(unit)
    local value = (UnitIsHumanPlayer or UnitIsPlayer)(unit)
    return ns.IsReadable(value) and value
end
function ns.Identity(unit)
    local guid = UnitGUID(unit)
    if not ns.IsReadable(guid) then return nil end
    local first, surname = (UnitNameUnmodified or UnitName)(unit)
    -- Recognition and saved nicknames use the GUID even if the live name is
    -- temporarily missing or restricted during nameplate assignment.
    if not ns.IsReadable(first) or not ns.IsReadable(surname) or not first then return guid end
    local name = first
    if surname and surname ~= "" and first:sub(-#surname - 1) ~= " " .. surname
        and first:sub(-#surname - 1) ~= "-" .. surname then name = first .. " " .. surname end
    -- Forever's second name is a surname. GUIDs identify characters, not RP profiles.
    return guid, name
end
function ns.TRPRelation(unit)
    local api = TRP3_API
    if not (api and api.utils and api.utils.str and api.register and api.register.relation) then return false end
    local id = api.utils.str.getUnitID(unit)
    local profileID = id and api.register.getUnitIDProfileID(id)
    local relation = profileID and api.register.relation.getRelation(profileID)
    return relation and relation.id and relation.id ~= "NONE" and relation.id ~= "" or false
end
function ns.ShouldManage(unit, options)
    return ns.Classify(unit, options)
end
local function Check(func, ...)
    if type(func) ~= "function" then return false end
    local ok, value = pcall(func, ...)
    return ok and ns.IsReadable(value) and not not value
end
function ns.IsGroupMember(unit)
    return unit and (Check(UnitInParty, unit) or Check(UnitInRaid, unit)) or false
end
function ns.AutoRecognition(guid, unit, db, customOnly)
    local options, firstMatch, hasCustom = db.options, nil, false
    local friendKind
    for _, category in ipairs(ns.recognitionCategories) do
        if options[category.option] and options[category.modeKey] == "custom" then hasCustom = true; break end
    end
    if customOnly and not hasCustom then return false, "unknown" end
    for _, category in ipairs(ns.recognitionCategories) do
        if options[category.option] and (not customOnly or options[category.modeKey] == "custom") then
            local id, matches = category.id, false
            if id == "guild" then matches = guid and Check(IsGuildMember, guid)
            elseif id == "characterFriend" then matches = guid and Check(C_FriendList and C_FriendList.IsFriend, guid)
            elseif id == "wowFriend" or id == "battleNetFriend" then
                if friendKind == nil then friendKind = (guid and ns.Social.FriendKind(guid)) or false end
                matches = friendKind == id
            elseif id == "group" then matches = ns.IsGroupMember(unit)
            elseif id == "community" then matches = guid and ns.Social.IsCommunityMember(guid)
            elseif id == "trpRelation" then
                matches = (unit and Check(ns.TRPRelation, unit)) or (guid and Check(ns.TRPRelationByGUID, guid))
            end
            if matches then
                firstMatch = firstMatch or id
                if options[category.modeKey] == "custom" then return true, firstMatch, options[category.colourKey] end
                if not hasCustom then return true, firstMatch end
            end
        end
    end
    return firstMatch ~= nil, firstMatch or "unknown"
end
function ns.KnownGUID(guid, unit, db)
    if not ns.IsReadable(guid) then return false, "owner unavailable" end
    if guid and guid == UnitGUID("player") then return true, "self" end
    local recognised, reason, colour = ns.AutoRecognition(guid, unit, db, guid and db.known[guid] ~= nil)
    if guid and db.known[guid] then return true, "remembered", colour end
    return recognised, reason, colour
end
function ns.Known(unit, db)
    return ns.KnownGUID(ns.Identity(unit), unit, db)
end
function ns.DisplayName(unit, db)
    local guid, name = ns.Identity(unit)
    local record = guid and db.known[guid]
    if record and record.nickname and record.nickname ~= "" then return record.nickname end
    if db.options.useRPNames and AddOn_TotalRP3 and AddOn_TotalRP3.Player then
        local ok, rpName = pcall(function()
            return AddOn_TotalRP3.Player.CreateFromUnit(unit):GetRoleplayingName()
        end)
        if ok and ns.IsReadable(rpName) and type(rpName) == "string" and rpName ~= "" then return rpName end
    end
    return name or (record and record.name)
end

function ns.GuildName(unit)
    if type(GetGuildInfo) ~= "function" then return nil end
    local ok, guild = pcall(GetGuildInfo, unit)
    if ok and ns.IsReadable(guild) and type(guild) == "string" and guild ~= "" then return guild end
end

function ns.TRPRelationByGUID(guid)
    if not TRP3_NameUtil or not TRP3_API then return false end
    local id = TRP3_NameUtil.GetQualifiedNameByGUID(guid)
    local profileID = id and TRP3_API.register.getUnitIDProfileID(id)
    local relation = profileID and TRP3_API.register.relation.getRelation(profileID)
    return relation and relation.id and relation.id ~= "NONE" and relation.id ~= "" or false
end

function ns.CompanionOwner(unit)
    local ownerGUID
    if type(UnitOwnerGUID) == "function" then
        local ok, value = pcall(UnitOwnerGUID, unit)
        if ok and ns.IsReadable(value) and type(value) == "string" and value ~= "" then ownerGUID = value end
    end
    if ownerGUID then
        -- NPC-owned creatures are not another player's companions.
        if not ownerGUID:match("^Player%-") then return nil, nil, false end
        local ownerUnit
        if type(UnitTokenFromGUID) == "function" then
            local ok, value = pcall(UnitTokenFromGUID, ownerGUID)
            if ok and ns.IsReadable(value) and type(value) == "string" then ownerUnit = value end
        end
        return ownerGUID, ownerUnit, true
    end
    -- If ownership is missing/restricted, confirmed player companions stay
    -- hidden rather than falling back to the ordinary NPC name display.
    if Check(UnitIsOwnerOrControllerOfUnit, "player", unit) then return UnitGUID("player"), "player", true end
    local companion = Check(UnitIsOtherPlayersPet, unit) or Check(UnitIsOtherPlayersBattlePet, unit)
        or Check(UnitIsMinion, unit)
    return nil, nil, companion
end

function ns.Classify(unit, options)
    if not unit then return false end
    if ns.IsPlayer(unit) then
        if UnitIsUnit(unit, "player") then return false end
        return options.affectEnemies or UnitIsFriend("player", unit)
    end
    local ownerGUID, ownerUnit, companion = ns.CompanionOwner(unit)
    if not companion then return false end
    return options.affectEnemies or UnitIsFriend("player", unit), ownerGUID, ownerUnit, true
end

function ns.CompanionName(unit)
    local name = (UnitNameUnmodified or UnitName)(unit)
    if ns.IsReadable(name) and type(name) == "string" and name ~= "" then return name end
end
