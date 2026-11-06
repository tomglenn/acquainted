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
        function f:SetPoint(...) self.point = { ... } end
        function f:ClearAllPoints() self.point = nil end
        function f:SetWidth(v) self.width = v end
        function f:SetHeight(v) self.height = v end
        function f:SetSize(x, y) self.width, self.height = x, y end
        function f:SetText(v) self.text = v end
        function f:SetJustifyH(v) self.justify = v end
        function f:SetFont(path, size, flags) self.font = { path, size, flags }; return true end
        function f:SetTextColor(...) self.color = { ... } end
        function f:SetAlpha(v) assert(not self.forbidden, 'forbidden setter'); self.alpha = v end
        function f:GetAlpha() return self.alpha end
        function f:IsForbidden() return self.forbidden end
        function f:Hide() self.shown = false end
        function f:Show() self.shown = true end
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
        assert(object == env.C_AddOns, 'must not hook native frame setters')
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
    env.C_NamePlate = { GetNamePlates = function() return w.plates end }
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

local w = world()
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
local reused = world()
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
print('Acquainted: ' .. checks .. ' checks passed')
return {}
