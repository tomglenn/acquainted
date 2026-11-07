local _, ns = ...
local settings = {}
ns.GameSettings = settings
settings.required = {}
function settings.Initialize(db)
    -- Overrides belong to the client session, not one character. Keep cleanup
    -- ownership account-wide so character switching can release leftovers too.
    AcquaintedRuntime = AcquaintedRuntime or {}
    AcquaintedRuntime.temporary = AcquaintedRuntime.temporary or db.temporary or {}
    settings.temporary = AcquaintedRuntime.temporary
    settings.userControlsNamesOnly = AcquaintedRuntime.nameOnlyUserControlled == true
    settings.observedNamesOnly, settings.pendingNamesOnly = {}, {}
    db.temporary = nil
end
local function Read(key)
    local ok, value = pcall(C_CVar.GetCVar, key)
    if ok then return value end
end
local nameOnlyKeys = { "nameplateShowOnlyNameForFriendlyPlayerUnits", "nameplateShowOnlyNames" }
local function NameOnlyKey(key)
    if type(key) ~= "string" then return end
    for _, supported in ipairs(nameOnlyKeys) do
        if key:lower() == supported:lower() then return supported end
    end
end
function settings.ObserveNamesOnly(key, value)
    key = NameOnlyKey(key)
    if not key then return end
    if type(value) == "boolean" then value = value and "1" or "0"
    elseif type(value) == "number" then value = tostring(value) end
    if value ~= "0" and value ~= "1" then value = Read(key) end
    if value == nil or value == settings.observedNamesOnly[key] then return end
    settings.observedNamesOnly[key] = value
    settings.userControlsNamesOnly = true
    AcquaintedRuntime.nameOnlyUserControlled = true
    if settings.temporary[key] then settings.pendingNamesOnly[key] = true end
end
function settings.WatchNamesOnly(callback)
    -- Blizzard reports the user's requested value here even when a temporary
    -- override still masks the saved value. Observe only; cleanup is deferred.
    if not Settings or not Settings.SetOnValueChangedCallback then return end
    for _, key in ipairs(nameOnlyKeys) do
        if Read(key) ~= nil then
            Settings.SetOnValueChangedCallback(key, function(_, _, value) callback(key, value) end)
        end
    end
end
function settings.RefreshNamesOnly()
    for _, key in ipairs(nameOnlyKeys) do settings.ObserveNamesOnly(key, Read(key)) end
    if InCombatLockdown() then return true end
    for key in pairs(settings.pendingNamesOnly) do
        local record = settings.temporary[key]
        if record then
            local current = Read(key)
            if current == nil then return false, "Could not read " .. key end
            if current == record.value then
                local ok, result = pcall(C_CVar.RemoveTempCVar, key)
                if not ok or result == false then return false, "Could not release temporary " .. key end
            end
            settings.temporary[key] = nil
        end
        settings.pendingNamesOnly[key] = nil
        settings.observedNamesOnly[key] = Read(key)
    end
    return true
end
function settings.NamesOnlyPending()
    return next(settings.pendingNamesOnly) ~= nil
end
-- Persistent writes are reserved for recovery records from versions before 0.6.0.
local function RecoverLegacy(key, value)
    local ok, err = pcall(C_CVar.SetCVar, key, value)
    if not ok then ns.Error(err); return false end
    if Read(key) ~= value then ns.Error("WoW did not accept " .. key); return false end
    return true
end
function settings.Desired(options, db)
    local desired = {}
    if ns.NativeSettingsReason() or ns.UseOverlay(options) then return desired end
    db = db or ns.db
    local function Original(key)
        if db and settings.temporary[key] then return settings.temporary[key].original end
        return Read(key)
    end
    local function Pick(names, value, required)
        for _, key in ipairs(names) do
            if Read(key) ~= nil then desired[key] = value; return key end
        end
        if required then error("Required name setting unavailable: " .. names[1]) end
    end
    local friendly = Pick({ "nameplateShowFriendlyPlayers", "nameplateShowFriends" }, "1", true)
    -- Frames are needed for custom labels. If we introduced them, request text
    -- only; if the player already wanted friendly plates, preserve their bars.
    if Original(friendly) == "0" and not settings.userControlsNamesOnly then
        Pick({ "nameplateShowOnlyNameForFriendlyPlayerUnits", "nameplateShowOnlyNames" }, "1", true)
    end
    -- Both existing friendly plates and newly enabled ones need persistent
    -- world anchors outside instances. This is an override, not a saved preference.
    Pick({ "nameplateShowAll" }, "1", true)
    Pick({ "UnitNameFriendlyPlayerName" }, "0", true)
    Pick({ "nameplateShowFriendlyPlayerMinions", "nameplateShowFriendlyMinions" }, "1")
    for _, key in ipairs({ "UnitNameFriendlyPetName", "UnitNameFriendlyMinionName", "UnitNameFriendlyGuardianName",
        "UnitNameFriendlyTotemName", "UnitNameCompanionName" }) do Pick({ key }, "0") end
    -- Modern clients share this control between critters and cosmetic pets.
    -- Suppress it too so a vanity pet cannot reveal an unknown owner.
    Pick({ "UnitNameNonCombatCreatureName" }, "0")
    Pick({ "UnitNameFocused" }, "0")
    Pick({ "UnitNameTargeted" }, "0")
    if options.affectEnemies then
        Pick({ "UnitNameEnemyPlayerName" }, "0", true)
        for _, key in ipairs({ "UnitNameEnemyPetName", "UnitNameEnemyMinionName", "UnitNameEnemyGuardianName",
            "UnitNameEnemyTotemName" }) do Pick({ key }, "0") end
    end
    return desired
end
-- Temporary overrides are shared by all addons. Only remove a value that still
-- matches ours; a different current value belongs to the user or another addon.
local function ReleaseTemporary()
    local success = true
    for key, record in pairs(settings.temporary) do
        local current = Read(key)
        if current == nil then
            ns.Error("Could not read " .. key .. "; temporary cleanup will retry.")
            success = false
        elseif current ~= record.value then
            settings.temporary[key] = nil
        elseif type(C_CVar.RemoveTempCVar) ~= "function" then
            ns.Error("Temporary name settings cannot be removed on this client.")
            success = false
        else
            local ok, result = pcall(C_CVar.RemoveTempCVar, key)
            if ok and result ~= false then settings.temporary[key] = nil
            else ns.Error(ok and ("WoW did not release " .. key) or result); success = false end
        end
    end
    return success
end
local function RestoreLegacy(db)
    for key, original in pairs(db.restore) do
        if Read(key) == original or RecoverLegacy(key, original) then db.restore[key] = nil end
    end
    return next(db.restore) == nil
end
function settings.HasPending(db)
    return next(db.restore) ~= nil or next(settings.temporary) ~= nil
end
function settings.CheckApplied()
    for key, value in pairs(settings.required) do
        if Read(key) ~= value then return false, key end
    end
    return true
end
function settings.Apply(db, options)
    if InCombatLockdown() then return false, "combat" end
    settings.required = {}
    -- Clear surviving overrides (including across /reload) before reading the
    -- saved baseline. Recover old persistent writes before taking any new ones.
    if not ReleaseTemporary() or not RestoreLegacy(db) then return false end
    settings.pendingNamesOnly = {}
    for _, key in ipairs(nameOnlyKeys) do settings.observedNamesOnly[key] = Read(key) end
    local desired = settings.Desired(options, db)
    if next(desired) == nil then return true end
    if type(C_CVar.SetTempCVar) ~= "function" or type(C_CVar.RemoveTempCVar) ~= "function" then
        ns.Error("This client does not support temporary name settings. Use overlay mode or update the client.")
        return false
    end
    -- Record ownership before writing so partial failures remain removable.
    -- These originals guide display policy; cleanup removes the override rather
    -- than writing the original back over a user's newer saved preference.
    for key, value in pairs(desired) do
        local original = Read(key)
        if original ~= value then settings.temporary[key] = { original = original, value = value } end
    end
    for key, record in pairs(settings.temporary) do
        local ok, err = pcall(C_CVar.SetTempCVar, key, record.value)
        if not ok or err == false then ns.Error(ok and ("WoW rejected temporary " .. key) or err); return false end
        if Read(key) ~= record.value then ns.Error("WoW did not accept temporary " .. key); return false end
    end
    for _, key in ipairs(nameOnlyKeys) do settings.observedNamesOnly[key] = Read(key) end
    for key, value in pairs(desired) do
        if not NameOnlyKey(key) then settings.required[key] = value end
    end
    return true
end
function settings.NamesOnly()
    return (Read("nameplateShowOnlyNameForFriendlyPlayerUnits") or Read("nameplateShowOnlyNames")) == "1"
end
function settings.IntroducedCompanionPlates()
    -- Enabling the parent friendly-plate switch also introduces companion
    -- plates when their child switch was saved on but previously inactive.
    for _, key in ipairs({ "nameplateShowFriendlyPlayers", "nameplateShowFriends",
        "nameplateShowFriendlyPlayerMinions", "nameplateShowFriendlyMinions" }) do
        local record = settings.temporary[key]
        if record and record.original == "0" and record.value == "1" and Read(key) == "1" then return true end
    end
    return false
end
function settings.Restore(db)
    settings.required = {}
    if InCombatLockdown() then return false end
    -- Do not expose an old persistent baseline until our runtime overrides are
    -- gone, and retain failed cleanup for the next out-of-combat service pass.
    if not ReleaseTemporary() then return false end
    settings.pendingNamesOnly = {}
    return RestoreLegacy(db)
end
