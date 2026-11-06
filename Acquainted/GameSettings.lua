local _, ns = ...
local settings = {}
ns.GameSettings = settings
local function Read(key)
    local ok, value = pcall(C_CVar.GetCVar, key)
    if ok then return value end
end
local function Write(key, value)
    local ok, err = pcall(C_CVar.SetCVar, key, value)
    if not ok then ns.Error(err); return false end
    if Read(key) ~= value then ns.Error("WoW did not accept " .. key); return false end
    return true
end
function settings.Desired(options)
    local desired = {}
    local function Pick(names, value, required)
        for _, key in ipairs(names) do
            if Read(key) ~= nil then desired[key] = value; return end
        end
        if required then error("Required name setting unavailable: " .. names[1]) end
    end
    Pick({ "nameplateShowFriendlyPlayers", "nameplateShowFriends" }, "1", true)
    Pick({ "nameplateShowOnlyNameForFriendlyPlayerUnits", "nameplateShowOnlyNames" }, "1", true)
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
function settings.Apply(db, options)
    if InCombatLockdown() then return false, "combat" end
    local desired = settings.Desired(options)
    for key, original in pairs(db.restore) do
        if desired[key] == nil then
            if Write(key, original) then db.restore[key] = nil else return false end
        end
    end
    -- Snapshot every value BEFORE the first write. Never replace this snapshot
    -- with our own temporary settings during a refresh, reload, or upgrade.
    for key in pairs(desired) do
        if db.restore[key] == nil then db.restore[key] = Read(key) end
    end
    local success = true
    for key, value in pairs(desired) do
        if Read(key) ~= value and not Write(key, value) then success = false end
    end
    return success
end
function settings.Restore(db, unloading)
    if InCombatLockdown() and not unloading then return false end
    for key, original in pairs(db.restore) do
        -- Restore EXACT pre-enable values; retain failed writes for recovery.
        if Read(key) == original or Write(key, original) then db.restore[key] = nil end
    end
    return next(db.restore) == nil
end
