local addonName, ns = ...
local events = CreateFrame("Frame")
local states = setmetatable({}, { __mode = "k" })
local db, active, suspended, stopping, servicing, queued, failed
local needsSetup, lastError = true, nil
local appliedNativeSettings
local toggledAcquaintances = {}
ns.version = "0.7.4"
function ns.Say(text) DEFAULT_CHAT_FRAME:AddMessage("|cff80d8c0Acquainted:|r " .. text) end
function ns.Error(err)
    if not lastError then
        lastError = tostring(err)
        ns.Say("A compatibility error was recorded. /acq status for details.")
    end
end
local function CanTouch(frame) return frame and not (frame.IsForbidden and frame:IsForbidden()) end
local function SetNameAlpha(state, value)
    if not CanTouch(state.plate) or not CanTouch(state.frame) or not CanTouch(state.nativeName) then return false end
    local ok, err = pcall(state.nativeName.SetAlpha, state.nativeName, value)
    if not ok then ns.Error(err) end
    return ok
end
local function RestoreName(state)
    if state.masked and CanTouch(state.plate) and CanTouch(state.frame) and CanTouch(state.nativeName) then
        local observed = state.nativeName:GetAlpha()
        if ns.IsReadable(observed) and observed ~= 0 then state.nameAlpha = observed end
        if SetNameAlpha(state, state.nameAlpha) then state.masked = false end
    end
end
local function SetCompanionAlpha(state, region, value)
    if not CanTouch(state.plate) or not CanTouch(state.frame) or not CanTouch(region) then return false end
    local ok, err = pcall(region.SetAlpha, region, value)
    if not ok then ns.Error(err) end
    return ok
end
local function RestoreCompanionVisuals(state)
    for region, record in pairs(state.companionMasks) do
        if CanTouch(state.frame) and CanTouch(region) then
            local observed = region:GetAlpha()
            if ns.IsReadable(observed) and observed ~= 0 then record.alpha = observed end
            if SetCompanionAlpha(state, region, record.alpha) then state.companionMasks[region] = nil end
        end
    end
end
local function MaskCompanionVisuals(state)
    local frame = state.frame
    -- Only plates introduced for friendly companion names reach this path.
    -- Never mask a player UnitFrame or an already-enabled companion health bar.
    local regions = { frame.HealthBarsContainer or frame.healthBar, frame.LevelFrame, frame.PlayerLevelDiffFrame }
    for _, region in pairs(regions) do
        if CanTouch(region) then
            local observed = region:GetAlpha()
            if ns.IsReadable(observed) then
                local record = state.companionMasks[region]
                if not record then record = { alpha = observed }; state.companionMasks[region] = record
                elseif observed ~= 0 then record.alpha = observed end
                SetCompanionAlpha(state, region, 0)
            end
        end
    end
end
local function RestoreVisual(state)
    state.label:Hide()
    state.guildLabel:Hide()
    RestoreName(state)
    RestoreCompanionVisuals(state)
end
local function RestoreVisuals() for _, state in pairs(states) do RestoreVisual(state) end end
local function Render(plate, visited)
    local state = plate and states[plate]
    if state then visited[state] = true end
    local frame = CanTouch(plate) and (plate.UnitFrame or plate.unitFrame)
    if not CanTouch(plate) or not CanTouch(frame) then
        if state then RestoreVisual(state) end
        return
    end
    local unit = plate.namePlateUnitToken or frame.unit
    local ok, manage, ownerGUID, ownerUnit, companion = pcall(ns.ShouldManage, unit, db.options)
    if not ok then ns.Error(manage) end
    if not active or not ok or not manage then
        if state then RestoreVisual(state) end
        return
    end
    if not state then
        -- A separate child draws above replacement plates without changing them.
        local overlay = CreateFrame("Frame", nil, plate)
        overlay:SetAllPoints(plate)
        local label = overlay:CreateFontString(nil, "OVERLAY")
        local guildLabel = overlay:CreateFontString(nil, "OVERLAY")
        state = { frame = frame, plate = plate, overlay = overlay, label = label, guildLabel = guildLabel, companionMasks = {} }
        states[plate] = state
        visited[state] = true
    end
    state.label:Hide()
    state.guildLabel:Hide()
    local overlayOnly = ns.UseOverlay(db.options) or plate.unitFrame ~= nil
    local nativeName = not overlayOnly and frame.name or nil
    if state.frame ~= frame or state.nativeName ~= nativeName then
        RestoreVisual(state)
        -- Do not forget a pending restoration on an inaccessible old region.
        if state.masked or next(state.companionMasks) then return end
        state.frame, state.nativeName = frame, nativeName
    end
    state.unit = unit
    local anchor = overlayOnly and plate.unitFrame or plate
    local levelFrame = overlayOnly and plate.unitFrame or frame
    if CanTouch(levelFrame) then state.overlay:SetFrameLevel(levelFrame:GetFrameLevel() + 10) end
    if nativeName then
        if not CanTouch(nativeName) then return end
        local observed = nativeName:GetAlpha()
        if not ns.IsReadable(observed) then return end
        if not state.masked or observed ~= 0 then state.nameAlpha = observed end
        if not SetNameAlpha(state, 0) then return end
        state.masked = true
    elseif not overlayOnly then
        -- Unknown or restricted native layouts retain their original display.
        return
    end
    local friendly = UnitIsFriend("player", unit)
    if companion and not overlayOnly and ns.IsReadable(friendly) and friendly and ns.GameSettings.IntroducedCompanionPlates() then
        MaskCompanionVisuals(state)
    else
        RestoreCompanionVisuals(state)
    end
    local known, name
    if companion then
        known = db.options.showPetNames and ns.KnownGUID(ownerGUID, ownerUnit, db)
        name = known and ns.CompanionName(unit)
    else
        known = ns.Known(unit, db)
        -- Anonymous modes must not depend on the player's name being accessible.
        if (known and not db.options.hideMet) or (not known and not db.options.hideUnmet and db.options.unmetDisplay == "name") then
            name = ns.DisplayName(unit, db)
        end
        name = ns.PlayerLabel(known, db.options, name)
    end
    -- Companion visibility remains independent of the player Hide controls.
    if not name or name == "" then return end
    local guild = not companion and ns.ShowGuild(known, db.options) and ns.GuildName(unit)
    local fontSize, height, r, g, b = ns.Appearance(known, db.options)
    local guildSize = math.max(8, math.floor(fontSize * 0.8))
    local health = frame.healthBar or (frame.HealthBarsContainer and frame.HealthBarsContainer.healthBar) or frame.HealthBarsContainer
    local namesOnly = not companion and ns.IsReadable(friendly) and friendly and ns.GameSettings.NamesOnly()
    if not overlayOnly and not namesOnly and not next(state.companionMasks) and CanTouch(health) and health:IsShown() then
        anchor = health
        height = math.max(guild and guildSize + 6 or 4, height)
    end
    state.label:SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")
    state.label:ClearAllPoints()
    state.label:SetPoint("BOTTOM", anchor or plate, "TOP", 0, height)
    state.label:SetTextColor(r, g, b)
    state.label:SetText(ns.WithoutColourCodes(name))
    state.label:Show()
    if guild then
        state.guildLabel:SetFont(STANDARD_TEXT_FONT, guildSize, "OUTLINE")
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
        local state = CanTouch(plate) and states[plate]
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
    local wasActive, hadRestore, wasNativeReason, wasFailed = active, ns.GameSettings.HasPending(db), ns.nativeSettingsReason, failed
    servicing = true
    local ok, err = pcall(function()
        ns.nativeSettingsReason = ns.NativeSettingsReason()
        local nativeSettings = ns.UseOverlay(db.options) or ns.nativeSettingsReason ~= nil
        if appliedNativeSettings ~= nativeSettings then needsSetup = true end
        local enabled = db.options.enabled and not suspended and not failed
        if enabled and (not active or needsSetup) then
            -- Timer only: settings callbacks must finish before any CVar write.
            local applied, reason = ns.GameSettings.Apply(db, db.options)
            if applied then active, needsSetup, appliedNativeSettings = true, false, nativeSettings
            elseif reason ~= "combat" then
                active, failed = false, true
                ns.GameSettings.Restore(db)
                ns.Say("Could not apply name settings; filtering stopped. /acq status")
            end
        elseif not enabled then
            active = false
            RestoreVisuals()
            ns.GameSettings.Restore(db)
        end
        if active then
            if not nativeSettings then
                local refreshed, err = ns.GameSettings.RefreshNamesOnly()
                if not refreshed then error(err) end
            end
            local applied, key = ns.GameSettings.CheckApplied()
            if not applied then error(key .. " changed outside Acquainted. Filtering stopped to preserve the other setting; /acq setup to retry.") end
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
    if ns.RefreshSettings and (wasActive ~= active or hadRestore ~= ns.GameSettings.HasPending(db) or wasNativeReason ~= ns.nativeSettingsReason
        or wasFailed ~= failed or ns.lastShownStatus ~= ns.DisplayStatus()) then ns.RefreshSettings() end
end
function ns.Queue()
    if not db or queued or stopping or servicing then return end
    queued = true
    C_Timer.After(0, function() queued = false; Service() end)
end
function ns.SetOption(key, value)
    if (key == "enabled" or key == "affectEnemies" or key == "overlayOnly") and InCombatLockdown() then
        ns.Say("Finish combat first so your game settings can be restored.")
        return false
    end
    value = ns.NormalizeOption(key, value)
    if value == nil then return false end
    if key == "enabled" and not value and ns.CloseColourPicker then ns.CloseColourPicker() end
    db.options[key] = value
    if key == "enabled" or key == "affectEnemies" or key == "overlayOnly" then needsSetup, failed = true, false end
    ns.Queue()
    if ns.RefreshSettings then ns.RefreshSettings() end
    return true
end
function ns.ResetAppearance(which)
    local keys
    if which == "met" then keys = { "fontSize", "nameOffset", "metColour" }
    elseif which == "unmet" then keys = { "unmetFontSize", "unmetNameOffset", "unmetColour" }
    elseif which == "all" then
        keys = { "fontSize", "nameOffset", "metColour", "unmetFontSize", "unmetNameOffset", "unmetColour", "hideMet", "hideUnmet", "unmetDisplay", "showGuildName", "showUnmetGuildName" }
    else return false end
    if ns.FinishSettingsInput then ns.FinishSettingsInput() end
    if ns.CloseColourPicker then ns.CloseColourPicker() end
    for _, key in ipairs(keys) do db.options[key] = ns.defaults[key] end
    ns.Queue()
    if ns.RefreshSettings then ns.RefreshSettings() end
    return true
end
function ns.ClearRememberedUndo()
    toggledAcquaintances = {}
end
function ns.PeopleChanged()
    ns.peopleRevision = (ns.peopleRevision or 0) + 1
    ns.Queue()
    if ns.RefreshSettings then ns.RefreshSettings() end
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
    ns.PeopleChanged()
end
function ns.RememberTarget(forget, nickname)
    local accessible, isOther = pcall(function()
        return ns.IsPlayer("target") and not UnitIsUnit("target", "player")
    end)
    if not accessible or not isOther then ns.Say("Target another player first."); return end
    local ok, guid, name = pcall(ns.Identity, "target")
    if not ok or not guid or not name then ns.Say("That player's identity is not available yet."); return end
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
function ns.DisplayStatus()
    local pending = ns.GameSettings.HasPending(db)
    if not db.options.enabled then
        return pending and "Off · restoring original settings when combat ends." or "Off · original name settings restored."
    end
    if suspended or stopping then return "Disabled in the addon list · filtering stopped." end
    if failed then return "Filtering stopped · /acq status for details." end
    if not active then return InCombatLockdown() and "Waiting for combat to end before enabling name displays." or "Preparing name displays…" end
    if ns.GameSettings.NamesOnlyPending() and InCombatLockdown() then return "Waiting for combat to finish applying Show only name." end
    if ns.nativeSettingsReason then
        return pending and "Instance · temporary settings cleanup pending until combat ends." or "Instance · styling accessible existing nameplates."
    end
    return "Changes apply immediately · saved game preferences are unchanged."
end
function ns.Forget(guid)
    toggledAcquaintances[guid] = nil
    db.known[guid] = nil
    ns.PeopleChanged()
end
function ns.SetNickname(guid, nickname)
    local record = db.known[guid]
    if not record or type(nickname) ~= "string" then return false end
    nickname = nickname:match("^%s*(.-)%s*$")
    record.nickname = nickname ~= "" and nickname or nil
    toggledAcquaintances[guid] = nil
    ns.PeopleChanged()
    return true
end
local function Status()
    ns.Say(ns.version .. " | " .. (active and "enabled" or "disabled") .. " | TRP3 optional")
    if ns.nativeSettingsReason then ns.Say("Instance: using native settings and accessible nameplates; restricted frames are left native.") end
    local count = 0
    for _ in pairs(db.known) do count = count + 1 end
    ns.Say(count .. " people remembered by this character.")
    if next(ns.GameSettings.temporary) then ns.Say("Temporary name settings are active; saved preferences are unchanged.") end
    if next(db.restore) then ns.Say("Recovery of settings from an older version is pending.") end
    if not active and not ns.GameSettings.HasPending(db) then ns.Say("Original game settings restored.") end
    if not active and ns.GameSettings.HasPending(db) then ns.Say("Restoration pending; finish combat and use /acq restore.") end
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
    elseif command == "help" then ns.Say("/acq opens settings. Commands: meet [nickname], forget, togglemet, on, off, toggle, restore, status, setup.")
    elseif ns.OpenSettings then ns.OpenSettings() end
end
local function Start()
    AcquaintedDB = AcquaintedDB or {}
    db = AcquaintedDB
    db.options, db.known, db.restore = db.options or {}, db.known or {}, db.restore or {}
    ns.GameSettings.Initialize(db)
    for key, original in pairs(db.cvars or {}) do
        if db.restore[key] == nil then db.restore[key] = original end
    end
    db.cvars = nil
    if db.options.hideUnmet == nil and type(db.options.showUnmetNames) == "boolean" then
        db.options.hideUnmet = not db.options.showUnmetNames
    end
    db.options.showUnmetNames = nil
    for key, value in pairs(ns.defaults) do
        local normalized = ns.NormalizeOption(key, db.options[key])
        if normalized == nil then normalized = value end
        db.options[key] = normalized
    end
    if db.enabled ~= nil then db.options.enabled = db.enabled; db.enabled = nil end
    db.schema = 4
    ns.db = db
    ns.GameSettings.WatchNamesOnly(function(key, value)
        if active and not servicing and not stopping and db.options.enabled
            and not ns.UseOverlay(db.options) and not ns.NativeSettingsReason() then
            ns.GameSettings.ObserveNamesOnly(key, value)
            ns.Queue()
        end
    end)
    SLASH_ACQUAINTED1 = "/acquainted"
    SLASH_ACQUAINTED2 = "/acq"
    SlashCmdList.ACQUAINTED = Command
    local ok, err = pcall(ns.CreateSettings)
    if not ok then ns.Error(err) end
    ok, err = pcall(ns.RegisterContextMenus)
    if not ok then ns.Error(err) end
    ns.ticker = C_Timer.NewTicker(0.25, Service)
    ns.Queue()
    ns.Say("Welcome to Acquainted (v" .. ns.version .. ")!")
    ns.Say("Type |cffffd100/acq|r for settings. Happy roleplaying!")
end
local function Unload()
    stopping, active = true, false
    if ns.CloseColourPicker then ns.CloseColourPicker() end
    if ns.ticker then ns.ticker:Cancel() end
    RestoreVisuals()
    ns.GameSettings.Restore(db, true)
end
-- Reassert name text and addon-introduced companion visuals only.
-- Player health frames are never modified.
events:SetScript("OnUpdate", function()
    if not active or stopping or suspended or servicing or not db.options.enabled then return end
    for _, state in pairs(states) do
        if state.masked then
            if not CanTouch(state.plate) or not CanTouch(state.frame) or not CanTouch(state.nativeName) then
                state.label:Hide()
                state.guildLabel:Hide()
            else
                local unit = state.plate.namePlateUnitToken or state.frame.unit
                local frame = state.plate.UnitFrame or state.plate.unitFrame
                if ns.UseOverlay(db.options) or state.plate.unitFrame or unit ~= state.unit or frame ~= state.frame or frame.name ~= state.nativeName then
                    RestoreVisual(state)
                else
                    local observed = state.nativeName:GetAlpha()
                    if ns.IsReadable(observed) and observed ~= 0 then
                        state.nameAlpha = observed
                        SetNameAlpha(state, 0)
                    end
                    for region, record in pairs(state.companionMasks) do
                        if CanTouch(region) then
                            local alpha = region:GetAlpha()
                            if ns.IsReadable(alpha) and alpha ~= 0 then
                                record.alpha = alpha
                                SetCompanionAlpha(state, region, 0)
                            end
                        end
                    end
                end
            end
        end
    end
end)
events:SetScript("OnEvent", function(_, event, unit, value)
    if event == "PLAYER_LOGIN" then Start()
    elseif not db then return
    elseif event == "PLAYER_LOGOUT" or event == "ADDONS_UNLOADING" then Unload()
    else
        if event == "CVAR_UPDATE" and active and not servicing and not stopping and db.options.enabled
            and not ns.UseOverlay(db.options) and not ns.NativeSettingsReason() then
            ns.GameSettings.ObserveNamesOnly(unit, value)
        end
        if event == "GROUP_ROSTER_UPDATE" and active and not servicing and not stopping then
            -- Membership changes recognition only; keep the native health bars
            -- and outsider labels in place, including during combat.
            RenderAll()
        end
        if active and not suspended and not servicing and not stopping and db.options.enabled then
            if event == "NAME_PLATE_UNIT_ADDED" and unit then
                -- Render a newly assigned plate in this event, before the next
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
    "GROUP_ROSTER_UPDATE", "UNIT_PET", "CVAR_UPDATE" }) do events:RegisterEvent(event) end
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
