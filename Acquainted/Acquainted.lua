local addonName, ns = ...
local events = CreateFrame("Frame")
local states = setmetatable({}, { __mode = "k" })
local db, active, suspended, stopping, servicing, queued, failed
local needsSetup, lastError = true, nil
local toggledAcquaintances = {}
ns.version = "0.3.2"
function ns.Say(text) DEFAULT_CHAT_FRAME:AddMessage("|cff80d8c0Acquainted:|r " .. text) end
function ns.Error(err)
    if not lastError then
        lastError = tostring(err)
        ns.Say("A compatibility error was recorded. /acquainted status for details.")
    end
end
local function CanTouch(frame) return frame and not (frame.IsForbidden and frame:IsForbidden()) end
local function SetAlpha(state, value)
    local ok, err = pcall(state.frame.SetAlpha, state.frame, value)
    if not ok then ns.Error(err) end
    return ok
end
local function RestoreVisual(state)
    if not CanTouch(state.frame) then return end
    state.label:Hide()
    state.guildLabel:Hide()
    if state.masked and CanTouch(state.frame) then
        local observed = state.frame:GetAlpha()
        if ns.IsReadable(observed) and observed ~= 0 then state.alpha = observed end
        if SetAlpha(state, state.alpha) then state.masked = false end
    end
end
local function RestoreVisuals() for _, state in pairs(states) do RestoreVisual(state) end end
local function Render(plate, visited)
    if not CanTouch(plate) or not CanTouch(plate.UnitFrame) then return end
    local frame = plate.UnitFrame
    local state = states[frame]
    if state then visited[state] = true end
    local unit = plate.namePlateUnitToken or frame.unit
    local ok, manage, ownerGUID, ownerUnit, companion = pcall(ns.ShouldManage, unit, db.options)
    if not ok then ns.Error(manage) end
    if not active or not ok or not manage then
        if state then RestoreVisual(state) end
        return
    end
    if not state then
        -- Text is a sibling of UnitFrame, so it can show without Blizzard's bars.
        local label = plate:CreateFontString(nil, "OVERLAY")
        local guildLabel = plate:CreateFontString(nil, "OVERLAY")
        state = { frame = frame, label = label, guildLabel = guildLabel, alpha = frame:GetAlpha() }
        states[frame] = state
        visited[state] = true
    elseif state.masked then
        local observed = frame:GetAlpha()
        if ns.IsReadable(observed) and observed ~= 0 then state.alpha = observed end
    else state.alpha = frame:GetAlpha() end
    state.label:Hide()
    state.guildLabel:Hide()
    state.unit = unit
    if not SetAlpha(state, 0) then return end
    state.masked = true
    local known, name
    if companion then
        known = db.options.showPetNames and ns.KnownGUID(ownerGUID, ownerUnit, db)
        name = known and ns.CompanionName(unit)
    else
        known = ns.Known(unit, db)
        if known or db.options.showUnmetNames then name = ns.DisplayName(unit, db) end
    end
    -- Unmet player names can be styled, but unknown owners' pets remain hidden.
    if not known and (companion or not db.options.showUnmetNames) then return end
    if not name or name == "" then return end
    local fontSize, height, r, g, b = ns.Appearance(known, db.options)
    state.label:SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")
    state.label:ClearAllPoints()
    state.label:SetPoint("BOTTOM", plate, "TOP", 0, height)
    state.label:SetTextColor(r, g, b)
    state.label:SetText(ns.WithoutColourCodes(name))
    state.label:Show()
    local guild = known and not companion and db.options.showGuildName and ns.GuildName(unit)
    if guild then
        state.guildLabel:SetFont(STANDARD_TEXT_FONT, math.max(8, math.floor(fontSize * 0.8)), "OUTLINE")
        state.guildLabel:ClearAllPoints()
        state.guildLabel:SetPoint("TOP", state.label, "BOTTOM", 0, -2)
        state.guildLabel:SetTextColor(r, g, b)
        state.guildLabel:SetText("<" .. guild .. ">")
        state.guildLabel:Show()
    end
end
local function RenderPlate(plate, visited)
    local ok, err = pcall(Render, plate, visited or {})
    if not ok then
        ns.Error(err)
        local state = CanTouch(plate) and states[plate.UnitFrame]
        if state then RestoreVisual(state) end
    end
end
local function RenderAll()
    local visited = {}
    for _, plate in ipairs(C_NamePlate.GetNamePlates(false)) do
        RenderPlate(plate, visited)
    end
    for _, state in pairs(states) do if not visited[state] then RestoreVisual(state) end end
end
local function Service()
    if not db or stopping or servicing then return end
    servicing = true
    local ok, err = pcall(function()
        local enabled = db.options.enabled and not suspended and not failed
        if enabled and (not active or needsSetup) then
            -- Timer only: settings callbacks must finish before any CVar write.
            local applied, reason = ns.GameSettings.Apply(db, db.options)
            if applied then active, needsSetup = true, false
            elseif reason ~= "combat" then
                active, failed = false, true
                ns.GameSettings.Restore(db)
                ns.Say("Could not apply name settings; filtering stopped. /acquainted status")
            end
        elseif not enabled then
            active = false
            RestoreVisuals()
            ns.GameSettings.Restore(db)
        end
        RenderAll()
    end)
    if not ok then
        ns.Error(err)
        active, failed = false, true
        RestoreVisuals()
        ns.GameSettings.Restore(db)
    end
    servicing = false
end
function ns.Queue()
    if not db or queued or stopping or servicing then return end
    queued = true
    C_Timer.After(0, function() queued = false; Service() end)
end
function ns.SetOption(key, value)
    if (key == "enabled" or key == "affectEnemies") and InCombatLockdown() then
        ns.Say("Finish combat first so your game settings can be restored.")
        return false
    end
    value = ns.NormalizeOption(key, value)
    if value == nil then return false end
    if key == "enabled" and not value and ns.CloseColourPicker then ns.CloseColourPicker() end
    db.options[key] = value
    if key == "enabled" or key == "affectEnemies" then needsSetup, failed = true, false end
    ns.Queue()
    if ns.RefreshSettings then ns.RefreshSettings() end
    return true
end
function ns.ResetAppearance(which)
    local keys
    if which == "met" then keys = { "fontSize", "nameOffset", "metColour" }
    elseif which == "unmet" then keys = { "unmetFontSize", "unmetNameOffset", "unmetColour" }
    elseif which == "all" then
        keys = { "fontSize", "nameOffset", "metColour", "unmetFontSize", "unmetNameOffset", "unmetColour", "showUnmetNames" }
    else return false end
    if ns.CloseColourPicker then ns.CloseColourPicker() end
    for _, key in ipairs(keys) do db.options[key] = ns.defaults[key] end
    ns.Queue()
    if ns.RefreshSettings then ns.RefreshSettings() end
    return true
end
function ns.SetRemembered(guid, name, forget, nickname)
    if not guid or not name then return end
    toggledAcquaintances[guid] = nil
    if forget then
        db.known[guid] = nil
        ns.Say("Forgot " .. name .. ".")
    else
        db.known[guid] = { name = name, nickname = nickname ~= "" and nickname or nil }
        ns.Say("Remembered " .. name .. ".")
    end
    ns.Queue()
    if ns.RefreshSettings then ns.RefreshSettings() end
end
function ns.RememberTarget(forget, nickname)
    local accessible, isOther = pcall(function()
        return ns.IsPlayer("target") and not UnitIsUnit("target", "player")
    end)
    if not accessible or not isOther then ns.Say("Target another player first."); return end
    local ok, guid, name = pcall(ns.Identity, "target")
    if not ok or not guid then ns.Say("That player's identity is not available yet."); return end
    if forget == "toggle" then
        local previous = db.known[guid]
        if previous then
            ns.SetRemembered(guid, name, true)
            toggledAcquaintances[guid] = previous
        else
            local cached = toggledAcquaintances[guid]
            ns.SetRemembered(guid, name, false, cached and cached.nickname)
        end
        return
    end
    ns.SetRemembered(guid, name, forget, nickname)
end
function ns.IsEnabled()
    return db and db.options.enabled and not suspended and not stopping
end
function ns.Forget(guid)
    toggledAcquaintances[guid] = nil
    db.known[guid] = nil
    ns.Queue()
    if ns.RefreshSettings then ns.RefreshSettings() end
end
local function Status()
    ns.Say(ns.version .. " | " .. (active and "enabled" or "disabled") .. " | TRP3 optional")
    local count = 0
    for _ in pairs(db.known) do count = count + 1 end
    ns.Say(count .. " people remembered by this character.")
    if next(db.restore) then ns.Say("Original game settings are saved for restoration.") end
    if not active and not next(db.restore) then ns.Say("Original game settings restored.") end
    if not active and next(db.restore) then ns.Say("Restoration pending; finish combat and use /acquainted restore.") end
    if lastError then ns.Say("Last error: " .. lastError) end
end
local function Command(text)
    local command, rest = (text or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = command:lower()
    if command == "on" or command == "off" or command == "toggle" then
        ns.SetOption("enabled", command == "on" or (command == "toggle" and not db.options.enabled))
    elseif command == "meet" or command == "remember" then ns.RememberTarget(false, rest)
    elseif command == "forget" then ns.RememberTarget(true)
    elseif command == "togglemet" then ns.RememberTarget("toggle")
    elseif command == "restore" then
        if ns.SetOption("enabled", false) then ns.Say("Restoring your original game settings.") end
    elseif command == "status" then Status()
    elseif command == "setup" then needsSetup, failed = true, false; ns.Queue()
    elseif command == "help" then ns.Say("/acquainted opens settings. Commands: meet [nickname], forget, togglemet, on, off, toggle, restore, status, setup.")
    elseif ns.OpenSettings then ns.OpenSettings() end
end
local function Start()
    AcquaintedDB = AcquaintedDB or {}
    db = AcquaintedDB
    db.options, db.known, db.restore = db.options or {}, db.known or {}, db.restore or {}
    for key, original in pairs(db.cvars or {}) do
        if db.restore[key] == nil then db.restore[key] = original end
    end
    db.cvars = nil
    for key, value in pairs(ns.defaults) do
        local normalized = ns.NormalizeOption(key, db.options[key])
        if normalized == nil then normalized = value end
        db.options[key] = normalized
    end
    if db.enabled ~= nil then db.options.enabled = db.enabled; db.enabled = nil end
    db.schema = 2
    ns.db = db
    SLASH_ACQUAINTED1 = "/acquainted"
    SLASH_ACQUAINTED2 = "/acq"
    SlashCmdList.ACQUAINTED = Command
    local ok, err = pcall(ns.CreateSettings)
    if not ok then ns.Error(err) end
    ok, err = pcall(ns.RegisterContextMenus)
    if not ok then ns.Error(err) end
    ns.ticker = C_Timer.NewTicker(0.25, Service)
    ns.Queue()
    ns.Say("Loaded. /acquainted for settings; /acquainted meet to remember your target.")
end
local function Unload()
    stopping, active = true, false
    if ns.CloseColourPicker then ns.CloseColourPicker() end
    if ns.ticker then ns.ticker:Cancel() end
    RestoreVisuals()
    ns.GameSettings.Restore(db, true)
end
-- WoW can reset a native frame's alpha between our slower policy refreshes.
-- Reassert only existing masks before drawing; never write CVars here or hook
-- native setters (which can recurse through the client's nameplate updates).
events:SetScript("OnUpdate", function()
    if not active or stopping or suspended or servicing or not db.options.enabled then return end
    for _, state in pairs(states) do
        if state.masked and CanTouch(state.frame) then
            local observed = state.frame:GetAlpha()
            if ns.IsReadable(observed) and observed ~= 0 then
                state.alpha = observed
                SetAlpha(state, 0)
            end
        end
    end
end)
events:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_LOGIN" then Start()
    elseif not db then return
    elseif event == "PLAYER_LOGOUT" or event == "ADDONS_UNLOADING" then Unload()
    else
        if active and not suspended and not servicing and not stopping and db.options.enabled then
            if event == "NAME_PLATE_UNIT_ADDED" and unit then
                -- Mask a newly assigned plate in this event, before the next
                -- frame, rather than waiting for the deferred settings service.
                RenderPlate(C_NamePlate.GetNamePlateForUnit(unit, false))
            elseif event == "NAME_PLATE_UNIT_REMOVED" and unit then
                for _, state in pairs(states) do
                    if state.unit == unit then RestoreVisual(state); state.unit = nil end
                end
            end
        end
        ns.Queue()
    end
end)
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_LOGOUT", "ADDONS_UNLOADING", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
    "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_TARGET_CHANGED", "UNIT_NAME_UPDATE",
    "FRIENDLIST_UPDATE", "BN_FRIEND_INFO_CHANGED", "GUILD_ROSTER_UPDATE", "UNIT_GUILD_UPDATE",
    "GROUP_ROSTER_UPDATE", "UNIT_PET" }) do events:RegisterEvent(event) end
-- Lifecycle hooks only. No hooks on any native frame setter.
local function IsOurAddon(name)
    if type(name) == "number" and C_AddOns.GetAddOnName then name = C_AddOns.GetAddOnName(name) end
    return type(name) == "string" and name:lower() == addonName:lower()
end
if C_AddOns and C_AddOns.DisableAddOn then
    hooksecurefunc(C_AddOns, "DisableAddOn", function(name)
        if IsOurAddon(name) then suspended = true; ns.Queue() end
    end)
end
if C_AddOns and C_AddOns.DisableAllAddOns then
    hooksecurefunc(C_AddOns, "DisableAllAddOns", function() suspended = true; ns.Queue() end)
end
if C_AddOns and C_AddOns.EnableAddOn then
    hooksecurefunc(C_AddOns, "EnableAddOn", function(name)
        if IsOurAddon(name) then
            suspended, failed, needsSetup = false, false, true; ns.Queue()
        end
    end)
end
if C_AddOns and C_AddOns.EnableAllAddOns then
    hooksecurefunc(C_AddOns, "EnableAllAddOns", function()
        suspended, failed, needsSetup = false, false, true; ns.Queue()
    end)
end
