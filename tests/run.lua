-- Lua 5.1+ or: pandoc --lua-filter=tests/run.lua -f markdown -t plain /dev/null
local checks = 0
local function check(condition, message)
    assert(condition, message)
    checks = checks + 1
end
local function copy(source)
    local result = {}
    for key, value in pairs(source or {}) do result[key] = type(value) == 'table' and copy(value) or value end
    return result
end
local function world(saved)
    local w = { pending = {}, frames = {}, plates = {}, writes = 0, depth = 0, messages = {}, hooks = {} }
    local env = setmetatable({}, { __index = _G })
    env._G = env
    w.env, w.ns = env, {}
    w.units = {
        stranger = { guid = 'Player-1-A', first = 'Aster', surname = 'Moon', player = true, friend = true, guildName = 'Wayfarers' },
        acquaintance = { guid = 'Player-1-B', first = 'Briar', surname = 'Stone', player = true, friend = true },
        npc = { guid = 'Creature-1-C', first = 'Merchant', player = false, friend = true },
        enemy = { guid = 'Player-1-D', first = 'Dusk', surname = 'Raven', player = true, friend = false },
        player = { guid = 'Player-1-E', first = 'Me', player = true, friend = true },
    }
    w.target = 'stranger'
    local function unit(token) return w.units[token == 'target' and w.target or token] end
    env.UnitGUID = function(token) local u = unit(token); return u and u.guid end
    env.UnitNameUnmodified = function(token) local u = unit(token); if u then return u.first, u.surname end end
    env.UnitName = env.UnitNameUnmodified
    env.GetGuildInfo = function(token) return unit(token) and unit(token).guildName end
    env.UnitIsPlayer = function(token) return unit(token) and unit(token).player or false end
    env.UnitIsHumanPlayer = env.UnitIsPlayer
    env.UnitIsUnit = function(token, other) return unit(token) == unit(other) end
    env.UnitIsFriend = function(_, token) return unit(token) and unit(token).friend or false end
    env.UnitOwnerGUID = function(token) return unit(token) and unit(token).owner end
    env.UnitTokenFromGUID = function(guid)
        if w.ownerMissing then return nil end
        for token, record in pairs(w.units) do if record.guid == guid then return token end end
    end
    env.UnitIsMinion = function(token) return unit(token) and unit(token).minion or false end
    env.UnitIsOtherPlayersPet = function(token) return unit(token) and unit(token).pet or false end
    env.UnitIsOtherPlayersBattlePet = function(token) return unit(token) and unit(token).battlePet or false end
    env.UnitIsOwnerOrControllerOfUnit = function(owner, controlled)
        return unit(owner) and unit(controlled) and unit(controlled).owner == unit(owner).guid
    end
    env.UnitInParty = function(token) return unit(token).party end
    env.UnitInRaid = function(token) return unit(token).raid end
    env.IsGuildMember = function(guid) return w.guild == guid end
    env.C_FriendList = { IsFriend = function(guid) return w.friend == guid end }
    env.C_BattleNet = { GetAccountInfoByGUID = function(guid) if w.bnet == guid then return {} end end }
    env.issecretvalue = function(value) return type(value) == 'table' and value.secret end
    env.InCombatLockdown = function() return w.combat or false end
    env.STANDARD_TEXT_FONT = 'Fonts/FRIZQT__.TTF'
    env.DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) w.messages[#w.messages + 1] = text end }
    env.SlashCmdList = {}
    env.AcquaintedDB = copy(saved)
    local function widget(kind, name, parent, template)
        local f = { kind = kind, name = name, parent = parent, template = template, scripts = {}, alpha = 0.8, shown = true }
        function f:RegisterEvent(event) self.events = self.events or {}; self.events[event] = true; w.events = self end
        function f:SetScript(event, callback) self.scripts[event] = callback end
        function f:HookScript(event, callback)
            local previous = self.scripts[event]
            self.scripts[event] = function(...)
                if previous then previous(...) end
                callback(...)
            end
        end
        function f:SetPoint(...) self.point = { ... } end
        function f:ClearAllPoints() self.point = nil end
        function f:SetWidth(v) self.width = v end
        function f:SetHeight(v) self.height = v end
        function f:SetSize(x, y) self.width, self.height = x, y end
        function f:SetText(v)
            local changed = self.text ~= v
            self.text = v
            if changed and self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, false) end
        end
        function f:GetText() return self.text or '' end
        function f:SetAutoFocus(v) self.autoFocus = v end
        function f:SetMaxLetters(v) self.maxLetters = v end
        function f:SetEnabled(v) self.enabled = v end
        function f:HasFocus() return self.focused or false end
        function f:SetFocus() self.focused = true end
        function f:ClearFocus()
            local focused = self.focused
            self.focused = false
            if focused and self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end
        end
        function f:SetAllPoints() end
        function f:SetClipsChildren(v) self.clipsChildren = v end
        function f:SetColorTexture(...) self.color = { ... } end
        function f:CreateTexture() return widget('Texture', nil, self) end
        function f:SetJustifyH(v) self.justify = v end
        function f:SetFont(path, size, flags) self.font = { path, size, flags }; return true end
        function f:SetTextColor(...) self.color = { ... } end
        function f:SetAlpha(v) assert(not self.forbidden, 'forbidden setter'); self.alpha = v end
        function f:GetAlpha() return self.alpha end
        function f:IsForbidden() return self.forbidden end
        function f:Hide()
            local wasShown = self.shown
            self.shown = false
            if wasShown and self.scripts.OnHide then self.scripts.OnHide(self) end
        end
        function f:Show() self.shown = true end
        function f:IsShown() return self.shown end
        function f:SetShown(v) self.shown = v end
        function f:SetChecked(v) self.checked = v end
        function f:GetChecked() return self.checked end
        function f:SetMinMaxValues(low, high) self.low, self.high = low, high end
        function f:SetValueStep(v) self.step = v end
        function f:SetObeyStepOnDrag() end
        function f:SetValue(v)
            self.value = v
            if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, v) end
        end
        function f:SetScrollChild(child) self.child = child end
        function f:SetVerticalScroll(value) self.scrollOffset = value end
        function f:CreateFontString(_, layer, font)
            local text = widget('FontString', nil, self)
            text.layer, text.fontObject = layer, font
            self.labels = self.labels or {}; self.labels[#self.labels + 1] = text
            return text
        end
        w.frames[#w.frames + 1] = f
        if name then env[name] = f end
        if template == 'OptionsSliderTemplate' then
            f.Text, f.Low, f.High = widget('FontString'), widget('FontString'), widget('FontString')
        end
        return f
    end
    env.CreateFrame = widget
    env.ColorPickerFrame = widget('ColorPicker')
    env.ColorPickerFrame.shown = false
    function env.ColorPickerFrame:SetupColorPickerAndShow(options)
        self.options = options
        self.selected = { options.r, options.g, options.b }
        self:Show()
    end
    function env.ColorPickerFrame:GetColorRGB() return (table.unpack or unpack)(self.selected) end
    env.Settings = {
        RegisterCanvasLayoutCategory = function(frame, title)
            w.category = { frame = frame, title = title, GetID = function() return 71 end }
            return w.category
        end,
        RegisterAddOnCategory = function(category) w.registeredCategory = category end,
        OpenToCategory = function(id) w.opened = id end,
    }
    w.menuCallbacks = {}
    env.Menu = { ModifyMenu = function(tag, callback)
        for _, registered in pairs(w.menuCallbacks) do
            assert(registered ~= callback, 'each menu registration needs a distinct callback')
        end
        w.menuCallbacks[tag] = callback
    end }
    function w:menu(tag, token, forbidden)
        local root = { entries = {} }
        function root:QueueDivider() self.divider = true end
        function root:QueueTitle(title) self.title = title end
        function root:CreateButton(title, callback)
            local entry = { title = title, callback = callback, SetTooltip = function(self, func) self.tooltip = func end }
            self.entries[#self.entries + 1] = entry
            return entry
        end
        local callback = self.menuCallbacks['MENU_UNIT_' .. tag]
        assert(callback, 'missing menu callback: ' .. tag)
        callback({ IsForbidden = function() return forbidden end }, root, { which = tag, unit = token })
        return root
    end
    env.C_Timer = {
        After = function(_, callback) w.pending[#w.pending + 1] = callback end,
        NewTicker = function(_, callback)
            w.ticker = { callback = callback, Cancel = function(self) self.cancelled = true end }
            return w.ticker
        end,
    }
    function w:fire(event, argument)
        local previous = self.inEvent
        self.inEvent = event
        self.events.scripts.OnEvent(self.events, event, argument)
        self.inEvent = previous
    end
    function w:flush()
        local passes = 0
        while #self.pending > 0 do
            passes = passes + 1; assert(passes < 30, 'deferred refresh loop')
            local pending = self.pending; self.pending = {}
            for _, callback in ipairs(pending) do callback() end
        end
    end
    function w:tick() self.ticker.callback(); self:flush() end
    function w:command(text) env.SlashCmdList.ACQUAINTED(text); self:flush() end
    function w:option(key, value) local result = self.ns.SetOption(key, value); self:flush(); return result end
    w.cvars = {
        nameplateShowFriendlyPlayers = '0', nameplateShowOnlyNameForFriendlyPlayerUnits = '0',
        nameplateShowAll = '0', UnitNameFriendlyPlayerName = '1', UnitNameEnemyPlayerName = '1',
        UnitNameFocused = '1', UnitNameTargeted = '1', nameplateForceShowUnitName = '0',
        nameplateShowFriendlyPlayerMinions = '0',
        UnitNameFriendlyPetName = '1', UnitNameFriendlyMinionName = '1', UnitNameFriendlyGuardianName = '1',
        UnitNameFriendlyTotemName = '1', UnitNameCompanionName = '1',
        UnitNameNonCombatCreatureName = '1',
        UnitNameEnemyPetName = '1', UnitNameEnemyMinionName = '1', UnitNameEnemyGuardianName = '1', UnitNameEnemyTotemName = '1',
        untouched = 'original',
    }
    w.original = copy(w.cvars)
    env.C_CVar = {
        GetCVar = function(key) return w.cvars[key] end,
        SetCVar = function(key, value)
            assert(not w.inEvent or w.inEvent == 'PLAYER_LOGOUT' or w.inEvent == 'ADDONS_UNLOADING',
                'CVar write inside event: ' .. tostring(w.inEvent))
            assert(not w.combat, 'combat write blocked')
            w.depth = w.depth + 1; assert(w.depth == 1, 'nested CVar write')
            w.writes = w.writes + 1
            if w.requireSnapshot and not w.snapshotChecked then
                for managed in pairs(w.ns.GameSettings.Desired(w.ns.db.options)) do
                    assert(w.ns.db.restore[managed] ~= nil, 'all originals must be captured before first write')
                end
                w.snapshotChecked = true
            end
            -- Native settings changes can dispatch plate events BEFORE committing.
            w:fire('NAME_PLATE_UNIT_ADDED', 'stranger')
            w:fire('UNIT_NAME_UPDATE', 'stranger')
            if w.ticker then w.ticker.callback() end -- deliberately stress reentry guard
            if w.failKey == key then w.depth = w.depth - 1; error('setting blocked: ' .. key) end
            w.cvars[key] = value
            w.depth = w.depth - 1
        end,
    }
    env.C_AddOns = { DisableAddOn = function() end, EnableAddOn = function() end, DisableAllAddOns = function() end,
        EnableAllAddOns = function() end, GetAddOnName = function(index) return index == 7 and 'Acquainted' or 'other' end }
    env.hooksecurefunc = function(object, method, callback)
        assert(object == env.C_AddOns or (object == env.ColorPickerFrame and method == 'SetupColorPickerAndShow'),
            'must not hook native frame setters')
        w.hooks[#w.hooks + 1] = method
        local original = object[method]
        object[method] = function(...) original(...); callback(...) end
    end
    function w:plate(token)
        local p = widget('Frame')
        p.UnitFrame = widget('Frame', nil, p)
        p.UnitFrame.unit = token
        self.plates[#self.plates + 1] = p
        return p
    end
    env.C_NamePlate = {
        GetNamePlates = function() return w.plates end,
        GetNamePlateForUnit = function(token)
            for _, plate in ipairs(w.plates) do
                if (plate.namePlateUnitToken or plate.UnitFrame.unit) == token then return plate end
            end
        end,
    }
    function w:draw() self.events.scripts.OnUpdate(self.events, 1 / 60) end
    function w:label(p) return p.labels and p.labels[1] end
    function w:load()
        for _, file in ipairs({ 'Policy.lua', 'GameSettings.lua', 'Settings.lua', 'ContextMenus.lua', 'Acquainted.lua' }) do
            local path = 'Acquainted/' .. file
            local chunk
            if setfenv then chunk = assert(loadfile(path)); setfenv(chunk, env)
            else chunk = assert(loadfile(path, 't', env)) end
            chunk('Acquainted', self.ns)
        end
        self:fire('PLAYER_LOGIN')
    end
    function w:restored(message)
        for key, original in pairs(self.original) do check(self.cvars[key] == original, message .. ': ' .. key) end
        check(next(self.ns.db.restore) == nil, message .. ': recovery journal cleared')
    end
    return w
end

local w = world({ options = { showUnmetNames = false } })
w.requireSnapshot = true
local unknown, npc, enemy = w:plate('stranger'), w:plate('npc'), w:plate('enemy')
w:load()
check(w.writes == 0, 'login callback does not write CVars')
w:flush()
check(w.env.SLASH_ACQUAINTED1 == '/acquainted' and w.env.SLASH_ACQUAINTED2 == '/acq', 'new long and short commands registered')
check(w.snapshotChecked, 'complete settings snapshot checked before first write')
check(w.category and w.category.title == 'Acquainted', 'real settings module registered standalone panel')
check(w.registeredCategory == w.category, 'settings category registered with WoW')
check(w.env.TRP3_API == nil, 'standalone test has no TRP3')
check(w.cvars.nameplateShowOnlyNameForFriendlyPlayerUnits == '1', 'friendly plates use names-only click behavior')
check(unknown.UnitFrame.alpha == 0, 'unknown player has no health bar or native name')
check(not w:label(unknown).shown, 'unknown player has no custom overhead name')
check(not unknown.labels[2].shown, 'unknown player guild is also hidden')
check(npc.UnitFrame.alpha == 0.8 and not w:label(npc), 'NPC is untouched')
check(enemy.UnitFrame.alpha == 0.8 and not w:label(enemy), 'enemy untouched by default')
check(w.ns.db.restore.UnitNameFriendlyPlayerName == '1', 'original setting saved')
w:command('meet')
check(w.ns.db.known['Player-1-A'].name == 'Aster Moon', 'can remember non-TRP player with full Forever surname')
check(w:label(unknown).shown and w:label(unknown).text == 'Aster Moon', 'remembered player shows large name')
check(unknown.UnitFrame.alpha == 0, 'known player still has no health bar')
check(w:label(unknown).parent == unknown, 'name is sibling of masked health bar frame')
check(w:label(unknown).font[2] == 22, 'large name font applied')
check(unknown.labels[2].shown and unknown.labels[2].text == '<Wayfarers>', 'known guild shown in standard angle brackets')
check(unknown.labels[2].point[2] == w:label(unknown) and unknown.labels[2].point[3] == 'BOTTOM', 'guild anchored beneath name')
check(unknown.labels[2].font[2] < w:label(unknown).font[2], 'guild uses smaller matching font')
w:option('showGuildName', false)
check(not unknown.labels[2].shown and w:label(unknown).shown, 'guild display option does not hide player name')
w:option('showGuildName', true)
check(unknown.labels[2].shown, 'guild display defaults can be reenabled')
w.units.stranger.guildName = 'New Guild'; w:fire('UNIT_GUILD_UPDATE', 'stranger'); w:flush()
check(unknown.labels[2].text == '<New Guild>', 'guild updates refresh displayed text')
w.units.stranger.guildName = nil; w:tick()
check(not unknown.labels[2].shown and w:label(unknown).shown, 'leaving guild removes only guild line')
w.units.stranger.guildName = 'Wayfarers'; w:tick()
w:command('meet The Herbalist')
check(w:label(unknown).text == 'The Herbalist', 'local nickname overrides game name')
w:option('fontSize', 31)
w:option('nameOffset', 27)
check(w:label(unknown).font[2] == 31 and w:label(unknown).point[5] == 27, 'appearance controls render')
w:command('forget')
check(not w:label(unknown).shown, 'forget hides name again')
check(not unknown.labels[2].shown, 'forget hides guild line too')
w.friend = 'Player-1-A'
check(not w:label(unknown).shown, 'friends hidden until option enabled')
w:option('showFriends', true)
check(w:label(unknown).shown, 'friend option reveals character friends')
w.friend, w.bnet = nil, 'Player-1-A'; w:tick()
check(w:label(unknown).shown, 'friend option reveals Battle.net friends')
w:option('showFriends', false)
check(not w:label(unknown).shown, 'disabling friend option hides unknown friend')
w.guild = 'Player-1-A'; w:option('showGuild', true)
check(w:label(unknown).shown, 'guild option reveals guild member')
w:option('showGuild', false)
check(not w:label(unknown).shown, 'guild option reversible')
w.units.stranger.party = true; w:option('showGroup', true)
check(w:label(unknown).shown, 'group option reveals party member')
w.units.stranger.party, w.units.stranger.raid = nil, true; w:tick()
check(w:label(unknown).shown, 'group option reveals raid member')
w:option('showGroup', false)
check(not w:label(unknown).shown, 'group option reversible')

w.env.TRP3_API = {
    utils = { str = { getUnitID = function() return 'rp-character' end } },
    register = {
        getUnitIDProfileID = function() return 'rp-profile' end,
        relation = { getRelation = function() return { id = w.relation or 'NONE' } end },
    },
}
w.relation = 'NEUTRAL'; w:tick()
check(w:label(unknown).shown, 'optional TRP relation reveals name')
w.env.AddOn_TotalRP3 = { Player = { CreateFromUnit = function()
    return { GetRoleplayingName = function() return 'Aster the Wise' end }
end } }
w:tick(); check(w:label(unknown).text == 'Aster the Wise', 'optional RP display name')
w:option('useRPNames', false)
check(w:label(unknown).text == 'Aster Moon', 'game names selectable with TRP installed')
w:option('useTRPRelations', false)
check(not w:label(unknown).shown, 'TRP recognition separately switchable')
w.env.TRP3_API, w.env.AddOn_TotalRP3 = nil, nil
w:option('affectEnemies', true)
check(enemy.UnitFrame.alpha == 0 and not w:label(enemy).shown, 'opt-in enemy filtering removes bars and unknown names')
w.target = 'enemy'; w:command('meet')
check(w:label(enemy).shown and w:label(enemy).text == 'Dusk Raven', 'enemy known label without health bar')
w:option('affectEnemies', false)
check(enemy.UnitFrame.alpha == 0.8 and not w:label(enemy).shown, 'turning enemy filtering off restores native frame')
check(w.cvars.UnitNameEnemyPlayerName == '1', 'enemy name setting restored when option disabled')
w.target = 'stranger'; w:command('meet')
unknown.UnitFrame:SetAlpha(0.5); w:tick()
check(unknown.UnitFrame.alpha == 0, 'external alpha changes masked on refresh without hooks')
-- User manually changes managed values while active. Original snapshot must win on disable.
w.cvars.UnitNameFriendlyPlayerName = '1'
local writesBefore = w.writes
for _ = 1, 100 do w:fire('NAME_PLATE_UNIT_ADDED'); w:fire('UNIT_NAME_UPDATE') end
check(w.writes == writesBefore, '200 nested UI events cause no inline writes')
check(#w.pending == 1, 'event storm coalesces')
w:flush()
check(w.writes == writesBefore, 'ordinary refresh does not fight WoW settings')
w:command('off')
w:restored('off restores exact originals')
check(unknown.UnitFrame.alpha == 0.5 and not w:label(unknown).shown, 'off restores latest native alpha and removes custom name')
check(not unknown.labels[2].shown, 'off removes custom guild text')
w:command('')
check(w.opened == 71, 'slash command opens native settings page')
-- Click the real settings checkbox and slider callbacks.
local enabledButton
for _, f in ipairs(w.frames) do
    if f.template == 'UICheckButtonTemplate' and f.labels[1].text == 'Enable Acquainted' then enabledButton = f end
end
check(enabledButton ~= nil, 'enable setting exists')
enabledButton:SetChecked(true); enabledButton.scripts.OnClick(enabledButton); w:flush()
check(w.ns.db.options.enabled and unknown.UnitFrame.alpha == 0, 'settings checkbox enables filtering')
w.env.Acquainted_fontSizeSlider.scripts.OnValueChanged(w.env.Acquainted_fontSizeSlider, 29)
w:flush(); check(w:label(unknown).font[2] == 29, 'actual slider callback changes name size')
-- WoW addon-list disable must restore before Lua is unloaded and not reapply.
w.env.C_AddOns.DisableAddOn('Acquainted'); w:flush()
w:restored('addon-list disable restores originals')
check(not w:label(unknown).shown, 'addon-list disable removes custom label')
check(not unknown.labels[2].shown, 'addon-list disable removes guild text')
w:tick(); w:restored('disabled addon does not reactivate on ticker')
w.env.C_AddOns.EnableAddOn('Acquainted'); w:flush()
check(unknown.UnitFrame.alpha == 0, 'addon-list re-enable works')
w.env.C_AddOns.DisableAddOn(7); w:flush()
w:restored('numeric addon-list disable restores originals')
w.env.C_AddOns.EnableAddOn(7); w:flush()
check(unknown.UnitFrame.alpha == 0, 'numeric addon-list re-enable works')
w.env.C_AddOns.DisableAllAddOns(); w:flush()
w:restored('disable all addons restores originals')
w.env.C_AddOns.EnableAllAddOns(); w:flush()
check(unknown.UnitFrame.alpha == 0, 'enable all addons resumes filtering')
w.combat = true
check(not w:option('enabled', false), 'disable refused during combat rather than leaving settings changed')
check(w.ns.db.options.enabled, 'combat refusal keeps enabled checkbox truthful')
w.combat = false
w:command('off'); w:restored('disable after combat restores originals')
w:command('on')
w:fire('PLAYER_LOGOUT')
w:restored('normal logout restores exact originals')
check(w.ticker.cancelled and not w:label(unknown).shown, 'logout cancels work and clears custom visuals')
check(not unknown.labels[2].shown, 'logout clears guild text')

-- Fresh reload, independently saved settings, recovery, failure rollback, and plate reuse.
local fresh = world(copy(w.ns.db))
local freshPlate = fresh:plate('stranger')
fresh:load(); fresh:flush()
check(fresh:label(freshPlate).shown, 'remembered people persist across reload without TRP3')
fresh:command('off'); fresh:restored('post-reload off restores originals')
local recovery = world({ enabled = false, cvars = { UnitNameFriendlyPlayerName = '1', nameplateForceShowUnitName = '0' } })
recovery.cvars.UnitNameFriendlyPlayerName, recovery.cvars.nameplateForceShowUnitName = '0', '1'
recovery:load(); recovery:flush()
recovery:restored('pending settings snapshot is restored')
check(not recovery.ns.db.options.enabled, 'saved disabled preference retained')
local blocked = world()
blocked.failKey = 'UnitNameFriendlyPlayerName'
blocked:load(); blocked:flush()
-- Failed apply is rolled back; the blocked setting was never changed.
blocked:restored('failed activation rolls back temporary settings')
check(blocked.ns.db.options.enabled, 'failed activation does not erase user preference')
local reused = world({ options = { showUnmetNames = false } })
local reusedPlate = reused:plate('stranger')
reused:load(); reused:flush()
reused:command('meet')
reusedPlate.UnitFrame.unit = 'npc'; reused:fire('NAME_PLATE_UNIT_ADDED'); reused:flush()
check(reusedPlate.UnitFrame.alpha == 0.8 and not reused:label(reusedPlate).shown, 'NPC reuse restores frame and removes player label')
check(not reusedPlate.labels[2].shown, 'NPC reuse cannot retain guild text')
reusedPlate.UnitFrame.unit = 'acquaintance'; reused:fire('NAME_PLATE_UNIT_ADDED'); reused:flush()
check(reusedPlate.UnitFrame.alpha == 0 and not reused:label(reusedPlate).shown, 'player reuse cannot inherit previous name')
reusedPlate.UnitFrame.forbidden = true
reused:command('off')
check(reusedPlate.UnitFrame.alpha == 0, 'forbidden frame skipped')
reusedPlate.UnitFrame.forbidden = false; reused:tick()
check(reusedPlate.UnitFrame.alpha == 0.8, 'visual restoration retried when frame accessible')
local delayed = world()
delayed.combat = true; delayed:load(); delayed:flush()
check(delayed.writes == 0 and next(delayed.ns.db.restore) == nil, 'combat login does not snapshot or mutate settings')
delayed.combat = false; delayed:fire('PLAYER_REGEN_ENABLED'); delayed:flush()
check(delayed.cvars.nameplateShowFriendlyPlayers == '1', 'setup runs after combat ends')
delayed:command('off'); delayed:restored('combat-deferred activation restores original baseline')
local disabled = world({ options = { enabled = false } })
disabled:load(); disabled:flush()
check(disabled.writes == 0, 'loading disabled Acquainted makes no game setting changes')
disabled:restored('disabled startup leaves original settings')
local retry = world()
retry:plate('stranger'); retry:load(); retry:flush()
retry.failKey = 'UnitNameFriendlyPlayerName'
retry:command('off')
check(retry.ns.db.restore.UnitNameFriendlyPlayerName == '1', 'failed restoration retains original value')
check(retry.cvars.UnitNameFriendlyPlayerName == '0', 'failed restore is not falsely reported as restored')
check(#retry.pending == 0, 'failed restore with nested native events cannot create infinite deferred loop')
retry.failKey = nil; retry:tick()
retry:restored('restoration retries successfully after restriction clears')
local unload = world()
unload:load(); unload:flush(); unload:fire('ADDONS_UNLOADING')
unload:restored('addons unloading restores originals')
unload:fire('PLAYER_LOGOUT')
unload:restored('double unload notification is harmless')
local lost = world()
lost.cvars.nameplateShowFriendlyPlayers = nil
lost:load(); lost:flush()
check(lost.writes == 0, 'unsupported required CVar fails before changing any settings')
local alias = world()
alias.cvars.nameplateShowFriendlyPlayers = nil
alias.cvars.nameplateShowOnlyNameForFriendlyPlayerUnits = nil
alias.cvars.nameplateShowFriends, alias.cvars.nameplateShowOnlyNames = '0', '0'
alias.original = copy(alias.cvars)
alias:load(); alias:flush()
check(alias.cvars.nameplateShowFriends == '1' and alias.cvars.nameplateShowOnlyNames == '1', 'older CVar names supported')
alias:command('off'); alias:restored('fallback CVar originals restore')
local menus = world()
menus:plate('stranger'); menus:load(); menus:flush()
local menu = menus:menu('PLAYER', 'stranger')
check(menu.title == 'Acquainted' and menu.entries[1].title == 'Meet', 'unknown live player has Meet menu option')
menus.target = 'acquaintance'
menu.entries[1].callback(); menus:flush()
check(menus.ns.db.known['Player-1-A'] and not menus.ns.db.known['Player-1-B'], 'Meet applies to clicked person after target changes')
menu = menus:menu('PLAYER', 'stranger')
check(menu.entries[1].title == 'Forget' and menu.entries[1].tooltip, 'remembered person has Forget with visibility-rule tooltip')
menu.entries[1].callback(); menus:flush()
check(not menus.ns.db.known['Player-1-A'], 'Forget context action removes clicked memory')
check(#menus:menu('PLAYER', 'npc').entries == 0, 'NPC menus get no Meet entry')
check(#menus:menu('PLAYER', 'player').entries == 0, 'self menu gets no Meet entry')
check(#menus:menu('PLAYER', 'stranger', true).entries == 0, 'forbidden menu owner is untouched')
for _, tag in ipairs({ 'PARTY', 'RAID', 'RAID_PLAYER' }) do
    check(menus:menu(tag, 'stranger').entries[1].title == 'Meet', tag .. ' menu supported')
end
local staleMenu = menus:menu('PLAYER', 'stranger')
menus:command('off')
check(#menus:menu('PLAYER', 'stranger').entries == 0, 'disabled Acquainted adds no context menu entries')
staleMenu.entries[1].callback(); menus:flush()
check(not menus.ns.db.known['Player-1-A'], 'stale menu cannot modify memories after addon disabled')
menus:restored('context menu integration preserves disable restoration')
local restrictedGuild = world()
local restrictedPlate = restrictedGuild:plate('stranger')
restrictedGuild:load(); restrictedGuild:flush(); restrictedGuild:command('meet')
restrictedGuild.env.GetGuildInfo = function() return { secret = true } end
restrictedGuild:tick()
check(not restrictedPlate.labels[2].shown and restrictedGuild:label(restrictedPlate).shown, 'restricted guild info cannot break known-name rendering')
local pets = world()
pets.units.petA = { guid = 'Pet-1-A', first = 'Shadow', friend = true, pet = true, owner = 'Player-1-A' }
pets.units.minionA = { guid = 'Creature-1-Imp', first = 'Zigbit', friend = true, minion = true, owner = 'Player-1-A' }
pets.units.battleA = { guid = 'Pet-1-Critter', first = 'Tiny Dragon', friend = true, battlePet = true, owner = 'Player-1-A' }
pets.units.petB = { guid = 'Pet-1-B', first = 'Snow', friend = true, pet = true, owner = 'Player-1-B' }
pets.units.unownedPet = { guid = 'Pet-1-Unknown', first = 'Mystery', friend = true, pet = true }
pets.units.npcMinion = { guid = 'Creature-1-NPCMinion', first = 'Guard Dog', friend = true, minion = true, owner = 'Creature-1-C' }
pets.units.wild = { guid = 'Creature-1-Wild', first = 'Wild Rabbit', friend = true }
pets.units.ownPet = { guid = 'Pet-1-Mine', first = 'My Wolf', friend = true, pet = true, owner = 'Player-1-E' }
pets.units.enemyPet = { guid = 'Pet-1-Enemy', first = 'Fang', friend = false, pet = true, owner = 'Player-1-D' }
local petPlate, minionPlate, battlePlate, otherPet = pets:plate('petA'), pets:plate('minionA'), pets:plate('battleA'), pets:plate('petB')
local orphan, npcMinion, wild, ownPet, enemyPet = pets:plate('unownedPet'), pets:plate('npcMinion'), pets:plate('wild'), pets:plate('ownPet'), pets:plate('enemyPet')
pets:load(); pets:flush()
check(pets.ns.db.options.showPetNames, 'known-owner pet names enabled by default')
check(pets.cvars.UnitNameFriendlyPetName == '0' and pets.cvars.UnitNameFriendlyMinionName == '0', 'plain engine pet/minion names suppressed')
check(pets.cvars.nameplateShowFriendlyPlayerMinions == '1', 'accessible friendly companion plates requested')
for _, plate in ipairs({ petPlate, minionPlate, battlePlate, otherPet, orphan }) do
    check(plate.UnitFrame.alpha == 0 and not pets:label(plate).shown, 'unknown-owner companion has no name or bar')
end
check(npcMinion.UnitFrame.alpha == 0.8 and not pets:label(npcMinion), 'NPC-owned minion unaffected')
check(wild.UnitFrame.alpha == 0.8 and not pets:label(wild), 'wild critter frames not treated as player companions')
check(pets.cvars.UnitNameNonCombatCreatureName == '0', 'shared cosmetic pet/critter engine name setting suppressed')
check(pets:label(ownPet).shown and pets:label(ownPet).text == 'My Wolf', 'own pet owner counts as known')
check(enemyPet.UnitFrame.alpha == 0.8 and not pets:label(enemyPet), 'enemy pet respects opt-in enemy scope')
pets:command('meet')
check(pets:label(petPlate).shown and pets:label(petPlate).text == 'Shadow', 'meeting owner reveals pet name')
check(pets:label(minionPlate).shown and pets:label(minionPlate).text == 'Zigbit', 'meeting owner reveals summoned minion name')
check(pets:label(battlePlate).shown, 'meeting owner reveals cosmetic companion name when its plate exists')
check(not pets:label(otherPet).shown, 'meeting owner does not reveal another player pet')
check(not petPlate.labels[2].shown and not minionPlate.labels[2].shown, 'pet/minion labels do not show owner guild as pet guild')
pets:option('showPetNames', false)
check(not pets:label(petPlate).shown and not pets:label(minionPlate).shown and not pets:label(ownPet).shown, 'option off hides names even for known owners')
check(petPlate.UnitFrame.alpha == 0, 'option off does not expose native health bar/name')
pets:option('showPetNames', true)
check(pets:label(petPlate).shown, 'option on restores known owner companion names')
pets.ownerMissing = true; pets:tick()
check(pets:label(petPlate).shown, 'remembered owner GUID works even without accessible owner unit')
pets:command('forget')
check(not pets:label(petPlate).shown and not pets:label(minionPlate).shown, 'forgetting owner hides companions')
pets.friend = 'Player-1-A'; pets:option('showFriends', true)
check(pets:label(petPlate).shown, 'friend owner rule works without a live owner token')
pets:option('showFriends', false)
pets.guild = 'Player-1-A'; pets:option('showGuild', true)
check(pets:label(petPlate).shown, 'guild owner rule works without a live owner token')
pets:option('showGuild', false)
pets.ownerMissing = false
pets.units.stranger.party = true; pets:option('showGroup', true)
check(pets:label(petPlate).shown, 'group owner rule reveals companion names')
pets:option('showGroup', false)
pets.ownerMissing = true
pets.env.TRP3_NameUtil = { GetQualifiedNameByGUID = function(guid) return guid == 'Player-1-A' and 'owner-rp' end }
pets.env.TRP3_API = { register = {
    getUnitIDProfileID = function(id) return id == 'owner-rp' and 'owner-profile' end,
    relation = { getRelation = function(id) return { id = id == 'owner-profile' and 'NEUTRAL' or 'NONE' } end },
} }
pets:tick()
check(pets:label(petPlate).shown, 'TRP relationship can recognise owner by GUID without visible owner unit')
pets.env.TRP3_NameUtil, pets.env.TRP3_API = nil, nil
pets.ownerMissing = false
pets:command('meet')
pets.units.petA.owner = 'Player-1-B'; pets:tick()
check(not pets:label(petPlate).shown, 'pet ownership changes cannot retain the previous known owner name visibility')
pets.units.petA.owner = 'Player-1-A'; pets:tick()
check(pets:label(petPlate).shown, 'pet ownership change back to known owner refreshes visibility')
pets:command('forget')
pets.units.petA.owner = { secret = true }; pets:tick()
check(not pets:label(petPlate).shown and petPlate.UnitFrame.alpha == 0, 'restricted owner stays hidden')
pets.units.petA.owner = 'Player-1-A'
pets:option('affectEnemies', true)
check(enemyPet.UnitFrame.alpha == 0 and not pets:label(enemyPet).shown, 'unknown enemy pet filtered only when opted in')
pets.target = 'enemy'; pets:command('meet')
check(pets:label(enemyPet).shown, 'known enemy owner reveals enemy companion name')
pets:option('affectEnemies', false)
check(enemyPet.UnitFrame.alpha == 0.8 and pets.cvars.UnitNameEnemyPetName == '1', 'enemy companion setting/frame restored on scope change')
pets:command('off')
pets:restored('pet/minion settings restore exactly on disable')
for _, plate in ipairs({ petPlate, minionPlate, battlePlate, ownPet, orphan }) do
    check(plate.UnitFrame.alpha == 0.8 and not pets:label(plate).shown, 'disable releases companion frame and removes text')
end
check(#pets:menu('PLAYER', 'petA').entries == 0, 'companion cannot be manually met instead of its owner')
local display = world({
    options = { fontSize = 27, nameOffset = 0, showGuild = false, showUnmetNames = false },
    known = { ['Player-1-B'] = { name = 'Briar Stone', nickname = 'The Scholar' } },
})
local strangerDisplay, metDisplay = display:plate('stranger'), display:plate('acquaintance')
display:load(); display:flush()
check(display.ns.db.options.fontSize == 27 and display.ns.db.options.nameOffset == 0, 'upgrade preserves existing met size and zero height')
check(not display.ns.db.options.showUnmetNames and not display:label(strangerDisplay).shown, 'upgrade preserves saved hidden-unmet preference')
check(display.ns.db.options.unmetFontSize == 14 and display.ns.db.options.unmetColour == '999999', 'unmet style defaults to smaller grey text')
local nativeWrites = display.writes
display:option('nameOffset', -90)
display:option('metColour', '#00ff80')
check(display:label(metDisplay).point[5] == -90, 'met name can move below old zero limit')
check(display.ns.db.options.metColour == '00FF80' and display:label(metDisplay).color[2] == 1, 'met colour validates and renders')
check(display.env.Acquainted_nameOffsetSlider.low == -200 and display.env.Acquainted_nameOffsetSlider.high == 100, 'settings slider exposes negative height range')
display.env.Acquainted_nameOffsetSlider.scripts.OnValueChanged(display.env.Acquainted_nameOffsetSlider, -90)
display:flush()
check(display:label(metDisplay).point[5] == -90, 'actual height slider accepts negative positions')
display:option('showUnmetNames', true)
check(display:label(strangerDisplay).shown and display:label(strangerDisplay).font[2] == 14, 'optional unmet name is visible in smaller text')
check(display:label(strangerDisplay).text == 'Aster Moon', 'unmet style displays the player name')
check(math.abs(display:label(strangerDisplay).color[1] - 0.6) < 0.001, 'unmet default text is grey')
check(not strangerDisplay.labels[2].shown, 'unmet display does not reveal guild')
display:option('unmetNameOffset', -120)
display:option('unmetFontSize', 10)
display:option('unmetColour', '6688AA')
check(display:label(strangerDisplay).point[5] == -120 and display:label(strangerDisplay).font[2] == 10, 'unmet height and size are independently adjustable')
check(display:label(metDisplay).point[5] == -90 and display:label(metDisplay).font[2] == 27, 'unmet controls leave met layout unchanged')
check(display.ns.SetOption('metColour', 'not-a-colour') == false, 'invalid colour input rejected')
check(display.ns.SetOption('fontSize', 0/0) == false, 'nonfinite size rejected')
display:option('nameOffset', -1000)
display:option('unmetNameOffset', 1000)
check(display.ns.db.options.nameOffset == -200 and display.ns.db.options.unmetNameOffset == 100, 'height controls enforce expanded bounds')
display:option('fontSize', 1000)
display:option('unmetFontSize', -1000)
check(display.ns.db.options.fontSize == 48 and display.ns.db.options.unmetFontSize == 8, 'font controls enforce supported bounds')

display:command('togglemet')
check(display.ns.db.known['Player-1-A'] and display:label(strangerDisplay).font[2] == 48, 'togglemet meets current target and switches to met style')
check(strangerDisplay.labels[2].shown, 'meeting restores guild line')
display:command('togglemet')
check(not display.ns.db.known['Player-1-A'] and display:label(strangerDisplay).font[2] == 8, 'same togglemet command undoes accidental Meet')
check(not strangerDisplay.labels[2].shown, 'undo switches back to unmet display without guild')
display:option('showUnmetNames', false)
display:command('togglemet'); display:command('togglemet')
check(not display:label(strangerDisplay).shown, 'togglemet also undoes Meet when unmet names are hidden')
display.target = 'npc'; display:command('togglemet')
check(not display.ns.db.known['Creature-1-C'], 'togglemet cannot remember an NPC')
display.target = 'acquaintance'; display:command('togglemet')
check(not display.ns.db.known['Player-1-B'], 'togglemet removes an existing manual acquaintance')
display:command('togglemet')
check(display.ns.db.known['Player-1-B'].nickname == 'The Scholar', 'toggling back restores the previous nickname during this session')
display:command('meet The Scholar')

local function click(worldState, button)
    button.scripts.OnClick(button)
    worldState:flush()
end
local function namedButton(text)
    local names = { ['Reset met style'] = 'Acquainted_ResetMet', ['Reset unmet style'] = 'Acquainted_ResetUnmet', ['Reset name display'] = 'Acquainted_ResetAll' }
    if names[text] then return display.env[names[text]] end
    for _, frame in ipairs(display.frames) do
        if frame.template == 'UIPanelButtonTemplate' and frame.text == text then return frame end
    end
    error('missing button: ' .. text)
end
click(display, display.env.Acquainted_metColourButton)
local picker = display.env.ColorPickerFrame
check(picker.shown and picker.options.hasOpacity == false, 'met colour button opens native RGB picker')
local priorColour = display.ns.db.options.metColour
picker.selected = { 0.2, 0.4, 0.6 }; picker.options.swatchFunc(); display:flush()
check(display.ns.db.options.metColour == '336699', 'picker previews met colour live')
picker:Hide(); picker.options.cancelFunc(); display:flush()
check(display.ns.db.options.metColour == priorColour, 'cancel restores colour from before opening picker')
click(display, display.env.Acquainted_unmetColourButton)
picker.selected = { 0.5, 0.25, 0 }; picker.options.swatchFunc(); display:flush()
check(display.ns.db.options.unmetColour == '804000', 'unmet colour picker controls independent style')
picker:Hide(); display:flush()
check(display.ns.db.options.unmetColour == '804000', 'accept keeps selected colour')
-- A later picker opened by another addon must not be closed by our resets.
picker:Show()
click(display, namedButton('Reset met style'))
check(picker.shown, 'reset does not close another addon colour picker after our session ended')
picker:Hide()
click(display, display.env.Acquainted_metColourButton)
local previousSwatch = picker.options.swatchFunc
picker:SetupColorPickerAndShow({ r = 0, g = 0, b = 0, swatchFunc = function() end })
click(display, namedButton('Reset met style'))
previousSwatch(); display:flush()
check(picker.shown and display.ns.db.options.metColour == 'FFD100', 'another addon taking over an open picker retires our callbacks without closing theirs')
picker:Hide(); display:flush()
check(display.ns.db.options.fontSize == 22 and display.ns.db.options.nameOffset == -40 and display.ns.db.options.metColour == 'FFD100', 'met reset restores met defaults')
check(display.ns.db.options.unmetColour == '804000', 'met reset preserves unmet style')
display:option('showUnmetNames', true)
click(display, namedButton('Reset unmet style'))
check(display.ns.db.options.unmetFontSize == 14 and display.ns.db.options.unmetNameOffset == -40 and display.ns.db.options.unmetColour == '999999', 'unmet reset restores unmet defaults')
check(display.ns.db.options.showUnmetNames, 'style-only reset preserves unmet visibility choice')
click(display, display.env.Acquainted_metColourButton)
local staleCancel = picker.options.cancelFunc
picker.selected = { 1, 0, 0 }; picker.options.swatchFunc(); display:flush()
click(display, namedButton('Reset met style'))
staleCancel(); display:flush()
check(not picker.shown and display.ns.db.options.metColour == 'FFD100', 'reset closes own picker and stale cancel cannot undo defaults')
display:option('fontSize', 30)
display:option('unmetColour', '123456')
display:option('showGuild', true)
click(display, namedButton('Reset name display'))
check(display.ns.db.options.showUnmetNames and display.ns.db.options.fontSize == 22 and display.ns.db.options.unmetColour == '999999', 'full display reset restores both styles and visible-unmet default')
check(display.ns.db.known['Player-1-B'].nickname == 'The Scholar' and display.ns.db.options.showGuild, 'display resets preserve acquaintances, nicknames, and recognition rules')
check(display.writes == nativeWrites, 'all appearance edits, pickers, resets, and togglemet avoid game-setting writes')

display.env.AddOn_TotalRP3 = { Player = { CreateFromUnit = function()
    return { GetRoleplayingName = function() return '|cffff0000Briar|r |cnNORMAL_FONT_COLOR:Stone|r' end }
end } }
display:command('meet') -- clear the manual nickname so the RP name is displayed
display:option('metColour', '00FF00')
check(display:label(metDisplay).text == 'Briar Stone' and display:label(metDisplay).color[2] == 1, 'configured colour overrides embedded RP colour codes')
display:option('showGuild', false)
display:option('showUnmetNames', true)
display.units.stranger.guildName = 'Wayfarers'
display.units.demoPet = { guid = 'Pet-1-Demo', first = 'Shadow', pet = true, friend = true, owner = 'Player-1-A' }
local demoPet = display:plate('demoPet'); display:tick()
check(display:label(strangerDisplay).shown and not display:label(demoPet).shown, 'visible unmet player name does not reveal their pet name')
display:command('off')
check(not display:label(strangerDisplay).shown and not display:label(metDisplay).shown, 'disable clears met and unmet labels')
display:restored('expanded display options retain exact game-setting restoration')
local invalidOptions = world({ options = { fontSize = 'bad', nameOffset = -500, metColour = 'broken', unmetColour = '#aabbcc' } })
invalidOptions:load(); invalidOptions:flush()
check(invalidOptions.ns.db.options.fontSize == 22 and invalidOptions.ns.db.options.nameOffset == -200, 'startup sanitizes malformed and out-of-range numeric display options')
check(invalidOptions.ns.db.options.metColour == 'FFD100' and invalidOptions.ns.db.options.unmetColour == 'AABBCC', 'startup validates and normalizes persisted colours')
-- Arrival and native opacity resets must be handled before any deferred tick.
local arrival = world({ options = { showUnmetNames = false } })
arrival:load(); arrival:flush()
local arrivalWrites = arrival.writes
local arriving = arrival:plate('stranger')
arrival:fire('NAME_PLATE_UNIT_ADDED', 'stranger')
check(arriving.UnitFrame.alpha == 0, 'new unknown plate is masked inside the arrival event')
check(not arrival:label(arriving).shown, 'arrival cannot briefly reveal an unknown name')
check(arrival.writes == arrivalWrites, 'immediate arrival handling writes no game settings')
arrival:flush()
arriving.UnitFrame:SetAlpha(1)
arrival:draw()
check(arriving.UnitFrame.alpha == 0, 'native alpha reset is masked before drawing without a timer tick')
arrival:command('meet')
arriving.UnitFrame:SetAlpha(0.6)
arrival:draw()
check(arriving.UnitFrame.alpha == 0 and arrival:label(arriving).shown, 'per-frame mask preserves custom met name')
check(arriving.labels[2].shown, 'per-frame mask preserves custom guild')
arrival.combat = true
arriving.UnitFrame:SetAlpha(1); arrival:draw()
check(arriving.UnitFrame.alpha == 0 and arrival.writes == arrivalWrites, 'combat mask correction needs no CVar writes')
arrival.combat = false
arrival.plates = {}
arrival:fire('NAME_PLATE_UNIT_REMOVED', 'stranger')
check(not arrival:label(arriving).shown and not arriving.labels[2].shown, 'removal clears custom name and guild before deferred refresh')
check(arriving.UnitFrame.alpha == 1, 'removal restores latest native opacity for frame reuse')
arrival:draw()
check(arriving.UnitFrame.alpha == 1, 'removed plate no longer receives per-frame masking')
arrival.plates = { arriving }
arriving.UnitFrame.unit = 'npc'
arrival:fire('NAME_PLATE_UNIT_ADDED', 'npc')
check(arriving.UnitFrame.alpha == 1 and not arrival:label(arriving).shown, 'immediate NPC reuse remains native')
arriving.UnitFrame.unit = 'acquaintance'
arrival:fire('NAME_PLATE_UNIT_ADDED', 'acquaintance')
check(arriving.UnitFrame.alpha == 0 and not arrival:label(arriving).shown, 'reused frame immediately masks a different unknown player')
arriving.UnitFrame.forbidden = true; arriving.UnitFrame.alpha = 0.4
arrival:draw()
check(arriving.UnitFrame.alpha == 0.4, 'draw check skips forbidden native frames')
arriving.UnitFrame.forbidden = false
arrival:draw()
check(arriving.UnitFrame.alpha == 0, 'mask correction resumes when native frame becomes accessible')
arrival:fire('NAME_PLATE_UNIT_ADDED', 'missing')
check(arrival.writes == arrivalWrites and #arrival.pending == 1, 'missing and repeated arrival events remain coalesced without CVar writes')
arrival:command('off'); arrival:draw()
check(arriving.UnitFrame.alpha == 0.4, 'disabled draw check leaves restored native opacity intact')
arrival:restored('arrival fix preserves exact game-setting restoration')
arrival:command('on')
arrival.env.C_AddOns.DisableAddOn('Acquainted')
arriving.UnitFrame:SetAlpha(0.7); arrival:draw()
check(arriving.UnitFrame.alpha == 0.7, 'addon-list disable stops mask correction immediately')
arrival:flush()
arrival:fire('PLAYER_LOGOUT'); arrival:draw()
check(arriving.UnitFrame.alpha == 0.7, 'logout stops mask correction')
local defaults = world()
local defaultUnmet = defaults:plate('stranger')
defaults:load(); defaults:flush()
check(defaults.ns.db.options.nameOffset == -40 and defaults.ns.db.options.unmetNameOffset == -40, 'new installations use lower names for both styles')
check(defaults.ns.db.options.showUnmetNames and defaults:label(defaultUnmet).shown, 'new installations show unmet names by default')
check(defaults:label(defaultUnmet).font[2] == 14 and defaults:label(defaultUnmet).point[5] == -40, 'default unmet name uses size 14 and height -40')
check(defaults.ns.db.options.metColour == 'FFD100' and defaults.ns.db.options.unmetColour == '999999', 'default colours remain gold and grey')
check(not defaults.ns.db.options.showUnmetGuildName and not defaultUnmet.labels[2].shown, 'unmet guild is hidden by default')
local unmetGuildCheckbox = defaults.env.Acquainted_showUnmetGuildNameCheck
check(unmetGuildCheckbox ~= nil, 'unmet guild setting is available in the actual settings panel')
unmetGuildCheckbox:SetChecked(true); unmetGuildCheckbox.scripts.OnClick(unmetGuildCheckbox); defaults:flush()
check(defaultUnmet.labels[2].shown and defaultUnmet.labels[2].text == '<Wayfarers>', 'unmet guild checkbox reveals the real guild')
check(defaultUnmet.labels[2].font[2] == 11 and defaultUnmet.labels[2].color[1] == 0.6, 'unmet guild uses a smaller font and unmet colour')
check(defaults.ns.db.known['Player-1-A'] == nil, 'showing an unmet guild does not meet the player')
defaults:option('showGuildName', false)
check(defaultUnmet.labels[2].shown, 'known guild setting does not control unmet guilds')
defaults:command('meet')
check(not defaultUnmet.labels[2].shown, 'enabled unmet guild setting cannot reveal a disabled met guild')
defaults:command('forget')
check(defaultUnmet.labels[2].shown, 'forget returns to the configured unmet guild display')
defaults:option('showUnmetNames', false)
check(not defaultUnmet.labels[2].shown, 'unmet guild cannot appear when unmet names are hidden')
defaults:option('showUnmetNames', true)
defaults.units.stranger.guildName = nil; defaults:tick()
check(not defaultUnmet.labels[2].shown, 'unmet players without a guild have no guild line')
defaults.units.stranger.guildName = 'Wayfarers'; defaults:tick()
defaults.ns.ResetAppearance('unmet'); defaults:flush()
check(defaults.ns.db.options.showUnmetGuildName, 'style-only reset preserves unmet guild visibility')
defaults.ns.ResetAppearance('all'); defaults:flush()
check(not defaults.ns.db.options.showUnmetGuildName and not defaultUnmet.labels[2].shown, 'full display reset restores hidden unmet guild default')
-- Drive the tabbed settings through its real widget callbacks.
local ui = world({
    options = { showFriends = true, fontSize = 25, nameOffset = -70, showUnmetNames = false },
    known = { ['Player-1-B'] = { name = 'Briar Stone', nickname = 'The Scholar' } },
})
ui:load(); ui:flush()
local e = ui.env
check(e.Acquainted_AppearancePage.shown and not e.Acquainted_RecognitionPage.shown and not e.Acquainted_AcquaintancesPage.shown, 'appearance is the only initial settings page')
local uiWrites = ui.writes
local metPreview, unmetPreview
for _, frame in ipairs(ui.frames) do
    if frame.kind == 'FontString' and frame.text == 'Alex Rowan' then
        if frame.font[2] == 25 then metPreview = frame else unmetPreview = frame end
    end
end
check(metPreview and unmetPreview and metPreview.shown and not unmetPreview.shown, 'live previews reflect saved styles and unmet visibility')
local number = e.Acquainted_nameOffsetValue
number:SetFocus(); number:SetText('-83'); number.scripts.OnEnterPressed(number); ui:flush()
check(ui.ns.db.options.nameOffset == -83 and not number:HasFocus(), 'exact negative height can be typed and applied with Enter')
check(metPreview.point[5] == 62 - 83 / 4, 'preview immediately follows typed height')
number:SetFocus(); number:SetText('-64'); number:ClearFocus(); ui:flush()
check(ui.ns.db.options.nameOffset == -64, 'clicking away applies a numeric edit')
number:SetFocus(); number:SetText('oops'); number.scripts.OnEnterPressed(number)
check(number:GetText() == '-64' and ui.ns.db.options.nameOffset == -64, 'invalid numeric edit restores the saved value')
number:SetFocus(); number:SetText('-30'); number.scripts.OnEscapePressed(number)
check(number:GetText() == '-64' and ui.ns.db.options.nameOffset == -64, 'Escape cancels a numeric edit')
number:SetFocus(); number:SetText('-99')
click(ui, e.Acquainted_ResetMet)
check(ui.ns.db.options.nameOffset == -40 and number:GetText() == '-40', 'reset overrides uncommitted numeric edits without a later undo')
e.Acquainted_showUnmetNamesCheck:SetChecked(true)
click(ui, e.Acquainted_showUnmetNamesCheck)
check(unmetPreview.shown, 'unmet name toggle updates preview')
e.Acquainted_unmetFontSizeSlider.scripts.OnValueChanged(e.Acquainted_unmetFontSizeSlider, 18)
check(unmetPreview.font[2] == 18, 'dragging slider updates preview immediately')
click(ui, e.Acquainted_unmetColourButton)
e.ColorPickerFrame.selected = { 0, 1, 0 }; e.ColorPickerFrame.options.swatchFunc()
check(unmetPreview.color[2] == 1 and unmetPreview.color[1] == 0, 'colour swatch live changes update preview')
click(ui, e.Acquainted_RecognitionTab)
check(not e.ColorPickerFrame.shown and e.Acquainted_RecognitionPage.shown and not e.Acquainted_AppearancePage.shown, 'tab switch closes our picker and changes the visible page')
check(e.Acquainted_showFriendsCheck.checked and ui.ns.db.options.showFriends, 'redesigned recognition controls preserve saved preferences')
local advanced = e.Acquainted_affectEnemiesCheck.parent
check(not advanced.shown, 'advanced enemy options start collapsed')
click(ui, e.Acquainted_AdvancedButton)
check(advanced.shown, 'advanced disclosure reveals enemy options')
click(ui, e.Acquainted_AdvancedButton)
check(not advanced.shown, 'advanced disclosure can be collapsed')
click(ui, e.Acquainted_AcquaintancesTab)
check(e.Acquainted_TargetButton.enabled and e.Acquainted_TargetButton.text == 'Meet', 'unmet current target offers Meet')
click(ui, e.Acquainted_TargetButton)
check(ui.ns.db.known['Player-1-A'] and e.Acquainted_TargetButton.text == 'Forget', 'current target Meet button saves target and becomes Forget')
ui.target = 'npc'; ui:fire('PLAYER_TARGET_CHANGED')
check(not e.Acquainted_TargetButton.enabled, 'non-player target disables the Meet action immediately')
ui.target = 'acquaintance'; ui:fire('PLAYER_TARGET_CHANGED')
check(e.Acquainted_TargetButton.enabled and e.Acquainted_TargetButton.text == 'Forget', 'target changes update the action immediately')
local function visibleRows()
    local result = {}
    for _, frame in ipairs(ui.frames) do
        if frame.parent == e.Acquainted_AcquaintanceList and frame.kind == 'Frame' and frame.shown then result[#result + 1] = frame end
    end
    return result
end
local function rowButton(row, text)
    for _, frame in ipairs(ui.frames) do
        if frame.parent == row and frame.text == text then return frame end
    end
    error('missing row button: ' .. text)
end
e.Acquainted_Search:SetText('sChOlAr')
local matches = visibleRows()
check(#matches == 1 and matches[1].guid == 'Player-1-B', 'search finds nicknames without case sensitivity')
local briarRow = matches[1]
click(ui, rowButton(briarRow, 'Edit nickname'))
check(e.Acquainted_NicknameEditor.shown and e.Acquainted_NicknameInput:GetText() == 'The Scholar', 'nickname editor opens with the saved nickname')
e.Acquainted_NicknameInput:SetText('  The Ranger  ')
click(ui, e.Acquainted_SaveNickname)
check(ui.ns.db.known['Player-1-B'].nickname == 'The Ranger' and not e.Acquainted_NicknameEditor.shown, 'nickname edit saves trimmed text for the chosen GUID')
check(#visibleRows() == 0, 'active search updates when nickname no longer matches')
e.Acquainted_Search:SetText('ranger')
matches = visibleRows()
check(#matches == 1 and matches[1].guid == 'Player-1-B', 'new nickname is searchable')
click(ui, rowButton(matches[1], 'Edit nickname'))
e.Acquainted_NicknameInput:SetText('discard me')
e.Acquainted_NicknameInput.scripts.OnEscapePressed(e.Acquainted_NicknameInput)
check(ui.ns.db.known['Player-1-B'].nickname == 'The Ranger', 'Escape cancels nickname changes')
click(ui, rowButton(matches[1], 'Edit nickname'))
e.Acquainted_NicknameInput:SetText('')
e.Acquainted_NicknameInput.scripts.OnEnterPressed(e.Acquainted_NicknameInput)
check(ui.ns.db.known['Player-1-B'].nickname == nil, 'empty nickname falls back to roleplay or game name')
e.Acquainted_Search:SetText('Briar')
matches = visibleRows()
click(ui, rowButton(matches[1], 'Edit nickname'))
local saveStale = e.Acquainted_SaveNickname.scripts.OnClick
click(ui, rowButton(matches[1], 'Forget'))
check(not ui.ns.db.known['Player-1-B'] and not e.Acquainted_NicknameEditor.shown, 'forget clears saved entry and closes its nickname editor')
e.Acquainted_NicknameInput:SetText('stale'); saveStale()
check(not ui.ns.db.known['Player-1-B'], 'stale nickname save cannot recreate a forgotten player')
e.Acquainted_Search:SetText('[')
check(#visibleRows() == 0, 'search treats pattern characters as literal text')
e.Acquainted_Search:SetText('')
check(#visibleRows() == 1, 'clearing search returns remaining saved acquaintances')
e.Acquainted_Search:SetFocus(); click(ui, e.Acquainted_HelpTab)
check(e.Acquainted_HelpPage.shown and not e.Acquainted_Search:HasFocus(), 'Help is separate and tab switches release search focus')
check(ui.writes == uiWrites, 'all settings navigation, previews, search and nickname changes avoid game-setting writes')
ui:command('off')
local restoredStatus
for _, frame in ipairs(ui.frames) do
    if frame.kind == 'FontString' and frame.text == 'Off · original name settings restored.' then restoredStatus = frame end
end
check(restoredStatus ~= nil, 'disabled status updates after settings have actually restored')
ui:restored('tabbed settings preserve exact restoration')

print('Acquainted: ' .. checks .. ' checks passed')
return {}
