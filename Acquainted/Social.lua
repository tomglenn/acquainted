local _, ns = ...
local social = { clubs = {}, communityRevision = 0 }
ns.Social = social
local dirty, membership, friends, friendCount, requested = true, {}, {}, 0, {}
local signature = ""
local membersByClub, memberChanges = {}, {}
local function Read(func, ...)
    if type(func) ~= "function" then return nil end
    local ok, value = pcall(func, ...)
    if ok and ns.IsReadable(value) then return value end
end
local function Plain(value)
    if ns.IsReadable(value) and type(value) == "string" and #value <= 512 then
        return ns.WithoutColourCodes(value):gsub("[\r\n]", " ")
    end
end
function social.Initialize(db)
    local selected = {}
    for id, enabled in pairs(type(db.communities) == "table" and db.communities or {}) do
        if type(id) == "string" and #id <= 100 and enabled == true then selected[id] = true end
    end
    db.communities = selected
    dirty, membership, friends, friendCount, requested = true, {}, {}, 0, {}
    membersByClub, memberChanges = {}, {}
end
function social.MarkDirty() dirty = true end
function social.InvalidateFriends() friends, friendCount = {}, 0 end
function social.MemberChanged(event, clubId, memberId)
    if not ns.IsReadable(clubId) or not ns.IsReadable(memberId) or clubId == nil or memberId == nil then social.MarkDirty(); return end
    local key = tostring(clubId)
    if not ns.db.options.showCommunities or not ns.db.communities[key] then return end
    if not membersByClub[key] then social.MarkDirty(); return end
    memberChanges[key] = memberChanges[key] or { id = clubId, changes = {} }
    memberChanges[key].changes[tostring(memberId)] = { id = memberId, removed = event == "CLUB_MEMBER_REMOVED" }
end
function social.FriendKind(guid)
    if not ns.IsReadable(guid) or type(guid) ~= "string" then return nil end
    local now = (GetTime or GetServerTime or time)()
    local cached = friends[guid]
    if cached and cached.expires > now then return cached.kind end
    local info = Read(C_BattleNet and C_BattleNet.GetAccountInfoByGUID, guid)
    local kind
    if type(info) == "table" and ns.IsReadable(info.isFriend) and info.isFriend == true and ns.IsReadable(info.friendLevel) then
        local level = Enum and Enum.BattleNetFriendLevel
        if level and level.Title ~= nil and ns.IsReadable(info.friendLevel) and info.friendLevel == level.Title then
            kind = "wowFriend"
        else kind = "battleNetFriend" end
    end
    if friendCount >= 1024 then friends, friendCount = {}, 0 end
    if not friends[guid] then friendCount = friendCount + 1 end
    friends[guid] = { kind = kind, expires = now + 1 }
    return kind
end
function social.Refresh()
    if not dirty then
        if not next(memberChanges) then return false end
        local updates = memberChanges
        memberChanges = {}
        for key, update in pairs(updates) do
            local bucket = membersByClub[key]
            if bucket then
                for memberKey, change in pairs(update.changes) do
                    local old = bucket[memberKey]
                    if old then
                        local remaining = (membership[old] or 1) - 1
                        membership[old] = remaining > 0 and remaining or nil
                    end
                    local info = not change.removed and Read(C_Club and C_Club.GetMemberInfo, update.id, change.id)
                    local guid = type(info) == "table" and info.guid
                    if ns.IsReadable(guid) and type(guid) == "string" and guid:sub(1, 7) == "Player-" then
                        bucket[memberKey] = guid
                        membership[guid] = (membership[guid] or 0) + 1
                    else bucket[memberKey] = nil end
                end
            end
        end
        return true
    end
    dirty, memberChanges = false, {}
    local clubs, members, keys, byClub = {}, {}, {}, {}
    local api, character = C_Club, Enum and Enum.ClubType and Enum.ClubType.Character
    local subscribed = api and character ~= nil and Read(api.GetSubscribedClubs)
    social.available = type(subscribed) == "table"
    social.selectedCount, social.loadingCount = 0, 0
    for _, info in ipairs(type(subscribed) == "table" and subscribed or {}) do
        if ns.IsReadable(info) and type(info) == "table" and ns.IsReadable(info.clubType) and info.clubType == character
            and ns.IsReadable(info.clubId) and (type(info.clubId) == "string" or type(info.clubId) == "number") then
            local name, key = Plain(info.name), tostring(info.clubId)
            if name and name ~= "" and #key <= 100 then
                local club = { id = info.clubId, key = key, name = name }
                clubs[#clubs + 1] = club
                if ns.db.communities[key] then
                    social.selectedCount = social.selectedCount + 1
                    if ns.db.options.showCommunities then
                        local ready = Read(api.AreMembersReady, club.id)
                        -- Request roster data just as Blizzard's community panel
                        -- does, without changing its selected club or chat stream.
                        if ready ~= true and ns.IsEnabled() and not requested[key] and type(api.FocusMembers) == "function" then
                            local ok, result = pcall(api.FocusMembers, club.id)
                            if ok and result ~= false then requested[key] = true end
                            ready = Read(api.AreMembersReady, club.id)
                        end
                        if ready == true then
                            local ids = Read(api.GetClubMembers, club.id)
                            if type(ids) == "table" then byClub[key] = {}
                            else social.loadingCount = social.loadingCount + 1 end
                            for _, memberId in ipairs(type(ids) == "table" and ids or {}) do
                                if ns.IsReadable(memberId) then
                                    local member = Read(api.GetMemberInfo, club.id, memberId)
                                    local guid = type(member) == "table" and member.guid
                                    if ns.IsReadable(guid) and type(guid) == "string" and guid:sub(1, 7) == "Player-" then
                                        byClub[key][tostring(memberId)] = guid
                                        members[guid] = (members[guid] or 0) + 1
                                    end
                                end
                            end
                        else social.loadingCount = social.loadingCount + 1 end
                    end
                end
            end
        end
    end
    table.sort(clubs, function(a, b)
        local left, right = a.name:lower(), b.name:lower()
        return left == right and a.key < b.key or left < right
    end)
    for _, club in ipairs(clubs) do keys[#keys + 1] = club.key .. "\t" .. club.name end
    local nextSignature = table.concat(keys, "\n")
    if signature ~= nextSignature then social.communityRevision = social.communityRevision + 1; signature = nextSignature end
    for key in pairs(requested) do
        local present = false
        for _, club in ipairs(clubs) do if club.key == key then present = true; break end end
        if not present or not ns.db.communities[key] or not ns.db.options.showCommunities then requested[key] = nil end
    end
    social.clubs, membership, membersByClub = clubs, members, byClub
    return true
end
function social.IsCommunityMember(guid) return (membership[guid] or 0) > 0 end
function ns.SetCommunitySelected(key, selected)
    if type(selected) ~= "boolean" then return false end
    for _, club in ipairs(social.clubs) do
        if club.key == key then
            ns.db.communities[key] = selected and true or nil
            social.MarkDirty()
            ns.Queue()
            if ns.RefreshSettings then ns.RefreshSettings() end
            return true
        end
    end
    return false
end
