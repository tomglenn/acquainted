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
local function world(saved, runtime)
    local w = { pending = {}, frames = {}, plates = {}, writes = 0, depth = 0, messages = {}, hooks = {} }
    local env = setmetatable({}, { __index = _G })
    w.now = 1700000000
    env.GetServerTime = function() return w.now end
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
    env.C_BattleNet = { GetAccountInfoByGUID = function(guid) if w.bnet == guid then return { isFriend = true } end end }
    env.issecretvalue = function(value) return type(value) == 'table' and value.secret end
    env.InCombatLockdown = function() return w.combat or false end
    env.LE_PARTY_CATEGORY_INSTANCE = 2
    env.IsInGroup = function(category)
        if category == 2 then return w.instanceGroup or false end
        return w.grouped or w.raid or false
    end
    env.IsInRaid = function() return w.raid or false end
    env.IsInInstance = function() return w.instance or false, w.instanceType or 'none' end
    env.STANDARD_TEXT_FONT = 'Fonts/FRIZQT__.TTF'
    env.DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) w.messages[#w.messages + 1] = text end }
    env.SlashCmdList = {}
    env.AcquaintedDB = copy(saved)
    env.AcquaintedRuntime = copy(runtime)
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
        function f:SetID(v) self.id = v end
        function f:GetID() return self.id end
        function f:Enable() self.enabled = true end
        function f:Disable() self.enabled = false end
        function f:SetWidth(v) self.width = v end
        function f:SetHeight(v)
            local changed = self.height ~= v
            self.height = v
            if changed and self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self, self.width or 0, v) end
        end
        function f:GetHeight() return self.height or 0 end
        function f:SetSize(x, y) self.width, self.height = x, y end
        function f:SetText(v)
            local changed = self.text ~= v
            self.text = v
            if self.Text then self.Text:SetText(v) end
            if changed and self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, false) end
        end
        function f:GetText() return self.text or '' end
        function f:GetStringHeight() return 14 * (select(2, self:GetText():gsub('\n', '')) + 1) end
        function f:HighlightText() self.highlighted = true end
        function f:SetAutoFocus(v) self.autoFocus = v end
        function f:SetMaxLetters(v) self.maxLetters = v end
        function f:SetEnabled(v) self.enabled = v end
        function f:SetDefaultText(v) self.defaultText = v end
        function f:Update()
            local selected = {}
            for _, item in ipairs(self.menuItems or {}) do
                if item.isSelected and item.isSelected() then selected[#selected + 1] = item.text end
            end
            self:SetText(#selected > 0 and table.concat(selected, ", ") or self.defaultText or "")
        end
        function f:GenerateMenu()
            self.menuItems = {}
            local owner = self
            local root = {}
            function root:CreateRadio(text, selected, callback)
                local item = { text = text, isSelected = selected, callback = callback }
                owner.menuItems[#owner.menuItems + 1] = item
                return item
            end
            root.CreateCheckbox = root.CreateRadio
            function root:CreateTitle(text) owner.menuItems[#owner.menuItems + 1] = { text = text } end
            self.menuGenerator(self, root)
            self:Update()
        end
        function f:SetupMenu(generator) self.menuGenerator = generator; self:GenerateMenu() end
        function f:HasFocus() return self.focused or false end
        function f:SetFocus()
            self.focused = true
            if self.scripts.OnEditFocusGained then self.scripts.OnEditFocusGained(self) end
        end
        function f:ClearFocus()
            local focused = self.focused
            self.focused = false
            if focused and self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end
        end
        function f:SetAllPoints() end
        function f:SetFrameLevel(value) self.frameLevel = value end
        function f:GetFrameLevel() return self.frameLevel or 1 end
        function f:EnableMouse(value) self.mouseEnabled = value end
        function f:SetClipsChildren(v) self.clipsChildren = v end
        function f:SetColorTexture(...) self.color = { ... } end
        function f:CreateTexture() return widget('Texture', nil, self) end
        function f:SetJustifyH(v) self.justify = v end
        function f:SetJustifyV(v) self.justifyV = v end
        function f:SetWordWrap(v) self.wordWrap = v end
        function f:SetTextInsets(...) self.textInsets = { ... } end
        function f:SetMultiLine(value) self.multiline = value end
        function f:SetFont(path, size, flags) self.font = { path, size, flags }; return true end
        function f:SetTextColor(...) self.color = { ... } end
        function f:SetAlpha(v)
            assert(not self.nativePlate or self.companionVisual, 'must never change player plate alpha or existing health bars')
            assert(not self.forbidden, 'forbidden setter'); self.alpha = v
        end
        function f:GetAlpha() return self.alpha end
        function f:IsForbidden() return self.forbidden end
        function f:Hide()
            local wasShown = self.shown
            self.shown = false
            if wasShown and self.scripts.OnHide then self.scripts.OnHide(self) end
        end
        function f:Show() self.shown = true end
        function f:IsShown() return self.shown end
        function f:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
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
        function f:GetVerticalScroll() return self.scrollOffset or 0 end
        function f:CreateFontString(_, layer, font)
            local text = widget('FontString', nil, self)
            text.layer, text.fontObject = layer, font
            self.labels = self.labels or {}; self.labels[#self.labels + 1] = text
            if self.parent and (self.parent.UnitFrame or self.parent.unitFrame) then self.parent.labels = self.labels end
            return text
        end
        w.frames[#w.frames + 1] = f
        if name then env[name] = f end
        if template == 'UIPanelScrollFrameTemplate' then f.ScrollBar = widget('Slider', nil, f) end
        if template == 'PanelTopTabButtonTemplate' or template == 'PanelTabButtonTemplate' then
            f.Text = widget('FontString', nil, f)
            f.isTopTab = template == 'PanelTopTabButtonTemplate'
            for _, region in ipairs({ 'Left', 'Middle', 'Right', 'LeftActive', 'MiddleActive', 'RightActive' }) do
                f[region] = widget('Texture', nil, f)
            end
            f.scripts.OnShow = function(self)
                env.PanelTemplates_TabResize(self, parent.tabPadding, nil, parent.minTabWidth, parent.maxTabWidth)
            end
        end
        if template == 'OptionsSliderTemplate' then
            f.Text, f.Low, f.High = widget('FontString'), widget('FontString'), widget('FontString')
        end
        return f
    end
    env.PanelTemplates_TabResize = function(tab, padding, width, minimum, maximum)
        tab:SetWidth(width or math.max(minimum or 0, math.min(maximum or math.huge, #tab:GetText() * 7 + 24 + (padding or 0))))
    end
    env.PanelTemplates_SelectTab = function(tab)
        tab:Disable()
        for _, region in ipairs({ 'Left', 'Middle', 'Right' }) do tab[region]:Hide() end
        for _, region in ipairs({ 'LeftActive', 'MiddleActive', 'RightActive' }) do tab[region]:Show() end
    end
    env.PanelTemplates_DeselectTab = function(tab)
        tab:Enable()
        for _, region in ipairs({ 'Left', 'Middle', 'Right' }) do tab[region]:Show() end
        for _, region in ipairs({ 'LeftActive', 'MiddleActive', 'RightActive' }) do tab[region]:Hide() end
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
    w.settingCallbacks = {}
    env.Settings = {
        SetOnValueChangedCallback = function(key, callback) w.settingCallbacks[key] = callback end,
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
    function w:fire(event, argument, value)
        local previous = self.inEvent
        self.inEvent = event
        self.events.scripts.OnEvent(self.events, event, argument, value)
        self.inEvent = previous
    end
    function w:flush()
        local passes = 0
        while #self.pending > 0 do
            passes = passes + 1; assert(passes < 30, 'deferred refresh loop')
            local pending = self.pending; self.pending = {}
            for _, callback in ipairs(pending) do callback() end
        end
        for _, frame in ipairs(self.frames) do
            if frame.nativePlate and not frame.companionVisual then
                assert(frame.alpha == 0.8 and frame.shown, 'native plate, health and cast bars must retain their visibility and opacity')
            end
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
    w.temporaryCVars, w.persistentWrites = {}, 0
    -- cvars is the effective display state; savedCVars models preferences on
    -- disk/server. Direct fixture edits before load establish a saved baseline.
    local function NotifyWrite(key)
        assert(not w.inEvent or w.inEvent == 'PLAYER_LOGOUT' or w.inEvent == 'ADDONS_UNLOADING',
            'CVar write inside event: ' .. tostring(w.inEvent))
        assert(not w.combat, 'combat write blocked')
        w.depth = w.depth + 1; assert(w.depth == 1, 'nested CVar write')
        w.writes = w.writes + 1
        w:fire('CVAR_UPDATE', key)
        w:fire('NAME_PLATE_UNIT_ADDED', 'stranger')
        w:fire('UNIT_NAME_UPDATE', 'stranger')
        if w.ticker then w.ticker.callback() end
    end
    env.C_CVar = {
        GetCVar = function(key) return w.cvars[key] end,
        SetCVar = function(key, value)
            assert(w.ns.db.restore[key] ~= nil, 'persistent addon writes require an existing legacy recovery record')
            NotifyWrite(key)
            w.persistentWrites = w.persistentWrites + 1
            if w.failKey == key then w.depth = w.depth - 1; error('setting blocked: ' .. key) end
            w.savedCVars[key] = value
            if w.temporaryCVars[key] == nil then w.cvars[key] = value end
            w.depth = w.depth - 1
        end,
        SetTempCVar = function(key, value)
            NotifyWrite(key)
            if w.requireSnapshot and not w.snapshotChecked then
                for managed, wanted in pairs(w.ns.GameSettings.Desired(w.ns.db.options)) do
                    assert(w.cvars[managed] == wanted or w.ns.GameSettings.temporary[managed] ~= nil, 'temporary ownership recorded before first override')
                end
                w.snapshotChecked = true
            end
            if w.failKey == key then w.depth = w.depth - 1; error('temporary setting blocked: ' .. key) end
            -- Pick up fixture/user changes made while no override was active.
            if w.temporaryCVars[key] == nil then w.savedCVars[key] = w.cvars[key] end
            if w.rejectTempKey ~= key then
                w.temporaryCVars[key], w.cvars[key] = value, value
            end
            w.depth = w.depth - 1
        end,
        RemoveTempCVar = function(key)
            NotifyWrite(key)
            if w.failKey == key then w.depth = w.depth - 1; error('temporary removal blocked: ' .. key) end
            if w.temporaryCVars[key] ~= nil then
                w.temporaryCVars[key] = nil
                w.cvars[key] = w.savedCVars[key]
            end
            w.depth = w.depth - 1
        end,
    }
    function w:setSaved(key, value)
        self.savedCVars[key] = value
        if self.temporaryCVars[key] == nil then self.cvars[key] = value end
    end
    function w:changeBlizzardSetting(key, checked)
        local before = self.inEvent
        self.inEvent = 'BLIZZARD_SETTINGS'
        local value = checked and '1' or '0'
        self:setSaved(key, value)
        if self.uiClearsTemp then
            self.temporaryCVars[key] = nil
            self.cvars[key] = value
        end
        self:fire('CVAR_UPDATE', key, self.cvars[key])
        assert(self.settingCallbacks[key], 'Blizzard setting observer missing: ' .. key)
        self.settingCallbacks[key](key, {}, checked)
        self.inEvent = before
    end
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
        p.UnitFrame.nativePlate = true
        p.UnitFrame.name = widget('FontString', nil, p.UnitFrame)
        p.UnitFrame.healthBar = widget('StatusBar', nil, p.UnitFrame)
        p.UnitFrame.castBar = widget('StatusBar', nil, p.UnitFrame)
        p.UnitFrame.healthBar.nativePlate = true
        p.UnitFrame.castBar.nativePlate = true
        local creature = self.units[token]
        p.UnitFrame.healthBar.companionVisual = creature and (creature.pet or creature.minion or creature.battlePet) or false
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
        self.savedCVars = self.savedCVars or copy(self.cvars)
        local files = {}
        for line in io.lines('Acquainted/Acquainted.toc') do
            if line:match('^[%w_]+%.lua$') then files[#files + 1] = line end
        end
        for _, file in ipairs(files) do
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
        check(not self.ns.GameSettings.HasPending(self.ns.db), message .. ': recovery and override ownership cleared')
        check(next(self.temporaryCVars) == nil, message .. ': runtime overrides removed')
    end
    return w
end

local w = world({ options = { hideUnmet = true } })
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
check(w.cvars.nameplateShowOnlyNameForFriendlyPlayerUnits == '1', 'addon-introduced solo plates are names only')
check(unknown.UnitFrame.name.alpha == 0, 'unknown player native name is hidden')
check(not w:label(unknown).shown, 'unknown player has no custom overhead name')
check(not unknown.labels[2].shown, 'unknown player guild is also hidden')
check(npc.UnitFrame.name.alpha == 0.8 and not w:label(npc), 'NPC is untouched')
check(enemy.UnitFrame.name.alpha == 0.8 and not w:label(enemy), 'enemy untouched by default')
check(next(w.ns.db.restore) == nil and w.ns.GameSettings.temporary.UnitNameFriendlyPlayerName.original == '1', 'temporary ownership is separate from legacy recovery')
w:command('meet')
check(w.ns.db.known['Player-1-A'].name == 'Aster Moon', 'can remember non-TRP player with full Forever surname')
check(w:label(unknown).shown and w:label(unknown).text == 'Aster Moon', 'remembered player shows large name')
check(unknown.UnitFrame.name.alpha == 0, 'known player native name remains hidden')
check(w:label(unknown).parent.parent == unknown, 'custom name is in its own overlay frame')
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
w.friend, w.bnet = nil, 'Player-1-A'; w:option('showBattleNetFriends', true)
check(w:label(unknown).shown, 'separate Battle.net option reveals Battle.net friends')
w:option('showFriends', false)
w:option('showBattleNetFriends', false)
check(not w:label(unknown).shown, 'disabling friend option hides unknown friend')
w.guild = 'Player-1-A'; w:option('showGuild', true)
check(w:label(unknown).shown, 'guild option reveals guild member')
w:option('showGuild', false)
check(not w:label(unknown).shown, 'guild option reversible')
w.units.stranger.party = true; w:option('showGroup', true)
check(w.ns.Known('stranger', w.ns.db) and w:label(unknown).shown, 'party recognition shows met styling above native bars')
w.units.stranger.party, w.units.stranger.raid = nil, true; w:tick()
check(w.ns.Known('stranger', w.ns.db) and w:label(unknown).shown, 'raid recognition shows met styling above native bars')
w:option('showGroup', false)
check(not w:label(unknown).shown, 'group option reversible')
w.units.stranger.raid = nil

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
check(enemy.UnitFrame.name.alpha == 0 and not w:label(enemy).shown, 'opt-in enemy filtering hides only native name text')
w.target = 'enemy'; w:command('meet')
check(w:label(enemy).shown and w:label(enemy).text == 'Dusk Raven', 'enemy known label replaces native text')
w:option('affectEnemies', false)
check(enemy.UnitFrame.name.alpha == 0.8 and not w:label(enemy).shown, 'turning enemy filtering off restores native frame')
check(w.cvars.UnitNameEnemyPlayerName == '1', 'enemy name setting restored when option disabled')
w.target = 'stranger'; w:command('meet')
unknown.UnitFrame.name:SetAlpha(0.5); w:tick()
check(unknown.UnitFrame.name.alpha == 0, 'external alpha changes masked on refresh without hooks')
-- User manually changes managed values while active. Original snapshot must win on disable.
w:setSaved('UnitNameFriendlyPlayerName', '1')
local writesBefore = w.writes
for _ = 1, 100 do w:fire('NAME_PLATE_UNIT_ADDED'); w:fire('UNIT_NAME_UPDATE') end
check(w.writes == writesBefore, '200 nested UI events cause no inline writes')
check(#w.pending == 1, 'event storm coalesces')
w:flush()
check(w.writes == writesBefore, 'ordinary refresh does not fight WoW settings')
w:command('off')
w:restored('off restores exact originals')
check(unknown.UnitFrame.name.alpha == 0.5 and not w:label(unknown).shown, 'off restores latest native alpha and removes custom name')
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
check(w.ns.db.options.enabled and unknown.UnitFrame.name.alpha == 0, 'settings checkbox enables filtering')
w.env.Acquainted_fontSizeSlider.scripts.OnValueChanged(w.env.Acquainted_fontSizeSlider, 29)
w:flush(); check(w:label(unknown).font[2] == 29, 'actual slider callback changes name size')
-- WoW addon-list disable must restore before Lua is unloaded and not reapply.
w.env.C_AddOns.DisableAddOn('Acquainted'); w:flush()
w:restored('addon-list disable restores originals')
check(not w:label(unknown).shown, 'addon-list disable removes custom label')
check(not unknown.labels[2].shown, 'addon-list disable removes guild text')
w:tick(); w:restored('disabled addon does not reactivate on ticker')
w.env.C_AddOns.EnableAddOn('Acquainted'); w:flush()
check(unknown.UnitFrame.name.alpha == 0, 'addon-list re-enable works')
w.env.C_AddOns.DisableAddOn(7); w:flush()
w:restored('numeric addon-list disable restores originals')
w.env.C_AddOns.EnableAddOn(7); w:flush()
check(unknown.UnitFrame.name.alpha == 0, 'numeric addon-list re-enable works')
w.env.C_AddOns.DisableAllAddOns(); w:flush()
w:restored('disable all addons restores originals')
w.env.C_AddOns.EnableAllAddOns(); w:flush()
check(unknown.UnitFrame.name.alpha == 0, 'enable all addons resumes filtering')
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
local reused = world({ options = { hideUnmet = true } })
local reusedPlate = reused:plate('stranger')
reused:load(); reused:flush()
reused:command('meet')
reusedPlate.UnitFrame.unit = 'npc'; reused:fire('NAME_PLATE_UNIT_ADDED'); reused:flush()
check(reusedPlate.UnitFrame.name.alpha == 0.8 and not reused:label(reusedPlate).shown, 'NPC reuse restores frame and removes player label')
check(not reusedPlate.labels[2].shown, 'NPC reuse cannot retain guild text')
reusedPlate.UnitFrame.unit = 'acquaintance'; reused:fire('NAME_PLATE_UNIT_ADDED'); reused:flush()
check(reusedPlate.UnitFrame.name.alpha == 0 and not reused:label(reusedPlate).shown, 'player reuse cannot inherit previous name')
reusedPlate.UnitFrame.forbidden = true
reused:command('off')
check(reusedPlate.UnitFrame.name.alpha == 0, 'forbidden frame skipped')
reusedPlate.UnitFrame.forbidden = false; reused:tick()
check(reusedPlate.UnitFrame.name.alpha == 0.8, 'visual restoration retried when frame accessible')
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
check(retry.ns.GameSettings.temporary.UnitNameFriendlyPlayerName.original == '1', 'failed restoration retains original value')
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
    check(plate.UnitFrame.name.alpha == 0 and not pets:label(plate).shown, 'unknown-owner companion name is hidden')
end
check(npcMinion.UnitFrame.name.alpha == 0.8 and not pets:label(npcMinion), 'NPC-owned minion unaffected')
check(wild.UnitFrame.name.alpha == 0.8 and not pets:label(wild), 'wild critter frames not treated as player companions')
check(pets.cvars.UnitNameNonCombatCreatureName == '0', 'shared cosmetic pet/critter engine name setting suppressed')
check(pets:label(ownPet).shown and pets:label(ownPet).text == 'My Wolf', 'own pet owner counts as known')
check(enemyPet.UnitFrame.name.alpha == 0.8 and not pets:label(enemyPet), 'enemy pet respects opt-in enemy scope')
pets:command('meet')
check(pets:label(petPlate).shown and pets:label(petPlate).text == 'Shadow', 'meeting owner reveals pet name')
check(pets:label(minionPlate).shown and pets:label(minionPlate).text == 'Zigbit', 'meeting owner reveals summoned minion name')
check(pets:label(battlePlate).shown, 'meeting owner reveals cosmetic companion name when its plate exists')
check(not pets:label(otherPet).shown, 'meeting owner does not reveal another player pet')
check(not petPlate.labels[2].shown and not minionPlate.labels[2].shown, 'pet/minion labels do not show owner guild as pet guild')
pets:option('showPetNames', false)
check(not pets:label(petPlate).shown and not pets:label(minionPlate).shown and not pets:label(ownPet).shown, 'option off hides names even for known owners')
check(petPlate.UnitFrame.name.alpha == 0, 'option off keeps native companion name hidden')
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
check(not pets:label(petPlate).shown and petPlate.UnitFrame.name.alpha == 0, 'restricted owner stays hidden')
pets.units.petA.owner = 'Player-1-A'
pets:option('affectEnemies', true)
check(enemyPet.UnitFrame.name.alpha == 0 and not pets:label(enemyPet).shown, 'unknown enemy pet filtered only when opted in')
pets.target = 'enemy'; pets:command('meet')
check(pets:label(enemyPet).shown, 'known enemy owner reveals enemy companion name')
pets:option('affectEnemies', false)
check(enemyPet.UnitFrame.name.alpha == 0.8 and pets.cvars.UnitNameEnemyPetName == '1', 'enemy companion setting/frame restored on scope change')
pets:command('off')
pets:restored('pet/minion settings restore exactly on disable')
for _, plate in ipairs({ petPlate, minionPlate, battlePlate, ownPet, orphan }) do
    check(plate.UnitFrame.name.alpha == 0.8 and not pets:label(plate).shown, 'disable releases companion frame and removes text')
end
check(#pets:menu('PLAYER', 'petA').entries == 0, 'companion cannot be manually met instead of its owner')
local display = world({
    options = { fontSize = 27, nameOffset = 0, showGuild = false, hideUnmet = true },
    known = { ['Player-1-B'] = { name = 'Briar Stone', nickname = 'The Scholar' } },
})
local strangerDisplay, metDisplay = display:plate('stranger'), display:plate('acquaintance')
display:load(); display:flush()
check(display.ns.db.options.fontSize == 27 and display.ns.db.options.nameOffset == 0, 'upgrade preserves existing met size and zero height')
check(display.ns.db.options.hideUnmet and not display:label(strangerDisplay).shown, 'upgrade preserves saved hidden-unmet preference')
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
display:option('hideUnmet', false)
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
display:option('hideUnmet', true)
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
display:option('hideUnmet', false)
click(display, namedButton('Reset unmet style'))
check(display.ns.db.options.unmetFontSize == 14 and display.ns.db.options.unmetNameOffset == -40 and display.ns.db.options.unmetColour == '999999', 'unmet reset restores unmet defaults')
check(not display.ns.db.options.hideUnmet, 'style-only reset preserves unmet visibility choice')
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
check(not display.ns.db.options.hideUnmet and display.ns.db.options.fontSize == 22 and display.ns.db.options.unmetColour == '999999', 'full display reset restores both styles and visible-unmet default')
check(display.ns.db.known['Player-1-B'].nickname == 'The Scholar' and display.ns.db.options.showGuild, 'display resets preserve acquaintances, nicknames, and recognition rules')
check(display.writes == nativeWrites, 'all appearance edits, pickers, resets, and togglemet avoid game-setting writes')

display.env.AddOn_TotalRP3 = { Player = { CreateFromUnit = function()
    return { GetRoleplayingName = function() return '|cffff0000Briar|r |cnNORMAL_FONT_COLOR:Stone|r' end }
end } }
display:command('meet') -- clear the manual nickname so the RP name is displayed
display:option('metColour', '00FF00')
check(display:label(metDisplay).text == 'Briar Stone' and display:label(metDisplay).color[2] == 1, 'configured colour overrides embedded RP colour codes')
display:option('showGuild', false)
display:option('hideUnmet', false)
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
local arrival = world({ options = { hideUnmet = true } })
arrival:load(); arrival:flush()
local arrivalWrites = arrival.writes
local arriving = arrival:plate('stranger')
arrival:fire('NAME_PLATE_UNIT_ADDED', 'stranger')
check(arriving.UnitFrame.name.alpha == 0, 'new unknown plate is masked inside the arrival event')
check(not arrival:label(arriving).shown, 'arrival cannot briefly reveal an unknown name')
check(arrival.writes == arrivalWrites, 'immediate arrival handling writes no game settings')
arrival:flush()
arriving.UnitFrame.name:SetAlpha(1)
arrival:draw()
check(arriving.UnitFrame.name.alpha == 0, 'native alpha reset is masked before drawing without a timer tick')
arrival:command('meet')
arriving.UnitFrame.name:SetAlpha(0.6)
arrival:draw()
check(arriving.UnitFrame.name.alpha == 0 and arrival:label(arriving).shown, 'per-frame mask preserves custom met name')
check(arriving.labels[2].shown, 'per-frame mask preserves custom guild')
arrival.combat = true
arriving.UnitFrame.name:SetAlpha(1); arrival:draw()
check(arriving.UnitFrame.name.alpha == 0 and arrival.writes == arrivalWrites, 'combat mask correction needs no CVar writes')
arrival.combat = false
arrival.plates = {}
arrival:fire('NAME_PLATE_UNIT_REMOVED', 'stranger')
check(not arrival:label(arriving).shown and not arriving.labels[2].shown, 'removal clears custom name and guild before deferred refresh')
check(arriving.UnitFrame.name.alpha == 1, 'removal restores latest native opacity for frame reuse')
arrival:draw()
check(arriving.UnitFrame.name.alpha == 1, 'removed plate no longer receives per-frame masking')
arrival.plates = { arriving }
arriving.UnitFrame.unit = 'npc'
arrival:fire('NAME_PLATE_UNIT_ADDED', 'npc')
check(arriving.UnitFrame.name.alpha == 1 and not arrival:label(arriving).shown, 'immediate NPC reuse remains native')
arriving.UnitFrame.unit = 'acquaintance'
arrival:fire('NAME_PLATE_UNIT_ADDED', 'acquaintance')
check(arriving.UnitFrame.name.alpha == 0 and not arrival:label(arriving).shown, 'reused frame immediately masks a different unknown player')
arriving.UnitFrame.forbidden = true; arriving.UnitFrame.name.alpha = 0.4
arrival:draw()
check(arriving.UnitFrame.name.alpha == 0.4, 'draw check skips forbidden native frames')
arriving.UnitFrame.forbidden = false
arrival:draw()
check(arriving.UnitFrame.name.alpha == 0, 'mask correction resumes when native frame becomes accessible')
arrival:fire('NAME_PLATE_UNIT_ADDED', 'missing')
check(arrival.writes == arrivalWrites and #arrival.pending == 1, 'missing and repeated arrival events remain coalesced without CVar writes')
arrival:command('off'); arrival:draw()
check(arriving.UnitFrame.name.alpha == 0.4, 'disabled draw check leaves restored native opacity intact')
arrival:restored('arrival fix preserves exact game-setting restoration')
arrival:command('on')
arrival.env.C_AddOns.DisableAddOn('Acquainted')
arriving.UnitFrame.name:SetAlpha(0.7); arrival:draw()
check(arriving.UnitFrame.name.alpha == 0.7, 'addon-list disable stops mask correction immediately')
arrival:flush()
arrival:fire('PLAYER_LOGOUT'); arrival:draw()
check(arriving.UnitFrame.name.alpha == 0.7, 'logout stops mask correction')
local defaults = world()
local defaultUnmet = defaults:plate('stranger')
defaults:load(); defaults:flush()
check(defaults.ns.db.options.nameOffset == -40 and defaults.ns.db.options.unmetNameOffset == -40, 'new installations use lower names for both styles')
check(not defaults.ns.db.options.hideUnmet and defaults:label(defaultUnmet).shown, 'new installations show unmet names by default')
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
defaults:option('hideUnmet', true)
check(not defaultUnmet.labels[2].shown, 'unmet guild cannot appear when unmet names are hidden')
defaults:option('hideUnmet', false)
defaults.units.stranger.guildName = nil; defaults:tick()
check(not defaultUnmet.labels[2].shown, 'unmet players without a guild have no guild line')
defaults.units.stranger.guildName = 'Wayfarers'; defaults:tick()
defaults.ns.ResetAppearance('unmet'); defaults:flush()
check(defaults.ns.db.options.showUnmetGuildName, 'style-only reset preserves unmet guild visibility')
defaults.ns.ResetAppearance('all'); defaults:flush()
check(not defaults.ns.db.options.showUnmetGuildName and not defaultUnmet.labels[2].shown, 'full display reset restores hidden unmet guild default')
-- Drive the tabbed settings through its real widget callbacks.
local ui = world({
    options = { showFriends = true, fontSize = 25, nameOffset = -70, hideUnmet = true },
    known = { ['Player-1-B'] = { name = 'Briar Stone', nickname = 'The Scholar' } },
})
ui:load(); ui:flush()
local e = ui.env
check(ui.messages[1]:find('Welcome to Acquainted (v' .. ui.ns.version .. ')!', 1, true) ~= nil, 'startup welcomes the player with the current addon version')
check(ui.messages[2]:find('/acq|r for settings.', 1, true) ~= nil and not ui.messages[2]:find('/acquainted', 1, true), 'startup advertises the short settings command')
for _, key in ipairs({ 'fontSize', 'nameOffset', 'unmetFontSize', 'unmetNameOffset' }) do
    local value = e['Acquainted_' .. key .. 'Value']
    check(value:GetText() == tostring(ui.ns.db.options[key]), 'numeric field populated on initial settings creation: ' .. key)
    value:SetText('')
    value.scripts.OnShow(value)
    check(value:GetText() == tostring(ui.ns.db.options[key]), 'numeric field repopulates on show: ' .. key)
    check(value.font[1] == e.STANDARD_TEXT_FONT and value.color[1] == 1, 'numeric field has explicit readable font and colour: ' .. key)
    check(value.template == nil and value.textInsets[1] == 6 and value.justifyV == 'MIDDLE', 'input text layout does not depend on client templates: ' .. key)
    check(value.valueDisplay.shown and value.valueDisplay.text == tostring(ui.ns.db.options[key]), 'saved value has a visible independent text region: ' .. key)
    value:SetFocus()
    check(not value.valueDisplay.shown and value.color[4] == 1, 'focus switches to editable native text: ' .. key)
    value:ClearFocus()
    check(value.valueDisplay.shown and value.color[4] == 0, 'leaving focus returns to saved-value display without duplicate text: ' .. key)
end
check(e.Acquainted_AppearancePage.shown and not e.Acquainted_RecognitionPage.shown and not e.Acquainted_AcquaintancesPage.shown, 'appearance is the only initial settings page')
local peoplePage = e.Acquainted_AcquaintancesPage
peoplePage:SetHeight(400)
check(not peoplePage.ScrollBar.shown and e.Acquainted_AcquaintanceList.parent == peoplePage.child, 'short acquaintance list uses one page without a nested scrolling area')
peoplePage.child:SetHeight(900)
check(peoplePage.ScrollBar.shown, 'page scrollbar appears when content overflows')
peoplePage:SetVerticalScroll(500)
peoplePage.child:SetHeight(600)
check(peoplePage:GetVerticalScroll() == 200, 'shrinking content clamps the scroll offset to the remaining range')
peoplePage.child:SetHeight(204)
check(not peoplePage.ScrollBar.shown and peoplePage:GetVerticalScroll() == 0, 'scrollbar and old offset disappear when content fits again')

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
e.Acquainted_hideUnmetCheck:SetChecked(false)
click(ui, e.Acquainted_hideUnmetCheck)
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
ui:command('meet')
ui.target = 'acquaintance'
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
check(e.Acquainted_NicknameEditor.parent == ui.category.frame and e.Acquainted_NicknameEditor.point[1] == 'CENTER', 'nickname dialog is centred on the fixed canvas outside all scroll containers')
check(e.Acquainted_NicknameEditor:GetFrameLevel() > ui.category.frame:GetFrameLevel() and e.Acquainted_NicknameEditor.mouseEnabled, 'nickname dialog renders above the settings and blocks clicks through its body')
check(e.Acquainted_NicknameInput.font[1] == e.STANDARD_TEXT_FONT and e.Acquainted_nameOffsetValue.font[1] == e.STANDARD_TEXT_FONT, 'nickname and numeric fields have explicit readable fonts')
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
for index = 1, 20 do ui.ns.db.known['Overflow-' .. index] = { name = 'Overflow Person ' .. index } end
ui.ns.RefreshSettings()
check(peoplePage.ScrollBar.shown, 'long acquaintance list enables the single page scrollbar')
peoplePage:SetVerticalScroll(400)
e.Acquainted_Search:SetText('no matching person')
check(not peoplePage.ScrollBar.shown and peoplePage:GetVerticalScroll() == 0, 'filtering a long list removes needless scrolling and resets its position')
for index = 1, 20 do ui.ns.db.known['Overflow-' .. index] = nil end
e.Acquainted_Search:SetText('')

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

-- Display controls share policy with live previews; Hide must never hide bars.
local modes = world()
local modePlate = modes:plate('stranger')
modes:load(); modes:flush()
check(modes.ns.db.options.showGuild and modes.ns.db.options.showGroup and not modes.ns.db.options.showFriends,
    'fresh installs recognise guild and group by default, with friends unchanged')
modes:option('showUnmetGuildName', true)
check(modePlate.labels[2].shown, 'name display can include an unmet guild')
click(modes, modes.env.Acquainted_Unmet_label)
check(modes.ns.db.options.unmetDisplay == 'label' and modes:label(modePlate).text == 'Unmet', 'label selector renders anonymous Unmet')
check(not modePlate.labels[2].shown, 'anonymous label suppresses guild identity')
local oldDisplay = modes.ns.DisplayName
modes.ns.DisplayName = function() error('anonymous display must not resolve a name') end
modes:tick()
check(modes:label(modePlate).shown, 'anonymous label works without a display name')
click(modes, modes.env.Acquainted_Unmet_icon)
check(modes:label(modePlate).text == '|TInterface\\AddOns\\Acquainted\\Media\\Unmet:0|t' and not modePlate.labels[2].shown, 'icon selector renders the bundled person texture without guild')
modes.env.Acquainted_hideUnmetCheck:SetChecked(true)
click(modes, modes.env.Acquainted_hideUnmetCheck)
check(not modes:label(modePlate).shown and not modePlate.labels[2].shown, 'Hide unmet suppresses indicator and guild')
modes:option('hideUnmet', false)
modes.ns.DisplayName = oldDisplay
modes:command('meet')
check(modes:label(modePlate).text == 'Aster Moon' and modePlate.labels[2].shown, 'met appearance still shows actual name and guild')
modes.env.Acquainted_hideMetCheck:SetChecked(true)
click(modes, modes.env.Acquainted_hideMetCheck)
check(not modes:label(modePlate).shown and not modePlate.labels[2].shown, 'Hide met suppresses met display and guild')
modes:command('forget')
check(modes:label(modePlate).shown and modes:label(modePlate).text == '|TInterface\\AddOns\\Acquainted\\Media\\Unmet:0|t', 'forget immediately restores unmet indicator in reversed setup')
modes:option('hideUnmet', true)
modes:command('meet')
check(not modes:label(modePlate).shown, 'both categories can be hidden')
modes.ns.ResetAppearance('met'); modes:flush()
check(modes.ns.db.options.hideMet, 'individual style reset preserves Hide')
modes.ns.ResetAppearance('unmet'); modes:flush()
check(modes.ns.db.options.hideUnmet and modes.ns.db.options.unmetDisplay == 'icon', 'individual unmet style reset preserves Hide and display choice')
modes.ns.ResetAppearance('all'); modes:flush()
check(not modes.ns.db.options.hideMet and not modes.ns.db.options.hideUnmet and modes.ns.db.options.unmetDisplay == 'name', 'full appearance reset restores visible names')
check(not modes:option('unmetDisplay', 'bogus'), 'invalid display enum is rejected')
modes:command('forget'); modes:option('hideMet', true)
modes.units.stranger.party = true; modes:fire('GROUP_ROSTER_UPDATE'); modes:flush()
check(not modes:label(modePlate).shown and not modes.ns.db.known['Player-1-A'], 'group automatically counts as met without creating a manual record')
modes.units.stranger.party = nil; modes:fire('GROUP_ROSTER_UPDATE'); modes:flush()
check(modes:label(modePlate).shown, 'leaving group restores unmet appearance')
modes.guild = 'Player-1-A'; modes:fire('GUILD_ROSTER_UPDATE'); modes:flush()
check(not modes:label(modePlate).shown, 'guild automatically counts as met')
modes.guild = nil; modes:fire('GUILD_ROSTER_UPDATE'); modes:flush()
check(modes:label(modePlate).shown, 'leaving guild restores unmet appearance')

-- Legacy preferences migrate once; old names-only settings are released on upgrade.
for _, visible in ipairs({ true, false }) do
    local legacy = world({ schema = 2, options = { showUnmetNames = visible, showGuild = false, showGroup = false, fontSize = 29 },
        restore = { nameplateShowOnlyNameForFriendlyPlayerUnits = '0' }, known = { ['Player-1-B'] = { name = 'Briar Stone', nickname = 'Scholar' } } })
    legacy.cvars.nameplateShowOnlyNameForFriendlyPlayerUnits = '1'
    local plate = legacy:plate('stranger')
    legacy:load(); legacy:flush()
    check(legacy.ns.db.options.hideUnmet == not visible and legacy.ns.db.options.showUnmetNames == nil, 'old Show name preference migrates to inverse Hide')
    check(legacy:label(plate).shown == visible, 'migrated visibility is rendered')
    check(not legacy.ns.db.options.showGuild and not legacy.ns.db.options.showGroup and legacy.ns.db.options.fontSize == 29,
        'upgrade preserves explicit recognition and appearance choices')
    check(legacy.ns.db.known['Player-1-B'].nickname == 'Scholar' and legacy.ns.db.schema == 4, 'upgrade preserves manual data and advances schema')
    check(legacy.cvars.nameplateShowOnlyNameForFriendlyPlayerUnits == '1' and legacy.ns.GameSettings.temporary.nameplateShowOnlyNameForFriendlyPlayerUnits.original == '0' and next(legacy.ns.db.restore) == nil,
        'solo upgrade retains the original names-only value for later restoration')
    legacy.instance = true; legacy:fire('PLAYER_ENTERING_WORLD'); legacy:flush()
    check(legacy.cvars.nameplateShowOnlyNameForFriendlyPlayerUnits == '0' and legacy.ns.db.restore.nameplateShowOnlyNameForFriendlyPlayerUnits == nil,
        'entering an instance restores and releases legacy names-only setting')
end
local pendingUpgrade = world({ restore = { nameplateShowOnlyNames = '0' } })
pendingUpgrade.cvars.nameplateShowOnlyNames = '1'
pendingUpgrade.combat = true; pendingUpgrade:load(); pendingUpgrade:flush()
check(pendingUpgrade.cvars.nameplateShowOnlyNames == '1' and pendingUpgrade.writes == 0, 'legacy recovery waits for combat to end')
pendingUpgrade.combat = false; pendingUpgrade:fire('PLAYER_REGEN_ENABLED'); pendingUpgrade:flush()
check(pendingUpgrade.cvars.nameplateShowOnlyNames == '0', 'legacy fallback setting restores when combat ends')
local customNamesOnly = world()
customNamesOnly.cvars.nameplateShowOnlyNameForFriendlyPlayerUnits = '1'
customNamesOnly:load(); customNamesOnly:flush()
check(customNamesOnly.cvars.nameplateShowOnlyNameForFriendlyPlayerUnits == '1', 'user-selected names-only preference is not overridden')

-- Overlay mode leaves native names, bars and CVars to the existing nameplate addon.
local plater = world({ options = { hideMet = true, unmetDisplay = 'label' } })
plater.env.Plater = {}
local platerPlate = plater:plate('stranger')
platerPlate.unitFrame = plater.env.CreateFrame('Frame', nil, platerPlate)
platerPlate.unitFrame:SetFrameLevel(30)
plater:load(); plater:flush()
check(plater.writes == 0 and next(plater.ns.db.restore) == nil, 'Plater auto-detection requires no game-setting writes or snapshot')
check(platerPlate.UnitFrame.name.alpha == 0.8 and platerPlate.UnitFrame.alpha == 0.8, 'Plater native name and native plate remain unchanged')
check(plater:label(platerPlate).text == 'Unmet' and plater:label(platerPlate).point[2] == platerPlate.unitFrame, 'indicator anchors to Plater custom frame')
check(plater:label(platerPlate).parent:GetFrameLevel() > platerPlate.unitFrame:GetFrameLevel(), 'overlay draws above Plater')
plater:command('meet')
check(not plater:label(platerPlate).shown and platerPlate.UnitFrame.name.alpha == 0.8, 'meeting hides only the Acquainted overlay')
plater:command('forget')
check(plater:label(platerPlate).shown, 'forget restores unmet overlay')
plater.combat = true; plater:option('hideUnmet', true); plater:draw()
check(not plater:label(platerPlate).shown and plater.writes == 0, 'overlay visibility works in combat without CVars')
check(not plater:option('overlayOnly', true), 'changing manual integration mode is deferred until outside combat')
plater.combat = false; plater:command('off'); plater:restored('Plater disable leaves settings unchanged')
local manualOverlay = world({ options = { overlayOnly = true } })
local manualPlate = manualOverlay:plate('stranger')
manualOverlay:load(); manualOverlay:flush()
check(manualOverlay.writes == 0 and manualOverlay:label(manualPlate).shown and manualPlate.UnitFrame.name.alpha == 0.8, 'manual overlay works without Plater')
manualOverlay:option('overlayOnly', false)
check(manualPlate.UnitFrame.name.alpha == 0 and manualOverlay.cvars.UnitNameFriendlyPlayerName == '0', 'switching to standalone manages only name text')
manualOverlay:option('overlayOnly', true)
manualOverlay:restored('switching to overlay releases standalone game settings')
check(manualPlate.UnitFrame.name.alpha == 0.8, 'switching to overlay restores standalone native name')
manualOverlay:option('overlayOnly', false)
manualOverlay.env.Plater = {}; manualOverlay:tick()
manualOverlay:restored('late Plater detection releases standalone game settings')
check(manualPlate.UnitFrame.name.alpha == 0.8, 'late Plater detection releases standalone name mask')
local overlayUpgrade = world({ restore = { nameplateShowOnlyNameForFriendlyPlayerUnits = '0', UnitNameFriendlyPlayerName = '1' } })
overlayUpgrade.env.Plater = {}
overlayUpgrade.cvars.nameplateShowOnlyNameForFriendlyPlayerUnits, overlayUpgrade.cvars.UnitNameFriendlyPlayerName = '1', '0'
overlayUpgrade:load(); overlayUpgrade:flush(); overlayUpgrade:restored('Plater upgrade releases all legacy settings')
local forbidden = world()
local forbiddenPlate = forbidden:plate('stranger')
forbiddenPlate.UnitFrame.forbidden = true
forbidden:load(); forbidden:flush()
check(not forbidden:label(forbiddenPlate) and forbiddenPlate.UnitFrame.name.alpha == 0.8, 'inaccessible friendly instance plate retains native text and bars')
local unsupported = world()
local unsupportedPlate = unsupported:plate('stranger')
unsupportedPlate.UnitFrame.name = nil
unsupported:load(); unsupported:flush()
check(not unsupported:label(unsupportedPlate).shown, 'unknown native layout skips custom labels')
local reusedWithoutEvent = world()
local reusedWithoutPlate = reusedWithoutEvent:plate('stranger')
reusedWithoutEvent:load(); reusedWithoutEvent:flush()
reusedWithoutPlate.UnitFrame.unit = 'npc'; reusedWithoutEvent:draw()
check(reusedWithoutPlate.UnitFrame.name.alpha == 0.8 and not reusedWithoutEvent:label(reusedWithoutPlate).shown, 'draw releases mask on unit reuse even before arrival event')

-- Cross-machine transfer is inert, atomic, versioned, and scoped to manual data.
local source = world({ known = {
    ['Player-1-A'] = { name = 'Astér Moon', nickname = '100% The |cffff0000Sage|r' },
    ['Player-1-B'] = { name = 'Briar Stone' },
} })
source:load(); source:flush()
local exported = assert(source.ns.ExportPeople())
check(exported:find('ACQUAINTED:1', 1, true) == 1 and exported:find('Player-1-A', 1, true) < exported:find('Player-1-B', 1, true), 'export has a version and stable GUID ordering')
check(not exported:find('restore', 1, true) and not exported:find('options', 1, true), 'export contains no settings or recovery journal')
local recipient = world({ options = { fontSize = 35 }, known = {
    ['Player-1-A'] = { name = 'Local Aster', nickname = 'Local Sage' },
    ['Player-1-D'] = { name = 'Local Dusk' },
} })
recipient:load(); recipient:flush()
local stats = assert(recipient.ns.PreviewImport(exported))
check(stats.count == 2 and stats.added == 1 and stats.existing == 1 and stats.conflicts == 1 and stats.removed == 1, 'preview counts additions, conflicts and potential removals')
check(not recipient.ns.db.known['Player-1-B'], 'preview has no side effects')
local transferWrites = recipient.writes
check(recipient.ns.ImportPeople(exported), 'valid list imports')
recipient:flush()
check(recipient.ns.db.known['Player-1-A'].nickname == 'Local Sage' and recipient.ns.db.known['Player-1-D'], 'merge keeps local conflicts and people absent from import')
check(recipient.ns.db.known['Player-1-B'].name == 'Briar Stone' and recipient.ns.db.known['Player-1-B'].nickname == nil, 'empty final nickname round-trips')
check(recipient.ns.ImportPeople(exported, false, true), 'explicit overwrite imports')
check(recipient.ns.db.known['Player-1-A'].name == 'Astér Moon' and recipient.ns.db.known['Player-1-A'].nickname == '100% The |cffff0000Sage|r', 'Unicode, percent signs and text round-trip without evaluation')
check(recipient.ns.ImportPeople(exported, true), 'explicit replacement imports')
check(not recipient.ns.db.known['Player-1-D'], 'replacement removes local people absent from import')
recipient:flush()
check(recipient.writes == transferWrites and recipient.ns.db.options.fontSize == 35 and recipient.ns.GameSettings.temporary.UnitNameFriendlyPlayerName.original == '1', 'transfer preserves settings and machine-local restoration state')
check(recipient.ns.ImportPeople(exported:gsub('\n', '\r\n')), 'Windows line endings import')
local beforeInvalid = assert(recipient.ns.ExportPeople())
local badPayloads = {
    '', 'ACQUAINTED:2', 'return { known = {} }',
    'ACQUAINTED:1\nCreature-1-A\tNPC\t',
    'ACQUAINTED:1\nPlayer-1-A\tName\t\nPlayer-1-A\tDuplicate\t',
    'ACQUAINTED:1\nPlayer-1-A\tName\tbad%G0',
    'ACQUAINTED:1\nPlayer-1-A\tName\tbad%',
    'ACQUAINTED:1\nPlayer-1-A\tName\tbad%00',
    'ACQUAINTED:1\nPlayer-1-A\t%0A\t',
    'ACQUAINTED:1\nPlayer-1-A\t' .. string.rep('x', 513) .. '\t',
    exported .. '\nmalformed row', string.rep('x', recipient.ns.transferLimit + 1),
}
for _, bad in ipairs(badPayloads) do
    check(not recipient.ns.PreviewImport(bad), 'invalid payload preview rejected')
    check(not recipient.ns.ImportPeople(bad, true, true) and recipient.ns.ExportPeople() == beforeInvalid, 'invalid replacement is atomic and preserves the existing list')
end
local many = { 'ACQUAINTED:1' }
for i = 1, 10001 do many[#many + 1] = 'Player-1-' .. string.format('%X', i) .. '\tName\t' end
check(not recipient.ns.ImportPeople(table.concat(many, '\n')), 'oversized record count is rejected')
-- Import resets session undo so forgotten local nicknames cannot reappear.
recipient:command('togglemet')
check(not recipient.ns.db.known['Player-1-A'], 'target forgotten before transfer undo test')
check(recipient.ns.ImportPeople('ACQUAINTED:1', true), 'empty replacement is supported')
recipient:command('togglemet')
check(recipient.ns.db.known['Player-1-A'].nickname == nil, 'import clears stale Meet/Forget nickname undo')

-- Real transfer widget callbacks require a fresh preview after edits or mode changes.
local te = recipient.env
click(recipient, te.Acquainted_AcquaintancesTab)
click(recipient, te.Acquainted_Export)
check(te.Acquainted_TransferDialog.shown and te.Acquainted_TransferInput.highlighted and not te.Acquainted_TransferCommit.shown, 'export opens selected copyable text without an import action')
click(recipient, te.Acquainted_TransferClose)
click(recipient, te.Acquainted_Import)
check(te.Acquainted_TransferDialog.shown and not te.Acquainted_TransferCommit.enabled and te.Acquainted_TransferInput:GetText() == '', 'import opens blank and requires preview')
te.Acquainted_TransferInput:SetText(exported)
click(recipient, te.Acquainted_TransferPreview)
check(te.Acquainted_TransferCommit.enabled and te.Acquainted_TransferDialog.preview == exported, 'valid preview enables import')
te.Acquainted_TransferOverwrite:SetChecked(true); click(recipient, te.Acquainted_TransferOverwrite)
check(not te.Acquainted_TransferCommit.enabled and not te.Acquainted_TransferDialog.preview, 'changing conflict handling invalidates preview')
click(recipient, te.Acquainted_TransferPreview)
te.Acquainted_TransferInput:SetText('invalid')
check(not te.Acquainted_TransferCommit.enabled, 'editing pasted text invalidates preview')
click(recipient, te.Acquainted_TransferCommit)
check(recipient.ns.db.known['Player-1-B'] == nil, 'stale commit cannot import')
click(recipient, te.Acquainted_TransferPreview)
check(not te.Acquainted_TransferCommit.enabled, 'invalid preview leaves commit disabled')
te.Acquainted_TransferInput:SetText(exported)
click(recipient, te.Acquainted_TransferPreview)
click(recipient, te.Acquainted_TransferCommit)
check(not te.Acquainted_TransferDialog.shown and recipient.ns.db.known['Player-1-A'].nickname == '100% The |cffff0000Sage|r', 'real UI imports selected overwrite policy')
recipient.ns.SetRemembered('Player-1-D', 'Local Dusk'); recipient:flush()
click(recipient, te.Acquainted_Import)
te.Acquainted_TransferInput:SetText(exported)
te.Acquainted_TransferReplace:SetChecked(true); click(recipient, te.Acquainted_TransferReplace)
click(recipient, te.Acquainted_TransferPreview)
check(te.Acquainted_TransferCommit.text == 'Replace list' and te.Acquainted_TransferDialog.summary.text:find('removes 1 local', 1, true), 'replacement preview explicitly reports removals')
click(recipient, te.Acquainted_TransferCommit)
check(not recipient.ns.db.known['Player-1-D'], 'real UI replacement removes absent entries')
click(recipient, te.Acquainted_Import)
te.Acquainted_TransferInput:SetText(exported)
click(recipient, te.Acquainted_TransferPreview)
click(recipient, te.Acquainted_HelpTab)
check(not te.Acquainted_TransferDialog.shown and not te.Acquainted_TransferInput:HasFocus() and not te.Acquainted_TransferDialog.preview, 'tab change closes transfer dialog and invalidates preview')
click(recipient, te.Acquainted_AcquaintancesTab)
click(recipient, te.Acquainted_Import)
te.Acquainted_TransferInput:SetText(exported)
te.Acquainted_TransferReplace:SetChecked(true); click(recipient, te.Acquainted_TransferReplace)
click(recipient, te.Acquainted_TransferPreview)
recipient.ns.SetRemembered('Player-1-D', 'New acquaintance after preview'); recipient:flush()
click(recipient, te.Acquainted_TransferCommit)
check(recipient.ns.db.known['Player-1-D'] and not te.Acquainted_TransferCommit.enabled, 'list edits after preview prevent a stale replacement')
check(te.Acquainted_TransferDialog.summary.text:find('local list changed', 1, true), 'stale local list asks for a fresh preview')
click(recipient, te.Acquainted_TransferClose)
recipient:command('off'); recipient:restored('transfer retains exact setting restoration')

-- Saved preferences and runtime overrides are separate stores.
local temporary = world()
local temporaryPlate = temporary:plate('stranger')
temporary:load(); temporary:flush()
for key, original in pairs(temporary.original) do
    check(temporary.savedCVars[key] == original, 'activation preserves saved preference: ' .. key)
end
check(temporary.persistentWrites == 0 and next(temporary.ns.db.restore) == nil, 'fresh activation never creates legacy recovery records or persistent writes')
check(temporary.cvars.nameplateShowFriendlyPlayers == '1' and temporary.savedCVars.nameplateShowFriendlyPlayers == '0', 'temporary friendly anchors leave saved friendly-plate visibility off')
check(temporary.cvars.nameplateShowOnlyNameForFriendlyPlayerUnits == '1' and temporary.savedCVars.nameplateShowOnlyNameForFriendlyPlayerUnits == '0', 'temporary names-only leaves saved health-bar preference unchanged')
check(temporary:label(temporaryPlate).shown, 'custom met/unmet rendering still works with temporary overrides')
-- Removing overrides must reveal newer saved choices, not write old snapshots.
temporary:setSaved('UnitNameFriendlyPlayerName', '0')
temporary:setSaved('nameplateShowAll', '1')
check(temporary.ns.GameSettings.temporary.UnitNameFriendlyPlayerName.original == '1' and temporary.cvars.UnitNameFriendlyPlayerName == '0', 'saved changes can differ from the remembered policy baseline')
temporary.original.UnitNameFriendlyPlayerName, temporary.original.nameplateShowAll = '0', '1'
temporary:command('off'); temporary:restored('disable reveals the latest saved preferences')
check(temporary.cvars.UnitNameFriendlyPlayerName == '0' and temporary.cvars.nameplateShowAll == '1' and temporary.persistentWrites == 0, 'disable never overwrites new saved preferences with old values')
temporary:command('on'); temporary.instance = true; temporary:fire('PLAYER_ENTERING_WORLD'); temporary:flush()
temporary:restored('instance entry removes only runtime overrides')
check(temporary.persistentWrites == 0, 'instance transition never writes saved preferences')

-- A different runtime value indicates somebody else has taken over the key.
local takeover = world()
takeover:load(); takeover:flush()
takeover.temporaryCVars.nameplateShowFriendlyPlayers = '0'
takeover.cvars.nameplateShowFriendlyPlayers = '0'
takeover:command('off')
check(takeover.temporaryCVars.nameplateShowFriendlyPlayers == '0', 'cleanup preserves a different temporary value supplied by another addon')
check(not takeover.ns.GameSettings.HasPending(takeover.ns.db) and takeover.persistentWrites == 0, 'external takeover releases our ownership without changing saved settings')

-- Settings already supplied by another addon are not acquired or removed.
local existingOverride = world({ options = { overlayOnly = true } })
existingOverride.savedCVars = copy(existingOverride.cvars)
existingOverride.temporaryCVars.nameplateShowFriendlyPlayers = '1'
existingOverride.cvars.nameplateShowFriendlyPlayers = '1'
existingOverride:load(); existingOverride:flush(); existingOverride:command('off')
check(existingOverride.writes == 0 and existingOverride.temporaryCVars.nameplateShowFriendlyPlayers == '1', 'overlay mode leaves another addon temporary override completely alone')

for _, missing in ipairs({ 'SetTempCVar', 'RemoveTempCVar' }) do
    local unsupportedTemp = world()
    local unsupportedTempPlate = unsupportedTemp:plate('stranger')
    unsupportedTemp.env.C_CVar[missing] = nil
    unsupportedTemp:load(); unsupportedTemp:flush()
    unsupportedTemp:restored('missing ' .. missing .. ' leaves preferences unchanged')
    check(unsupportedTemp.persistentWrites == 0 and unsupportedTemp.writes == 0 and not unsupportedTemp:label(unsupportedTempPlate), 'missing temporary API has no persistent fallback')
    unsupportedTemp:option('overlayOnly', true)
    check(unsupportedTemp:label(unsupportedTempPlate).shown and unsupportedTemp.writes == 0, 'overlay remains available without temporary API support')
end
local rejectedOverride = world()
rejectedOverride.rejectTempKey = 'UnitNameFriendlyPlayerName'
rejectedOverride:load(); rejectedOverride:flush()
rejectedOverride:restored('silently rejected temporary setting rolls back partial overrides')
check(rejectedOverride.persistentWrites == 0, 'rejected temporary setting cannot fall back to persistent writing')

-- A full restart expires runtime overrides even if logout never ran.
local crashed = world()
crashed:load(); crashed:flush()
local crashedDB = copy(crashed.ns.db)
local crashedRuntime = copy(crashed.env.AcquaintedRuntime)
check(next(crashedRuntime.temporary) ~= nil, 'session cleanup metadata can survive an unclean shutdown')
local restarted = world(crashedDB, crashedRuntime)
restarted.cvars = copy(crashed.savedCVars)
restarted.original = copy(restarted.cvars)
restarted:load(); restarted:flush()
check(restarted.persistentWrites == 0 and restarted.ns.GameSettings.temporary.nameplateShowFriendlyPlayers.original == '0', 'restart uses saved preferences rather than old effective overrides')
restarted:command('off'); restarted:restored('stale ownership after full restart does not rewrite preferences')
-- A user could have enabled plates before the next launch: do not trust stale
-- metadata to decide whether the new session should hide their health bars.
local changedRestart = world(crashedDB, crashedRuntime)
changedRestart.cvars.nameplateShowFriendlyPlayers = '1'
changedRestart.original = copy(changedRestart.cvars)
changedRestart:load(); changedRestart:flush()
check(changedRestart.cvars.nameplateShowOnlyNameForFriendlyPlayerUnits == '0' and changedRestart.ns.GameSettings.temporary.nameplateShowOnlyNameForFriendlyPlayerUnits == nil,
    'fresh startup discards stale ownership and respects newly enabled health plates')
changedRestart:command('off'); changedRestart:restored('restart with new plate preferences keeps the new baseline')

-- /reload can retain engine overrides when combat prevents unloading cleanup.
local reloadSource = world()
reloadSource:load(); reloadSource:flush()
reloadSource.combat = true; reloadSource:fire('ADDONS_UNLOADING')
check(reloadSource.ns.GameSettings.HasPending(reloadSource.ns.db), 'combat unload keeps ownership metadata for surviving runtime overrides')
local reloaded = world(copy(reloadSource.ns.db), copy(reloadSource.env.AcquaintedRuntime))
reloaded.savedCVars = copy(reloadSource.savedCVars)
reloaded.cvars = copy(reloadSource.cvars)
reloaded.temporaryCVars = copy(reloadSource.temporaryCVars)
reloaded.original = copy(reloaded.savedCVars)
reloaded.combat, reloaded.instance = true, true
reloaded:load(); reloaded:flush()
check(reloaded.writes == 0 and reloaded.ns.GameSettings.HasPending(reloaded.ns.db), 'grouped combat reload does not attempt forbidden cleanup')
reloaded.combat = false; reloaded:fire('PLAYER_REGEN_ENABLED'); reloaded:flush()
reloaded:restored('grouped post-reload cleanup removes surviving overrides')
check(reloaded.persistentWrites == 0, 'post-reload cleanup preserves saved preferences')

-- Recover prior persistent versions once, before adding any temporary settings.
local migrating = world({ schema = 3, options = {}, restore = {
    nameplateShowFriendlyPlayers = '0', UnitNameFriendlyPlayerName = '1',
} })
migrating.cvars.nameplateShowFriendlyPlayers, migrating.cvars.UnitNameFriendlyPlayerName = '1', '0'
migrating:load(); migrating:flush()
check(migrating.persistentWrites == 2 and migrating.savedCVars.nameplateShowFriendlyPlayers == '0' and migrating.savedCVars.UnitNameFriendlyPlayerName == '1', 'migration restores the two known legacy changes')
check(next(migrating.ns.db.restore) == nil and migrating.ns.db.schema == 4 and migrating.ns.GameSettings.temporary.nameplateShowFriendlyPlayers.original == '0', 'legacy journal clears before temporary policy is chosen')
local migrationWrites = migrating.persistentWrites
migrating:command('off'); migrating:command('on'); migrating.instance = true; migrating:fire('PLAYER_ENTERING_WORLD'); migrating:flush()
check(migrating.persistentWrites == migrationWrites, 'persistent migration is not repeated during subsequent sessions and group transitions')
migrating:restored('migration and later cleanup restore the known saved baseline')
local failedMigration = world({ restore = { UnitNameFriendlyPlayerName = '1' } })
failedMigration.cvars.UnitNameFriendlyPlayerName = '0'
failedMigration.failKey = 'UnitNameFriendlyPlayerName'
failedMigration:load(); failedMigration:flush()
check(failedMigration.ns.db.restore.UnitNameFriendlyPlayerName == '1' and next(failedMigration.temporaryCVars) == nil, 'failed legacy recovery prevents new overrides and preserves its recovery record')
failedMigration.failKey = nil; failedMigration:tick()
check(next(failedMigration.ns.db.restore) == nil and failedMigration.cvars.UnitNameFriendlyPlayerName == '1', 'failed legacy recovery retries without re-enabling filtering')

-- Account-wide cleanup survives switching away from a character in combat.
local nextCharacter = world(nil, copy(reloadSource.env.AcquaintedRuntime))
nextCharacter.savedCVars = copy(reloadSource.savedCVars)
nextCharacter.cvars = copy(reloadSource.cvars)
nextCharacter.temporaryCVars = copy(reloadSource.temporaryCVars)
nextCharacter.original = copy(nextCharacter.savedCVars)
nextCharacter.instance = true
nextCharacter:load(); nextCharacter:flush()
nextCharacter:restored('a different character can remove leftover session overrides')
check(nextCharacter.persistentWrites == 0 and next(nextCharacter.ns.db.known) == nil, 'cross-character cleanup touches neither saved game preferences nor acquaintances')
check(nextCharacter.ns.db.temporary == nil and nextCharacter.ns.GameSettings.temporary == nextCharacter.env.AcquaintedRuntime.temporary,
    'session cleanup ownership is account-wide rather than duplicated in character data')
-- The removal API can be unavailable temporarily; never lose its ownership.
local missingCleanup = world()
missingCleanup:load(); missingCleanup:flush()
local removeAPI = missingCleanup.env.C_CVar.RemoveTempCVar
missingCleanup.env.C_CVar.RemoveTempCVar = nil
missingCleanup:command('off')
check(missingCleanup.ns.GameSettings.HasPending(missingCleanup.ns.db) and missingCleanup.persistentWrites == 0, 'missing cleanup API retains pending ownership without persistent fallback')
missingCleanup.env.C_CVar.RemoveTempCVar = removeAPI; missingCleanup:tick()
missingCleanup:restored('cleanup retries when the temporary API becomes available')

-- Labels need world anchors even if friendly plates were already enabled.
-- Simulate the absence of out-of-combat world plates with Always Show off.
for _, friendly in ipairs({ '0', '1' }) do
    for _, always in ipairs({ '0', '1' }) do
        local anchors = world()
        anchors.cvars.nameplateShowFriendlyPlayers = friendly
        anchors.cvars.nameplateShowAll = always
        anchors.original = copy(anchors.cvars)
        anchors:load(); anchors:flush()
        check(anchors.cvars.nameplateShowAll == '1' and anchors.savedCVars.nameplateShowAll == always,
            'solo needs anchors without saving Always Show: friendly=' .. friendly .. ', always=' .. always)
        local plate = anchors:plate('stranger')
        local getPlates = anchors.env.C_NamePlate.GetNamePlates
        anchors.env.C_NamePlate.GetNamePlates = function()
            if anchors.cvars.nameplateShowAll ~= '1' then return {} end
            return getPlates()
        end
        anchors:tick()
        check(anchors:label(plate) and anchors:label(plate).shown, 'unmet label is visible with the temporary solo anchor setting')
        anchors:command('meet')
        check(anchors:label(plate).text == 'Aster Moon', 'met label is visible with the temporary solo anchor setting')
        check(anchors.cvars.nameplateShowOnlyNameForFriendlyPlayerUnits == (friendly == '0' and '1' or '0'), 'Always Show fix leaves existing health-bar preferences intact')
        anchors.grouped = true; anchors.units.stranger.party = true; anchors:fire('GROUP_ROSTER_UPDATE'); anchors:flush()
        check(anchors.cvars.nameplateShowAll == '1' and anchors:label(plate).shown, 'group members and outsiders retain available name anchors')
        anchors.grouped = false; anchors.units.stranger.party = nil; anchors:fire('GROUP_ROSTER_UPDATE'); anchors:flush()
        check(anchors:label(plate).shown and anchors.cvars.nameplateShowAll == '1', 'leaving a group restores solo anchors')
        anchors:command('off'); anchors:restored('Always Show saved preference restored on disable')
        check(anchors.persistentWrites == 0, 'Always Show fix never saves game preferences')
    end
end
for _, usePlater in ipairs({ false, true }) do
    local untouchedAnchors = world({ options = { overlayOnly = not usePlater } })
    if usePlater then untouchedAnchors.env.Plater = {} end
    untouchedAnchors:load(); untouchedAnchors:flush()
    check(untouchedAnchors.cvars.nameplateShowAll == '0' and untouchedAnchors.writes == 0, 'overlay mode leaves Always Show to the player or Plater')
end

-- External setting changes must not leave native names suppressed with no anchors.
for _, key in ipairs({ 'nameplateShowAll', 'nameplateShowFriendlyPlayers', 'UnitNameFriendlyPlayerName' }) do
    local conflict = world()
    local plate = conflict:plate('stranger')
    conflict:load(); conflict:flush()
    local external = conflict.cvars[key] == '1' and '0' or '1'
    conflict.temporaryCVars[key], conflict.cvars[key] = external, external
    conflict:fire('CVAR_UPDATE', key)
    conflict:flush()
    check(not conflict:label(plate).shown and plate.UnitFrame.name.alpha == 0.8, 'conflicting ' .. key .. ' stops rendering and releases native text')
    check(conflict.cvars[key] == external and conflict.temporaryCVars[key] == external, 'conflicting ' .. key .. ' is left to its new owner')
    check(conflict.ns.DisplayStatus():find('Filtering stopped', 1, true) and conflict.persistentWrites == 0, 'conflict is visible in status without any persistent writes')
    local afterCleanup = conflict.writes
    conflict:tick(); conflict:tick()
    check(conflict.writes == afterCleanup, 'conflict does not start an addon settings fight')
    -- Once the competing setting is released, explicit setup can retry.
    conflict.temporaryCVars[key] = nil; conflict.cvars[key] = conflict.savedCVars[key]
    conflict:command('setup')
    check(conflict:label(plate).shown, 'explicit setup recovers after ' .. key .. ' conflict')
    conflict:command('off'); conflict:restored('post-conflict cleanup')
end
-- A value can be necessary even when Acquainted did not need to override it.
local unownedAnchor = world()
unownedAnchor.cvars.nameplateShowAll = '1'
unownedAnchor:load(); unownedAnchor:flush()
check(unownedAnchor.ns.GameSettings.temporary.nameplateShowAll == nil, 'already-enabled Always Show is not acquired')
unownedAnchor:setSaved('nameplateShowAll', '0'); unownedAnchor:fire('CVAR_UPDATE', 'nameplateShowAll'); unownedAnchor:flush()
check(unownedAnchor.ns.DisplayStatus():find('Filtering stopped', 1, true) and unownedAnchor.cvars.UnitNameFriendlyPlayerName == '1', 'loss of an unowned anchor setting also releases ordinary names')

local conflictCombat = world()
local conflictCombatPlate = conflictCombat:plate('stranger')
conflictCombat:load(); conflictCombat:flush()
conflictCombat.combat = true
conflictCombat.temporaryCVars.nameplateShowAll, conflictCombat.cvars.nameplateShowAll = '0', '0'
local conflictCombatWrites = conflictCombat.writes
conflictCombat:fire('CVAR_UPDATE', 'nameplateShowAll'); conflictCombat:flush()
check(not conflictCombat:label(conflictCombatPlate).shown and conflictCombatPlate.UnitFrame.name.alpha == 0.8, 'combat setting conflict immediately releases accessible native text')
check(conflictCombat.writes == conflictCombatWrites and conflictCombat.ns.GameSettings.HasPending(conflictCombat.ns.db), 'combat conflict queues cleanup without illegal CVar writes')
conflictCombat.combat = false; conflictCombat:fire('PLAYER_REGEN_ENABLED'); conflictCombat:flush()
check(not conflictCombat.ns.GameSettings.HasPending(conflictCombat.ns.db) and conflictCombat.cvars.nameplateShowAll == '0', 'post-combat conflict cleanup preserves the external value')

-- Failed/waiting states must not claim the display is active in the real panel.
local failedPanel = world()
failedPanel.env.C_CVar.SetTempCVar = nil
failedPanel:load(); failedPanel:flush()
local panelStopped = false
for _, frame in ipairs(failedPanel.frames) do
    if frame.kind == 'FontString' and frame.text == 'Filtering stopped · /acq status for details.' then panelStopped = true end
end
check(panelStopped, 'failed startup updates the settings panel even if activation never became active')
local waitingPanel = world()
waitingPanel.combat = true; waitingPanel:load(); waitingPanel:flush()
check(waitingPanel.ns.DisplayStatus() == 'Waiting for combat to end before enabling name displays.', 'combat startup reports waiting rather than active display')
waitingPanel.combat = false; waitingPanel:fire('PLAYER_REGEN_ENABLED'); waitingPanel:flush()
check(waitingPanel.ns.DisplayStatus():find('Changes apply immediately', 1, true), 'waiting status changes to active after successful setup')

-- Cleanup cannot infer ownership loss from an unreadable setting.
local unreadableSetting = world()
unreadableSetting:load(); unreadableSetting:flush()
local originalRead = unreadableSetting.env.C_CVar.GetCVar
unreadableSetting.env.C_CVar.GetCVar = function(key)
    if key == 'UnitNameFriendlyPlayerName' then error('temporarily unavailable') end
    return originalRead(key)
end
unreadableSetting:command('off')
check(unreadableSetting.ns.GameSettings.temporary.UnitNameFriendlyPlayerName ~= nil, 'unreadable CVar keeps cleanup ownership for retry')
unreadableSetting.env.C_CVar.GetCVar = originalRead; unreadableSetting:tick()
unreadableSetting:restored('cleanup recovers after a temporary CVar read failure')

-- Friendly names-only applies to friendly players, not enemies or companions.
local enemyPosition = world({ options = { affectEnemies = true } })
local enemyPositionPlate = enemyPosition:plate('enemy')
enemyPosition:load(); enemyPosition:flush()
check(enemyPosition.cvars.nameplateShowOnlyNameForFriendlyPlayerUnits == '1', 'friendly names-only setting is active for overlap regression')
enemyPosition.target = 'enemy'; enemyPosition:command('meet')
check(enemyPosition:label(enemyPositionPlate).point[2] == enemyPositionPlate.UnitFrame.healthBar and enemyPosition:label(enemyPositionPlate).point[5] >= 4,
    'enemy custom name clears its health bar despite friendly names-only')
enemyPosition.units.enemy.guildName = 'Other Guild'; enemyPosition:tick()
check(enemyPosition:label(enemyPositionPlate).point[5] >= 23, 'enemy custom guild also clears its health bar')
local petPosition = world()
petPosition.cvars.nameplateShowFriendlyPlayerMinions = '1'
petPosition.cvars.nameplateShowFriendlyPlayers = '1'
petPosition.units.pet = { guid = 'Pet-1-A', first = 'Shadow', owner = 'Player-1-A', pet = true, friend = true }
local petPositionPlate = petPosition:plate('pet')
petPosition:load(); petPosition:flush(); petPosition:command('meet')
check(petPosition:label(petPositionPlate).point[2] == petPositionPlate.UnitFrame.healthBar and petPosition:label(petPositionPlate).point[5] >= 4,
    'companion custom name clears its health bar despite friendly names-only')

-- GUID recognition survives temporarily absent/restricted live names.
local identityDelay = world({ known = { ['Player-1-A'] = { name = 'Aster Moon', nickname = 'The Scholar' } } })
local identityDelayPlate = identityDelay:plate('stranger')
identityDelay:load(); identityDelay:flush()
click(identityDelay, identityDelay.env.Acquainted_AcquaintancesTab)
identityDelay.units.stranger.first = nil; identityDelay:fire('UNIT_NAME_UPDATE', 'stranger'); identityDelay:flush()
check(identityDelay:label(identityDelayPlate).shown and identityDelay:label(identityDelayPlate).text == 'The Scholar', 'saved nickname survives a missing live name')
check(#identityDelay:menu('PLAYER', 'stranger').entries == 0, 'Meet/Forget context menu waits for a complete current identity')
identityDelay:command('meet New nickname')
check(identityDelay.ns.db.known['Player-1-A'].nickname == 'The Scholar', 'a command cannot overwrite an acquaintance with a missing live name')
identityDelay.ns.SetNickname('Player-1-A', ''); identityDelay:flush()
check(identityDelay:label(identityDelayPlate).text == 'Aster Moon', 'saved full name is a fallback when the live name is absent')
identityDelay.units.stranger.first = { secret = true }; identityDelay:tick()
check(identityDelay:label(identityDelayPlate).text == 'Aster Moon', 'restricted live name preserves GUID-based recognition and saved name')
identityDelay:option('hideMet', true)
check(not identityDelay:label(identityDelayPlate).shown, 'Hide met still applies when the live name is restricted')
identityDelay.units.stranger.first = 'Aster'; identityDelay:fire('UNIT_NAME_UPDATE', 'stranger'); identityDelay:flush()
check(#identityDelay:menu('PLAYER', 'stranger').entries == 1, 'context action returns when the full live identity is available')

-- Plate pools can replace the native frame/name region before our next tick.
local replacement = world()
local replacementPlate = replacement:plate('stranger')
replacement:load(); replacement:flush()
local replacementLabel = replacement:label(replacementPlate)
local oldFrame = replacementPlate.UnitFrame
local newFrame = replacement.env.CreateFrame('Frame', nil, replacementPlate)
newFrame.unit = 'stranger'
newFrame.name = replacement.env.CreateFrame('FontString', nil, newFrame)
replacementPlate.UnitFrame = newFrame
replacement:draw()
check(oldFrame.name.alpha == 0.8 and not replacementLabel.shown, 'frame replacement releases stale text masks and labels before the next tick')
replacement:tick()
check(newFrame.name.alpha == 0 and replacementLabel.shown, 'replacement native frame is adopted on refresh')
local oldRegion = newFrame.name
newFrame.name = replacement.env.CreateFrame('FontString', nil, newFrame)
replacement:draw()
check(oldRegion.alpha == 0.8 and not replacementLabel.shown, 'name region replacement releases stale masks before the next tick')
replacement:tick()
check(newFrame.name.alpha == 0 and replacementLabel.shown, 'replacement name region is adopted on refresh')
replacementPlate.UnitFrame = nil
replacement:draw()
check(newFrame.name.alpha == 0.8 and not replacementLabel.shown, 'native frame removal releases custom display without a nil dereference')

-- Only pet/minion plates introduced by Acquainted lose their health display.
for _, original in ipairs({ '0', '1' }) do
    local petBars = world()
    petBars.cvars.nameplateShowFriendlyPlayerMinions = original
    petBars.cvars.nameplateShowFriendlyPlayers = '1'
    petBars.original = copy(petBars.cvars)
    petBars.units.pet = { guid = 'Pet-1-A', first = 'Shadow', owner = 'Player-1-A', pet = true, friend = true }
    petBars.units.ownPet = { guid = 'Pet-1-Mine', first = 'My Wolf', owner = 'Player-1-E', pet = true, friend = true }
    petBars.units.minion = { guid = 'Creature-1-Imp', first = 'Zigbit', owner = 'Player-1-A', minion = true, friend = true }
    petBars.units.enemyPet = { guid = 'Pet-1-Enemy', first = 'Enemy Wolf', owner = 'Player-1-D', pet = true, friend = false }
    local pet, own, minion = petBars:plate('pet'), petBars:plate('ownPet'), petBars:plate('minion')
    local player, enemyCompanion = petBars:plate('stranger'), petBars:plate('enemyPet')
    pet.UnitFrame.LevelFrame = petBars.env.CreateFrame('Frame', nil, pet.UnitFrame)
    local expected = original == '0' and 0 or 0.8
    petBars:load(); petBars:flush()
    check(pet.UnitFrame.healthBar.alpha == expected and minion.UnitFrame.healthBar.alpha == expected and own.UnitFrame.healthBar.alpha == expected,
        'companion health display respects originally-enabled minion plates: ' .. original)
    check(pet.UnitFrame.LevelFrame.alpha == expected, 'introduced companion level display follows its health bar')
    check(not petBars:label(pet).shown and petBars:label(own).shown, 'pet health handling preserves unmet-owner filtering and own-pet names')
    check(player.UnitFrame.healthBar.alpha == 0.8 and player.UnitFrame.alpha == 0.8, 'companion suppression never changes player health bars or UnitFrame')
    petBars:command('meet')
    check(petBars:label(pet).shown and petBars:label(pet).text == 'Shadow' and pet.UnitFrame.healthBar.alpha == expected, 'meeting an owner reveals pet names without introducing bars')
    if original == '0' then
        pet.UnitFrame.healthBar:SetAlpha(0.5); petBars:draw()
        check(pet.UnitFrame.healthBar.alpha == 0, 'native companion bar opacity reset is suppressed before drawing')
        pet.UnitFrame.healthBar.forbidden = true
        petBars:command('off')
        check(pet.UnitFrame.healthBar.alpha == 0, 'forbidden companion display keeps restoration pending in its visual state')
        pet.UnitFrame.healthBar.forbidden = false; petBars:tick()
        check(pet.UnitFrame.healthBar.alpha == 0.5, 'companion opacity restoration retries when the region becomes accessible')
        petBars:command('on')
    end
    petBars:option('affectEnemies', true)
    check(enemyCompanion.UnitFrame.healthBar.alpha == 0.8, 'friendly companion suppression never removes existing enemy pet bars')
    petBars.grouped = true; petBars:fire('GROUP_ROSTER_UPDATE'); petBars:flush()
    check(pet.UnitFrame.healthBar.alpha == expected and petBars:label(pet).shown, 'group entry keeps companion name and original bar policy')
    petBars:command('off')
    petBars:restored('companion display releases original plate settings while grouped')
end
local overlayPets = world({ options = { overlayOnly = true } })
overlayPets.units.pet = { guid = 'Pet-1-A', first = 'Shadow', owner = 'Player-1-A', pet = true, friend = true }
local overlayPet = overlayPets:plate('pet')
overlayPets:load(); overlayPets:flush(); overlayPets:command('meet')
check(overlayPet.UnitFrame.healthBar.alpha == 0.8 and overlayPets.writes == 0, 'overlay mode leaves native pet health display untouched')
-- Mode switches must release these masks as well as native name-text masks.
local switchedPet = world()
switchedPet.units.pet = { guid = 'Pet-1-A', first = 'Shadow', owner = 'Player-1-A', pet = true, friend = true }
local switchedPetPlate = switchedPet:plate('pet')
switchedPet:load(); switchedPet:flush()
check(switchedPetPlate.UnitFrame.healthBar.alpha == 0, 'standalone introduces companion names without health bars')
switchedPet:option('overlayOnly', true)
check(switchedPetPlate.UnitFrame.healthBar.alpha == 0.8, 'switching to overlay releases companion health masks')

-- A saved-on child switch can still have been inactive under a saved-off parent.
local parentPet = world()
parentPet.cvars.nameplateShowFriendlyPlayerMinions = '1'
parentPet.units.pet = { guid = 'Pet-1-A', first = 'Shadow', owner = 'Player-1-A', pet = true, friend = true }
local parentPetPlate = parentPet:plate('pet')
parentPet:load(); parentPet:flush(); parentPet:command('meet')
check(parentPetPlate.UnitFrame.healthBar.alpha == 0 and parentPet:label(parentPetPlate).shown,
    'enabling friendly plates does not reveal pet bars from a previously inactive child switch')
parentPet:command('off')
check(parentPetPlate.UnitFrame.healthBar.alpha == 0.8, 'parent-introduced companion masks restore on disable')
local modernPet = world()
modernPet.units.pet = { guid = 'Pet-1-A', first = 'Shadow', owner = 'Player-1-A', pet = true, friend = true }
local modernPetPlate = modernPet:plate('pet')
modernPetPlate.UnitFrame.HealthBarsContainer = modernPet.env.CreateFrame('Frame', nil, modernPetPlate.UnitFrame)
modernPet:load(); modernPet:flush(); modernPet:command('meet')
check(modernPetPlate.UnitFrame.HealthBarsContainer.alpha == 0 and modernPet:label(modernPetPlate).shown, 'modern companion container hides its health bar and decoration together')
modernPet:command('off')
check(modernPetPlate.UnitFrame.HealthBarsContainer.alpha == 0.8, 'modern companion container opacity restores on disable')

-- Grouping changes recognition per unit, not the whole addon display.
for _, scenario in ipairs({ 'party', 'raid', 'instanceGroup' }) do
    for _, friendly in ipairs({ '0', '1' }) do
        for _, namesOnly in ipairs({ '0', '1' }) do
            local grouped = world({ known = { ['Player-1-B'] = { name = 'Briar Stone', nickname = 'The Scholar' } } })
            grouped.cvars.nameplateShowFriendlyPlayers = friendly
            grouped.cvars.nameplateShowOnlyNameForFriendlyPlayerUnits = namesOnly
            grouped.original = copy(grouped.cvars)
            grouped.units.member = { guid = 'Player-1-F', first = 'Our', surname = 'Healer', player = true, friend = true }
            if scenario == 'raid' then grouped.raid = true; grouped.units.member.raid = true
            elseif scenario == 'instanceGroup' then grouped.instanceGroup = true; grouped.units.member.party = true
            else grouped.grouped = true; grouped.units.member.party = true end
            local member, unmet, met = grouped:plate('member'), grouped:plate('stranger'), grouped:plate('acquaintance')
            grouped:load(); grouped:flush()
            check(grouped:label(unmet).shown and grouped:label(unmet).font[2] == 14 and grouped:label(unmet).color[1] == 0.6,
                scenario .. ' startup keeps outsider unmet style: friendly=' .. friendly .. ', namesOnly=' .. namesOnly)
            check(grouped:label(met).shown and grouped:label(met).text == 'The Scholar' and grouped:label(met).font[2] == 22, 'grouped outsider met style and nickname stay intact')
            check(grouped:label(member).shown and grouped:label(member).font[2] == 22 and grouped.ns.db.known['Player-1-F'] == nil, 'group member uses automatic met styling without a permanent acquaintance')
            local effectiveNamesOnly = friendly == '0' and '1' or namesOnly
            check(grouped.cvars.nameplateShowOnlyNameForFriendlyPlayerUnits == effectiveNamesOnly, 'grouping preserves the user health-bar versus names-only choice')
            check(member.UnitFrame.alpha == 0.8 and member.UnitFrame.healthBar.alpha == 0.8 and member.UnitFrame.healthBar.shown, 'group member native health frame is never hidden or faded')
            if friendly == '1' and namesOnly == '0' then
                check(grouped:label(member).point[2] == member.UnitFrame.healthBar and grouped:label(member).point[5] >= 4, 'group member custom name sits above an enabled native health bar')
            end
            check(grouped.savedCVars.nameplateShowFriendlyPlayers == friendly and grouped.savedCVars.nameplateShowOnlyNameForFriendlyPlayerUnits == namesOnly and grouped.persistentWrites == 0, 'group styling preserves saved game preferences')
            grouped:command('off'); grouped:restored('grouped disable restores original preferences')
        end
    end
end

local roster = world({ known = { ['Player-1-B'] = { name = 'Briar Stone' } } })
roster.cvars.nameplateShowFriendlyPlayers = '1'
roster.original = copy(roster.cvars)
local rosterUnmet, rosterMet = roster:plate('stranger'), roster:plate('acquaintance')
roster:load(); roster:flush()
local rosterWrites = roster.writes
roster.grouped, roster.units.stranger.party = true, true
roster:fire('GROUP_ROSTER_UPDATE')
check(roster:label(rosterUnmet).shown and roster:label(rosterUnmet).font[2] == 22, 'joining a party immediately promotes that member to met styling')
check(roster:label(rosterMet).shown and roster.writes == rosterWrites, 'joining a party keeps outsider styling and needs no CVar writes')
roster:flush()
roster.units.newcomer = { guid = 'Player-1-C0', first = 'New', surname = 'Stranger', player = true, friend = true }
local rosterArrival = roster:plate('newcomer')
roster:fire('NAME_PLATE_UNIT_ADDED', 'newcomer'); roster:flush()
check(roster:label(rosterArrival).shown and roster:label(rosterArrival).font[2] == 14, 'outsiders arriving while grouped get unmet styling')
roster.combat = true
roster.raid, roster.grouped, roster.units.stranger.raid, roster.units.stranger.party = true, false, true, nil
roster:fire('GROUP_ROSTER_UPDATE'); roster:flush(); roster:draw()
check(roster:label(rosterUnmet).shown and roster:label(rosterMet).shown and roster:label(rosterArrival).shown, 'raid conversion in combat does not disable any acquaintance display')
check(roster.writes == rosterWrites and rosterUnmet.UnitFrame.healthBar.alpha == 0.8, 'group changes in combat never rewrite settings or hide native health bars')
roster.raid, roster.units.stranger.raid = false, nil
roster:fire('GROUP_ROSTER_UPDATE'); roster:flush()
check(roster:label(rosterUnmet).font[2] == 14 and roster:label(rosterMet).shown and roster:label(rosterArrival).shown, 'leaving a group returns former members to unmet while outsiders stay styled')
roster.combat = false; roster:command('off'); roster:restored('roster changes leave saved preferences recoverable')

local groupedPlater = world({ options = { hideMet = true, unmetDisplay = 'label' } })
groupedPlater.env.Plater = {}
local platerStranger = groupedPlater:plate('stranger')
local platerMember = groupedPlater:plate('acquaintance')
groupedPlater:load(); groupedPlater:flush()
groupedPlater.grouped, groupedPlater.units.acquaintance.party = true, true
groupedPlater:fire('GROUP_ROSTER_UPDATE'); groupedPlater:flush()
check(groupedPlater:label(platerStranger).shown and groupedPlater:label(platerStranger).text == 'Unmet', 'Plater outsider reminder remains while grouped')
check(not groupedPlater:label(platerMember).shown and platerMember.UnitFrame.name.alpha == 0.8 and platerMember.UnitFrame.healthBar.alpha == 0.8, 'Plater group recognition hides only its met Acquainted overlay')
check(groupedPlater.writes == 0, 'grouped Plater display never changes game settings')

-- Instances relinquish shared settings but still decorate accessible plates.
local instance = world()
instance.cvars.nameplateShowFriendlyPlayers = '1'
instance.original = copy(instance.cvars)
instance.units.member = { guid = 'Player-1-F', first = 'Our', surname = 'Healer', friend = true, player = true, party = true }
local instanceOutsider = instance:plate('stranger')
local instanceMember = instance:plate('member')
instance:load(); instance:flush()
instance.grouped, instance.instance = true, true
instanceMember.UnitFrame.forbidden = true
instance:fire('PLAYER_ENTERING_WORLD'); instance:flush()
instance:restored('instance entry releases shared temporary overrides')
check(instance:label(instanceOutsider).shown and instance:label(instanceOutsider).font[2] == 14, 'accessible outsider keeps custom styling inside an instance')
check(not instance:label(instanceMember).shown and instanceMember.UnitFrame.alpha == 0.8 and instanceMember.UnitFrame.healthBar.alpha == 0.8, 'restricted group plate keeps native health display')
check(instance.ns.DisplayStatus():find('accessible existing nameplates', 1, true), 'instance status describes limited styling rather than a blanket pause')
instanceMember.UnitFrame.forbidden = false; instance:tick()
check(instanceMember.UnitFrame.healthBar.alpha == 0.8, 'accessible group health display remains native after restrictions clear')
instance.instance = false; instance:fire('PLAYER_ENTERING_WORLD'); instance:flush()
check(instance:label(instanceOutsider).shown and instance.savedCVars.UnitNameFriendlyPlayerName == '1', 'leaving an instance resumes overrides without changing saved preferences')
instance:command('off'); instance:restored('instance transition and disable restore saved preferences')

local combatInstance = world()
local combatInstancePlate = combatInstance:plate('stranger')
combatInstance:load(); combatInstance:flush()
combatInstance.combat, combatInstance.instance = true, true
local combatInstanceWrites = combatInstance.writes
combatInstance:fire('PLAYER_ENTERING_WORLD'); combatInstance:flush()
check(combatInstance:label(combatInstancePlate).shown and combatInstance.writes == combatInstanceWrites, 'instance entry during combat preserves accessible styling without illegal setting changes')
check(combatInstance.ns.DisplayStatus():find('cleanup pending', 1, true), 'combat-delayed instance cleanup is visible in status')
combatInstance.combat = false; combatInstance:fire('PLAYER_REGEN_ENABLED'); combatInstance:flush()
combatInstance:restored('instance cleanup completes after combat ends')
check(combatInstance:label(combatInstancePlate).shown, 'instance cleanup does not disable accessible custom names')

-- Show only name is cosmetic: both checkbox directions must keep filtering active.
for _, clearsTemp in ipairs({ false, true }) do
    for _, originalFriendly in ipairs({ '0', '1' }) do
        for _, originalNamesOnly in ipairs({ '0', '1' }) do
            local toggles = world()
            local key = 'nameplateShowOnlyNameForFriendlyPlayerUnits'
            toggles.cvars.nameplateShowFriendlyPlayers = originalFriendly
            toggles.cvars[key] = originalNamesOnly
            toggles.original = copy(toggles.cvars)
            toggles.uiClearsTemp = clearsTemp
            local stranger, met = toggles:plate('stranger'), toggles:plate('acquaintance')
            toggles:load(); toggles:flush()
            toggles.target = 'acquaintance'; toggles:command('meet')
            for _, checked in ipairs({ false, true, false, true }) do
                local before = toggles.writes
                toggles:changeBlizzardSetting(key, checked)
                check(toggles.writes == before, 'Blizzard checkbox callback makes no inline CVar writes')
                toggles:flush()
                local expected = checked and '1' or '0'
                check(toggles.cvars[key] == expected and toggles.savedCVars[key] == expected, 'Show only name honors both checkbox directions: ' .. expected)
                check(toggles:label(stranger).shown and toggles:label(stranger).font[2] == 14 and toggles:label(met).shown and toggles:label(met).font[2] == 22,
                    'Show only name keeps met/unmet styling active')
                check(not toggles.ns.DisplayStatus():find('Filtering stopped', 1, true), 'Show only name does not cause a required-setting conflict')
                check(toggles.ns.GameSettings.temporary[key] == nil, 'Show only name temporary override is relinquished after user choice')
                if checked then
                    check(toggles:label(stranger).point[2] == stranger and toggles:label(stranger).point[5] == -40, 'names-only returns text to its normal offset')
                else
                    check(toggles:label(stranger).point[2] == stranger.UnitFrame.healthBar and toggles:label(stranger).point[5] >= 4, 'health mode moves even unmet names clear of native bars')
                end
                check(stranger.UnitFrame.healthBar.alpha == 0.8 and met.UnitFrame.healthBar.alpha == 0.8 and toggles.persistentWrites == 0,
                    'Show only name remains native health-bar control without persistent addon writes')
            end
            toggles:command('setup')
            check(toggles.cvars[key] == '1' and toggles.ns.GameSettings.temporary[key] == nil, 'setup does not reclaim a user-controlled names-only setting')
            toggles:changeBlizzardSetting(key, false); toggles:flush()
            toggles:option('affectEnemies', true)
            check(toggles.cvars[key] == '0' and toggles.ns.GameSettings.temporary[key] == nil and toggles:label(stranger).shown,
                'scope changes preserve a user-controlled health mode')
            toggles.original[key] = '0'
            toggles:command('off'); toggles:restored('disable preserves the latest user Show only name preference')
        end
    end
end
local combatToggle = world()
local combatTogglePlate = combatToggle:plate('stranger')
combatToggle:load(); combatToggle:flush()
combatToggle.combat = true
local combatToggleWrites = combatToggle.writes
combatToggle:changeBlizzardSetting('nameplateShowOnlyNameForFriendlyPlayerUnits', false); combatToggle:flush()
check(combatToggle.writes == combatToggleWrites and combatToggle:label(combatTogglePlate).shown, 'combat checkbox change does not stop filtering or write protected settings')
check(combatToggle.ns.DisplayStatus():find('Show only name', 1, true), 'combat pending checkbox change is reported')
combatToggle.combat = false; combatToggle:fire('PLAYER_REGEN_ENABLED'); combatToggle:flush()
check(combatToggle.cvars.nameplateShowOnlyNameForFriendlyPlayerUnits == '0' and combatToggle:label(combatTogglePlate).shown,
    'Show only name override is released after combat without requiring setup')
check(combatToggle.ns.lastShownStatus == combatToggle.ns.DisplayStatus(), 'pending Show only name status clears after combat')
local choiceRestart = world(copy(combatToggle.ns.db), copy(combatToggle.env.AcquaintedRuntime))
choiceRestart.cvars = copy(combatToggle.savedCVars)
choiceRestart:plate('stranger'); choiceRestart:load(); choiceRestart:flush()
check(choiceRestart.cvars.nameplateShowOnlyNameForFriendlyPlayerUnits == '0' and choiceRestart.ns.GameSettings.temporary.nameplateShowOnlyNameForFriendlyPlayerUnits == nil,
    'explicit Show only name choice survives reload/restart bookkeeping')

local aliasToggle = world()
aliasToggle.cvars.nameplateShowOnlyNameForFriendlyPlayerUnits = nil
aliasToggle.cvars.nameplateShowOnlyNames = '0'
aliasToggle:plate('stranger'); aliasToggle:load(); aliasToggle:flush()
aliasToggle:changeBlizzardSetting('nameplateShowOnlyNames', false); aliasToggle:flush()
check(aliasToggle.cvars.nameplateShowOnlyNames == '0', 'legacy Show only name alias releases temporary override')
aliasToggle:changeBlizzardSetting('nameplateShowOnlyNames', true); aliasToggle:flush()
check(aliasToggle.cvars.nameplateShowOnlyNames == '1', 'legacy Show only name alias can be reversed without setup')

local externalCosmetic = world()
local externalCosmeticPlate = externalCosmetic:plate('stranger')
externalCosmetic:load(); externalCosmetic:flush()
externalCosmetic.temporaryCVars.nameplateShowOnlyNameForFriendlyPlayerUnits = '0'
externalCosmetic.cvars.nameplateShowOnlyNameForFriendlyPlayerUnits = '0'
externalCosmetic:fire('CVAR_UPDATE', 'nameplateshowonlynameforfriendlyplayerunits', '0'); externalCosmetic:flush()
check(externalCosmetic:label(externalCosmeticPlate).shown and externalCosmetic.temporaryCVars.nameplateShowOnlyNameForFriendlyPlayerUnits == '0',
    'another addon cosmetic choice is preserved without stopping filtering')

for _, overlay in ipairs({ false, true }) do
    local untouchedChoice = world({ options = { overlayOnly = overlay } })
    untouchedChoice.instance = not overlay
    untouchedChoice:load(); untouchedChoice:flush()
    untouchedChoice:changeBlizzardSetting('nameplateShowOnlyNameForFriendlyPlayerUnits', true); untouchedChoice:flush()
    check(untouchedChoice.writes == 0 and not untouchedChoice.env.AcquaintedRuntime.nameOnlyUserControlled,
        'instance/overlay modes leave Show only name entirely under native control')
end

-- IC-only activation reads the current TRP3 player on each service pass.
local function setTRPStatus(testWorld, initial)
    testWorld.inCharacter = initial
    testWorld.env.AddOn_TotalRP3 = { Player = { GetCurrentUser = function()
        return { IsInCharacter = function() return testWorld.inCharacter end }
    end } }
end
local noTRP = world({ options = { onlyWhileIC = true } })
local noTRPPlate = noTRP:plate('stranger')
noTRP:load(); noTRP:flush()
check(noTRP:label(noTRPPlate).shown and noTRP.ns.IsEnabled(), 'IC-only preference has no effect without TRP3')

for _, mode in ipairs({ 'standalone', 'group', 'instance', 'overlay', 'plater' }) do
    local ic = world({ options = { onlyWhileIC = true }, known = { ['Player-1-A'] = { name = 'Aster Moon', nickname = 'Friend' } } })
    ic.grouped = mode == 'group'
    ic.instance = mode == 'instance'
    if mode == 'overlay' then ic.env.AcquaintedDB.options.overlayOnly = true end
    if mode == 'plater' then ic.env.Plater = {} end
    setTRPStatus(ic, false)
    local plate = ic:plate('stranger')
    ic:load(); ic:flush()
    check(ic.writes == 0 and plate.UnitFrame.name.alpha == 0.8 and not ic.ns.IsEnabled(), 'OOC login leaves native settings and names untouched: ' .. mode)
    check(ic.ns.DisplayStatus():find('OOC', 1, true) ~= nil, 'settings explain OOC pause: ' .. mode)
    ic.inCharacter = true; ic:tick()
    check(ic:label(plate).shown and ic:label(plate).text == 'Friend' and ic.ns.IsEnabled(), 'IC automatically activates names with saved nicknames: ' .. mode)
    ic.inCharacter = false; ic:tick()
    check(not ic:label(plate).shown and plate.UnitFrame.name.alpha == 0.8, 'OOC releases custom displays and native masks: ' .. mode)
    check(next(ic.temporaryCVars) == nil, 'OOC removes owned temporary settings: ' .. mode)
    check(ic.ns.db.options.enabled and ic.ns.db.known['Player-1-A'].nickname == 'Friend', 'pausing preserves enable preference and acquaintances: ' .. mode)
    ic:restored('OOC restores original effective settings: ' .. mode)
    ic.inCharacter = true; ic:tick()
    check(ic:label(plate).shown and ic.persistentWrites == 0, 'repeated IC transitions resume without persistent writes: ' .. mode)
    ic:command('off'); ic:tick()
    check(not ic:label(plate).shown, 'IC cannot override the main enable switch: ' .. mode)
end

local icCombat = world({ options = { onlyWhileIC = true } })
setTRPStatus(icCombat, true)
local icCombatPlate = icCombat:plate('stranger')
icCombat:load(); icCombat:flush()
icCombat.combat = true
local combatWrites = icCombat.writes
icCombat.inCharacter = false; icCombat:tick()
check(not icCombat:label(icCombatPlate).shown and icCombatPlate.UnitFrame.name.alpha == 0.8, 'OOC during combat releases labels and native text immediately')
check(icCombat.writes == combatWrites and icCombat.ns.GameSettings.HasPending(icCombat.ns.db), 'OOC during combat defers temporary settings cleanup')
check(icCombat.ns.DisplayStatus():find('combat', 1, true) ~= nil, 'OOC combat pause reports pending cleanup')
icCombat.combat = false; icCombat:fire('PLAYER_REGEN_ENABLED'); icCombat:flush()
icCombat:restored('OOC deferred cleanup finishes after combat')
icCombat.combat = true; icCombat.inCharacter = true; icCombat:tick()
check(not icCombat:label(icCombatPlate).shown and next(icCombat.temporaryCVars) == nil, 'IC activation waits rather than changing settings during combat')
icCombat.combat = false; icCombat:fire('PLAYER_REGEN_ENABLED'); icCombat:flush()
check(icCombat:label(icCombatPlate).shown, 'IC activation resumes automatically after combat')
icCombat.inCharacter = false; icCombat:tick()
check(icCombat:option('onlyWhileIC', false) and icCombat:label(icCombatPlate).shown, 'turning off IC-only mode activates displays while OOC')
icCombat:option('onlyWhileIC', true)
check(not icCombat:label(icCombatPlate).shown, 'enabling IC-only mode while OOC pauses displays')
icCombat.env.AddOn_TotalRP3.Player.GetCurrentUser = function() return { IsInCharacter = function() return true end } end
icCombat:tick()
check(icCombat:label(icCombatPlate).shown, 'switching TRP3 profiles uses the new current player status')
icCombat.env.AddOn_TotalRP3.Player.GetCurrentUser = function() return nil end
icCombat:tick()
check(not icCombat:label(icCombatPlate).shown and icCombat.ns.DisplayStatus():find('waiting for Total RP 3', 1, true), 'unready TRP3 player safely pauses and explains why')
icCombat.env.AddOn_TotalRP3.Player.GetCurrentUser = function() error('TRP3 is not ready') end
icCombat:tick()
check(not icCombat:label(icCombatPlate).shown, 'TRP3 API errors do not activate displays or escape the service')
setTRPStatus(icCombat, true); icCombat:tick()
check(icCombat:label(icCombatPlate).shown, 'TRP3 API recovery automatically resumes displays')
icCombat.env.AddOn_TotalRP3, icCombat.env.TRP3_API = nil, nil
icCombat:tick()
check(icCombat:label(icCombatPlate).shown, 'removing TRP3 returns to ordinary Acquainted behaviour')
local optOut = world()
setTRPStatus(optOut, false)
local optOutPlate = optOut:plate('stranger')
optOut:load(); optOut:flush()
check(not optOut.ns.db.options.onlyWhileIC and optOut:label(optOutPlate).shown, 'IC-only mode defaults off even with TRP3 OOC')
optOut.env.AddOn_TotalRP3.Player.GetCurrentUser = function() error('must not read status when disabled') end
optOut:tick()
check(optOut:label(optOutPlate).shown, 'disabled IC-only option does not consult TRP3 status')

local function TestRecentPlayers()
-- Recent encounters are bounded, kept by GUID, and independent of rendering.
local function countRecords(bucket)
    local count = 0
    for _ in pairs(bucket) do count = count + 1 end
    return count
end
local function recentPerson(testWorld, token, index, inParty)
    testWorld.units[token] = { guid = string.format('Player-1-%X', 1000 + index), first = 'Person', surname = tostring(index), player = true, friend = true, party = inParty }
    return testWorld.units[token].guid
end
local history = world()
local historyPlate = history:plate('stranger')
history:load(); history:flush()
check(history.ns.db.recent.nearby['Player-1-A'].name == 'Aster Moon', 'existing nearby plates are captured on activation')
local historyWrites = history.writes
history.ns.Recent.Clear()
for index = 1, 55 do
    history.now = history.now + 1
    recentPerson(history, 'party1', index, true)
    history:fire('GROUP_ROSTER_UPDATE')
end
check(countRecords(history.ns.db.recent.group) == 50, 'group history retains at most 50 players')
check(not history.ns.db.recent.group[string.format('Player-1-%X', 1001)] and history.ns.db.recent.group[string.format('Player-1-%X', 1055)], 'new group members evict the oldest group member')
local protectedGroup = copy(history.ns.db.recent.group)
for index = 101, 180 do
    history.now = history.now + 1
    recentPerson(history, 'crowd', index)
    history:fire('UNIT_NAME_UPDATE', 'crowd')
end
check(countRecords(history.ns.db.recent.group) == 50 and countRecords(history.ns.db.recent.nearby) == 50, 'crowded nearby encounters cannot consume group capacity')
for guid, record in pairs(protectedGroup) do
    check(history.ns.db.recent.group[guid].lastSeen == record.lastSeen, 'crowds preserve every group history record')
end
check(not history.ns.db.recent.nearby[string.format('Player-1-%X', 1101)] and history.ns.db.recent.nearby[string.format('Player-1-%X', 1180)], 'nearby evicts its own least recent encounters')
history:flush()
check(history.writes == historyWrites, 'recording encounters never writes nameplate settings')

local nearbyGuid = recentPerson(history, 'crowd', 160)
history.now = history.now + 1; history.ns.Recent.CaptureNearby('crowd')
local list = history.ns.Recent.List('PERSON 160')
check(#list.nearby == 1 and list.nearby[1].guid == nearbyGuid, 'recent search uses case-insensitive literal game names')
check(history.ns.Recent.List('').nearby[1].guid == nearbyGuid, 'repeat encounter refreshes recency without adding a second record')
history.units.party1 = history.units.crowd; history.units.party1.party = true
history:fire('GROUP_ROSTER_UPDATE'); history:flush()
check(history.ns.db.recent.group[nearbyGuid] and not history.ns.db.recent.nearby[nearbyGuid], 'joining a group promotes nearby entries without duplicates')
local formerGroupStamp = history.ns.db.recent.group[nearbyGuid].lastSeen
history.units.crowd.party = false; history.units.party1 = nil
history.now = history.now + 10; history:fire('GROUP_ROSTER_UPDATE'); history.ns.Recent.CaptureNearby('crowd')
check(history.ns.db.recent.group[nearbyGuid].lastSeen == formerGroupStamp and not history.ns.db.recent.nearby[nearbyGuid], 'nearby sightings do not reorder former group members')
history.units.crowd = nil
check(history.ns.Recent.Meet(nearbyGuid) and history.ns.db.known[nearbyGuid].name == 'Person 160', 'Meet works after a player leaves and their unit disappears')
check(not history.ns.db.recent.group[nearbyGuid] and not history.ns.db.recent.nearby[nearbyGuid], 'meeting frees both history slots')
check(not history.ns.Recent.Meet(nearbyGuid), 'stale recent Meet cannot overwrite an existing acquaintance')
history.ns.SetNickname(nearbyGuid, 'An old friend')
history.ns.Recent.Meet(nearbyGuid)
check(history.ns.db.known[nearbyGuid].nickname == 'An old friend', 'stale Meet preserves nicknames')

local reloadedHistory = world(copy(history.ns.db))
reloadedHistory.now = history.now
reloadedHistory.units.stranger = nil
reloadedHistory:load(); reloadedHistory:flush()
check(countRecords(reloadedHistory.ns.db.recent.group) == 49 and countRecords(reloadedHistory.ns.db.recent.nearby) == 49, 'separate histories survive reload')
check(reloadedHistory.ns.db.known[nearbyGuid].nickname == 'An old friend', 'reload preserves permanent acquaintances independently')
reloadedHistory.ns.Recent.Clear()
check(countRecords(reloadedHistory.ns.db.recent.group) == 0 and countRecords(reloadedHistory.ns.db.recent.nearby) == 0 and reloadedHistory.ns.db.known[nearbyGuid], 'clear history leaves permanent acquaintances untouched')

local delayedRecent = world()
delayedRecent:load(); delayedRecent:flush()
local delayedGuid = recentPerson(delayedRecent, 'party1', 501, true)
delayedRecent.units.party1.first = nil
delayedRecent:fire('GROUP_ROSTER_UPDATE')
check(not delayedRecent.ns.db.recent.group[delayedGuid], 'missing names are not stored as incomplete encounters')
delayedRecent.units.party1.first = 'Later'; delayedRecent:tick()
check(delayedRecent.ns.db.recent.group[delayedGuid].name == 'Later 501', 'pending roster identity retries succeed without another roster event')
local reusedGuid = recentPerson(delayedRecent, 'party1', 502, true)
delayedRecent.units.party1.first = nil; delayedRecent:fire('GROUP_ROSTER_UPDATE')
recentPerson(delayedRecent, 'party1', 503, true); delayedRecent:tick()
check(not delayedRecent.ns.db.recent.group[reusedGuid], 'pending captures do not associate reused unit tokens with the previous player')
local absentGuid = recentPerson(delayedRecent, 'party1', 504, true)
delayedRecent.units.party1.first = nil; delayedRecent:fire('GROUP_ROSTER_UPDATE')
for _ = 1, 42 do delayedRecent:tick() end
delayedRecent.units.party1.first = 'TooLate'; delayedRecent:tick()
check(not delayedRecent.ns.db.recent.group[absentGuid], 'missing identities expire rather than retrying forever')
delayedRecent.units.raid1 = delayedRecent.units.party1; delayedRecent.units.party1 = nil; delayedRecent.raid = true
delayedRecent:fire('GROUP_ROSTER_UPDATE')
check(delayedRecent.ns.db.recent.group[absentGuid].source == 'raid', 'raid roster members are captured without a nameplate')

local restrictedRecent = world({ options = { enabled = false } })
restrictedRecent:load(); restrictedRecent:flush()
recentPerson(restrictedRecent, 'party1', 601, true)
restrictedRecent:fire('GROUP_ROSTER_UPDATE'); restrictedRecent:fire('UNIT_NAME_UPDATE', 'party1'); restrictedRecent:flush()
check(countRecords(restrictedRecent.ns.db.recent.group) == 0, 'disabled Acquainted does not collect new history')
restrictedRecent:command('on')
check(countRecords(restrictedRecent.ns.db.recent.group) == 1, 'enabling captures current roster even without a new roster event')
restrictedRecent.ns.Recent.Clear()
restrictedRecent.units.secret = { guid = { secret = true }, first = 'Secret', player = true, friend = true }
restrictedRecent.ns.Recent.CaptureNearby('secret')
restrictedRecent.ns.Recent.CaptureNearby('player'); restrictedRecent.ns.Recent.CaptureNearby('npc')
check(countRecords(restrictedRecent.ns.db.recent.nearby) == 0, 'restricted identities, self and NPCs never enter history')
setTRPStatus(restrictedRecent, false); restrictedRecent:option('onlyWhileIC', true)
restrictedRecent:fire('GROUP_ROSTER_UPDATE'); restrictedRecent:flush()
check(countRecords(restrictedRecent.ns.db.recent.group) == 0, 'OOC pause respects IC-only history capture')

local recentUI = world()
recentUI:load(); recentUI:flush()
recentUI.ns.Recent.Clear()
local uiGroup = recentPerson(recentUI, 'party1', 701, true)
recentUI.env.AddOn_TotalRP3 = { Player = { CreateFromUnit = function(token)
    return { GetRoleplayingName = function() return token == 'party1' and '|cff00ff00The Scholar|r' or 'A passerby' end }
end } }
recentUI:fire('GROUP_ROSTER_UPDATE')
local uiNear = recentPerson(recentUI, 'nearby', 702)
recentUI:fire('UNIT_NAME_UPDATE', 'nearby'); recentUI:flush()
recentUI.units.party1, recentUI.units.nearby = nil, nil
local rui = recentUI.env
click(recentUI, rui.Acquainted_AcquaintancesTab); click(recentUI, rui.Acquainted_RecentPlayers)
check(not rui.Acquainted_Export.shown and not rui.Acquainted_Import.shown and rui.Acquainted_ClearHistory.shown, 'recent view uses clear history instead of export/import actions')
local function recentVisibleRows()
    local result = {}
    for _, frame in ipairs(recentUI.frames) do
        if frame.parent == rui.Acquainted_AcquaintanceList and frame.kind == 'Frame' and frame.shown then result[#result + 1] = frame end
    end
    return result
end
local recentMatches = recentVisibleRows()
check(#recentMatches == 2 and recentMatches[1].guid == uiGroup and recentMatches[2].guid == uiNear, 'recent UI places group members before nearby encounters')
check(recentMatches[1].label.text == 'The Scholar' and recentMatches[1].detail.text:find('Person 701', 1, true), 'recent rows show RP names with game identity and encounter details')
check(recentMatches[1].label.wordWrap == false and recentMatches[1].detail.wordWrap == false, 'long RP names cannot wrap over adjacent rows')
rui.Acquainted_Search:SetText('scholar')
check(#recentVisibleRows() == 1 and recentVisibleRows()[1].guid == uiGroup, 'recent UI searches RP names')
local clickedRecentMeet
for _, frame in ipairs(recentUI.frames) do
    if frame.parent == recentVisibleRows()[1] and frame.text == 'Meet' then clickedRecentMeet = frame end
end
check(clickedRecentMeet ~= nil, 'recent player rows offer a Meet action')
click(recentUI, clickedRecentMeet)
check(recentUI.ns.db.known[uiGroup] and #recentVisibleRows() == 0, 'recent Meet immediately updates the filtered list after the group disbands')
rui.Acquainted_Search:SetText('')
click(recentUI, rui.Acquainted_ClearHistory)
check(rui.Acquainted_ClearHistoryDialog.shown, 'clearing history first opens a confirmation')
click(recentUI, rui.Acquainted_CancelClearHistory)
check(not rui.Acquainted_ClearHistoryDialog.shown and recentUI.ns.db.recent.nearby[uiNear], 'cancel preserves history')
click(recentUI, rui.Acquainted_ClearHistory); click(recentUI, rui.Acquainted_ConfirmClearHistory)
check(#recentVisibleRows() == 0 and recentUI.ns.db.known[uiGroup], 'confirmed clear empties history without forgetting acquaintances')
click(recentUI, clickedRecentMeet)
check(recentUI.ns.db.known[uiGroup].name == 'Person 701', 'stale row action after clear cannot mutate an acquaintance')
click(recentUI, rui.Acquainted_SavedPlayers)
check(rui.Acquainted_Export.shown and rui.Acquainted_Import.shown and not rui.Acquainted_ClearHistory.shown, 'saved view retains its existing export/import controls')
check(#recentVisibleRows() == 1 and recentVisibleRows()[1].guid == uiGroup, 'recently met player appears in saved acquaintances')

-- Recent rows stay pinned until the user explicitly refreshes or reopens them.
click(recentUI, rui.Acquainted_RecentPlayers)
local listCalls, realRecentList = 0, recentUI.ns.Recent.List
recentUI.ns.Recent.List = function(query) listCalls = listCalls + 1; return realRecentList(query) end
recentUI.category.frame:Hide()
recentPerson(recentUI, 'newcomer', 801)
recentUI:fire('UNIT_NAME_UPDATE', 'newcomer'); recentUI.now = recentUI.now + 1; recentUI:flush()
check(listCalls == 0, 'hidden settings do not rebuild recent lists when encounters arrive')
recentUI.category.frame:Show(); recentUI.ns.RefreshSettings(); listCalls = 0
for index = 802, 810 do
    recentPerson(recentUI, 'newcomer', index)
    recentUI:fire('UNIT_NAME_UPDATE', 'newcomer'); recentUI:flush()
end
check(listCalls == 0, 'same-second arrivals do not repeatedly rebuild the open recent list')
recentUI.now = recentUI.now + 1; recentUI:tick()
check(listCalls == 0, 'new encounters cannot reorder rows under a visible Meet button')
recentUI.now = recentUI.now + 60; recentUI:tick()
check(listCalls == 0, 'idle timers cannot replace the displayed recent list')
rui.Acquainted_Search:SetText('Person 810')
check(#recentVisibleRows() == 0 and listCalls == 0, 'searching uses the same pinned list rather than loading new encounters')
rui.Acquainted_Search:SetText('')
click(recentUI, rui.Acquainted_RefreshRecent)
check(listCalls == 1 and #recentVisibleRows() == 10, 'Refresh list explicitly loads all new encounters')
local pinnedGuid = string.format('Player-1-%X', 1801)
local pinnedButton
for _, row in ipairs(recentVisibleRows()) do
    if row.guid == pinnedGuid then
        for _, frame in ipairs(recentUI.frames) do
            if frame.parent == row and frame.text == 'Meet' then pinnedButton = frame end
        end
    end
end
check(pinnedButton ~= nil, 'snapshot contains a Meet button for its oldest nearby encounter')
for index = 811, 880 do
    recentPerson(recentUI, 'newcomer', index)
    recentUI.now = recentUI.now + 1
    recentUI:fire('UNIT_NAME_UPDATE', 'newcomer'); recentUI:flush()
end
check(not recentUI.ns.db.recent.nearby[pinnedGuid] and #recentVisibleRows() == 10 and listCalls == 1, 'even history eviction cannot replace the visible snapshot')
click(recentUI, pinnedButton)
check(recentUI.ns.db.known[pinnedGuid] and recentUI.ns.db.known[pinnedGuid].name == 'Person 801', 'pinned Meet still works after a crowd evicts its stored encounter')
local exportRecentOnly = recentUI.ns.ExportPeople()
check(not exportRecentOnly:find('Person 810', 1, true), 'recent history is excluded from acquaintance exports')

local rapidGroup = world()
rapidGroup:load(); rapidGroup:flush()
local rapidGuid = recentPerson(rapidGroup, 'party1', 901, true)
rapidGroup:fire('GROUP_ROSTER_UPDATE')
rapidGroup.units.party1 = nil; rapidGroup:fire('GROUP_ROSTER_UPDATE'); rapidGroup:flush()
check(rapidGroup.ns.db.recent.group[rapidGuid] ~= nil, 'roster identities are captured before a same-frame disband can invalidate tokens')
rapidGroup.combat = true
recentPerson(rapidGroup, 'party1', 902, true)
local rapidWrites = rapidGroup.writes
rapidGroup:fire('GROUP_ROSTER_UPDATE'); rapidGroup:flush()
check(rapidGroup.ns.db.recent.group[string.format('Player-1-%X', 1902)] and rapidGroup.writes == rapidWrites, 'combat roster history never changes protected settings')

local importedHistory = world()
importedHistory:load(); importedHistory:flush()
check(importedHistory.ns.db.recent.nearby['Player-1-A'], 'nearby player exists before import')
check(importedHistory.ns.ImportPeople('ACQUAINTED:1\nPlayer-1-A\tAster Moon\t', false, false), 'import can permanently meet a recent player')
check(not importedHistory.ns.db.recent.nearby['Player-1-A'], 'import frees recent history slots for newly saved acquaintances')

local badHistory = world({ recent = { group = {
    ['Player-1-AAA'] = { name = 'Good', lastSeen = 1699999999, order = 1 },
    ['Player-1-AAB'] = { name = 'Future', lastSeen = math.huge, order = 2 },
    ['Player-1-AAC'] = { name = 42, lastSeen = 1699999999, order = 3 },
    ['Player-1-AAD'] = { name = 'No time' },
}, nearby = {
    ['Player-1-AAA'] = { name = 'Duplicate', lastSeen = 1699999999, order = 1 },
    ['Creature-1-ABC'] = { name = 'NPC', lastSeen = 1699999999, order = 1 },
} } })
badHistory.units.stranger = nil
badHistory:load(); badHistory:flush()
check(countRecords(badHistory.ns.db.recent.group) == 1 and countRecords(badHistory.ns.db.recent.nearby) == 0, 'reload normalizes malformed history and removes duplicate identities')

end
TestRecentPlayers()

local function TestSettingsNavigation()
    local navigation = world()
    navigation:load(); navigation:flush()
    local env = navigation.env
    local baselineWrites = navigation.writes
    for _, key in ipairs({ 'Appearance', 'Recognition', 'Acquaintances', 'Help' }) do
        local tab = env['Acquainted_' .. key .. 'Tab']
        check(tab.template == 'PanelTopTabButtonTemplate' and tab:GetText() == key, 'main navigation uses native tabs with plain labels: ' .. key)
        check(tab.selected == (key == 'Appearance'), 'native selection matches initially visible page: ' .. key)
    end
    check(env.Acquainted_AppearanceTab.LeftActive.shown and not env.Acquainted_AppearanceTab.enabled, 'selected native tab uses active artwork and cannot be clicked again')
    check(not env.Acquainted_HelpTab.LeftActive.shown and env.Acquainted_HelpTab.enabled, 'unselected native tab stays available')
    click(navigation, env.Acquainted_AcquaintancesTab)
    check(env.Acquainted_AcquaintancesTab.LeftActive.shown and not env.Acquainted_AppearanceTab.LeftActive.shown, 'main tab changes update native artwork')
    check(env.Acquainted_SavedPlayers:GetText() == 'Saved' and env.Acquainted_RecentPlayers:GetText() == 'Recent', 'secondary tabs use concise labels')
    check(env.Acquainted_SavedPlayers.parent ~= env.Acquainted_AcquaintancesTab.parent and env.Acquainted_SavedPlayers.width < env.Acquainted_AcquaintancesTab.width, 'secondary tabs have their own bar and smaller size')
    check(env.Acquainted_SavedPlayers.selected and env.Acquainted_AcquaintancesTab.selected, 'main and secondary selection coexist')
    click(navigation, env.Acquainted_RecentPlayers)
    check(env.Acquainted_RecentPlayers.LeftActive.shown and not env.Acquainted_SavedPlayers.LeftActive.shown, 'secondary selection uses native artwork')
    check(env.Acquainted_RefreshRecent.template == 'UIPanelButtonTemplate' and env.Acquainted_ClearHistory.template == 'UIPanelButtonTemplate', 'actions retain ordinary buttons')
    env.Acquainted_Search:SetText('Aster')
    env.Acquainted_AcquaintancesPage:SetVerticalScroll(42)
    local recentCalls, originalList = 0, navigation.ns.Recent.List
    navigation.ns.Recent.List = function(query) recentCalls = recentCalls + 1; return originalList(query) end
    click(navigation, env.Acquainted_RecentPlayers)
    click(navigation, env.Acquainted_AcquaintancesTab)
    check(env.Acquainted_Search:GetText() == 'Aster' and env.Acquainted_AcquaintancesPage:GetVerticalScroll() == 42 and recentCalls == 0, 'clicking active navigation preserves search, scroll, and pinned recent entries')
    env.Acquainted_AcquaintancesTab.scripts.OnShow(env.Acquainted_AcquaintancesTab)
    env.Acquainted_RecentPlayers.scripts.OnShow(env.Acquainted_RecentPlayers)
    check(env.Acquainted_AcquaintancesTab.width == 144 and env.Acquainted_RecentPlayers.width == 112, 'native show-time sizing preserves separate tab widths')
    click(navigation, env.Acquainted_HelpTab)
    check(env.Acquainted_HelpTab.selected and not env.Acquainted_AcquaintancesTab.selected and not env.Acquainted_Search:HasFocus(), 'navigation to Help selects its tab and releases search focus')
    check(navigation.writes == baselineWrites, 'native navigation never changes game settings')

    local legacy = world()
    local originalCreate = legacy.env.CreateFrame
    legacy.env.CreateFrame = function(kind, name, parent, template)
        if template == 'PanelTopTabButtonTemplate' then error('template unavailable') end
        return originalCreate(kind, name, parent, template)
    end
    legacy:load(); legacy:flush()
    check(legacy.env.Acquainted_AppearanceTab.template == 'PanelTabButtonTemplate' and legacy.env.Acquainted_AppearanceTab.LeftActive.shown, 'clients without top tabs can use the standard native tab template')
    click(legacy, legacy.env.Acquainted_AcquaintancesTab)
    click(legacy, legacy.env.Acquainted_RecentPlayers)
    check(legacy.env.Acquainted_RecentPlayers.selected, 'standard native fallback supports secondary navigation')

    local minimal = world()
    minimal.env.PanelTemplates_SelectTab = false
    minimal:load(); minimal:flush()
    check(minimal.env.Acquainted_AppearanceTab.template == nil and minimal.env.Acquainted_AppearanceTab.selectionLine.shown, 'clients without native tab helpers retain text navigation with a selected underline')
    click(minimal, minimal.env.Acquainted_HelpTab)
    check(minimal.env.Acquainted_HelpPage.shown and minimal.env.Acquainted_HelpTab.selectionLine.shown and not minimal.env.Acquainted_AppearanceTab.selectionLine.shown, 'minimal fallback keeps settings accessible and selection visible')
end
TestSettingsNavigation()

local function TestRecognitionColours()
    local guid = 'Player-1-A'
    local function communities(testWorld)
        testWorld.env.Enum = { ClubType = { Guild = 0, Character = 1, BattleNet = 2 }, BattleNetFriendLevel = { Title = 3, BattleTag = 2, RealID = 1 } }
        testWorld.clubs = { { clubId = 11, clubType = 1, name = 'Wayfarers' }, { clubId = 12, clubType = 1, name = 'Adventurers' },
            { clubId = 99, clubType = 0, name = 'The guild' }, { clubId = 98, clubType = 2, name = 'Account community' } }
        testWorld.clubReady, testWorld.clubGuids, testWorld.focusRequests, testWorld.clubReads = true, { guid }, 0, 0
        testWorld.env.C_Club = {
            GetSubscribedClubs = function() testWorld.clubReads = testWorld.clubReads + 1; return testWorld.clubs end,
            AreMembersReady = function() return testWorld.clubReady end,
            FocusMembers = function() testWorld.focusRequests = testWorld.focusRequests + 1 end,
            GetClubMembers = function(id) return id == 11 and testWorld.clubGuids or {} end,
            GetMemberInfo = function(_, memberId) return { guid = memberId } end,
        }
    end
    local function near(expected, label)
        local r, g, b = tonumber(expected:sub(1,2),16)/255, tonumber(expected:sub(3,4),16)/255, tonumber(expected:sub(5,6),16)/255
        return label.color[1] == r and label.color[2] == g and label.color[3] == b
    end
    for _, kind in ipairs({ 'guild', 'wowFriend', 'battleNetFriend', 'characterFriend', 'trpRelation', 'community', 'group' }) do
        local coloured = world({ options = { hideUnmet = true }, communities = { ['11'] = true } })
        communities(coloured)
        if kind == 'guild' then coloured.guild = guid
        elseif kind == 'wowFriend' or kind == 'battleNetFriend' then
            coloured.env.C_BattleNet.GetAccountInfoByGUID = function() return { isFriend = true, friendLevel = kind == 'wowFriend' and 3 or 2 } end
        elseif kind == 'characterFriend' then coloured.friend = guid
        elseif kind == 'trpRelation' then
            coloured.env.TRP3_API = { utils = { str = { getUnitID = function() return 'person' end } },
                register = { getUnitIDProfileID = function() return 'profile' end, relation = { getRelation = function() return { id = 'FRIEND' } end } } }
        elseif kind == 'group' then coloured.units.stranger.party = true end
        local plate = coloured:plate('stranger')
        coloured:load(); coloured:flush()
        local category
        for _, rule in ipairs(coloured.ns.recognitionCategories) do if rule.id == kind then category = rule end end
        coloured:option(category.option, true)
        check(coloured:label(plate).shown and near('FFD100', coloured:label(plate)), 'category inherits the existing met colour: ' .. kind)
        local writes = coloured.writes
        coloured:option(category.colourKey, '12ABEF'); coloured:option(category.modeKey, 'custom')
        check(near('12ABEF', coloured:label(plate)) and near('12ABEF', plate.labels[2]), 'custom colour applies to name and guild line: ' .. kind)
        check(coloured:label(plate).font[2] == 22 and coloured.ns.db.options.nameOffset == -40, 'category overrides leave met size and position shared: ' .. kind)
        coloured:command('meet My nickname')
        check(coloured:label(plate).text == 'My nickname' and near('12ABEF', coloured:label(plate)), 'manual Meet and nickname preserve category colour: ' .. kind)
        coloured:option(category.option, false)
        check(near('FFD100', coloured:label(plate)), 'disabled category no longer overrides a manually met person: ' .. kind)
        check(coloured.writes == writes, 'category recognition and colours never write nameplate settings: ' .. kind)
    end
    local overlap = world({ options = { showWoWFriends = true, showGroup = true, showGuild = true,
        guildColourMode = 'custom', guildColour = '00FF00', groupColourMode = 'custom', groupColour = 'FF0000',
        wowFriendColourMode = 'custom', wowFriendColour = '0000FF' } })
    communities(overlap); overlap.guild = guid; overlap.units.stranger.party = true
    overlap.env.C_BattleNet.GetAccountInfoByGUID = function() return { isFriend = true, friendLevel = 3 } end
    local overlapPlate = overlap:plate('stranger')
    overlap.units.pet = { guid = 'Pet-1-ABC', first = 'Companion', player = false, friend = true, pet = true, owner = guid }
    local petPlate = overlap:plate('pet')
    overlap:load(); overlap:flush()
    check(near('00FF00', overlap:label(overlapPlate)) and near('00FF00', overlap:label(petPlate)), 'guild colour wins overlaps and companions follow owner colour')
    overlap:option('guildColourMode', 'met')
    check(near('0000FF', overlap:label(overlapPlate)), 'inherited Met colour does not block a lower custom colour')
    overlap:option('showWoWFriends', false)
    check(near('FF0000', overlap:label(overlapPlate)), 'disabling a higher category reveals the next matching custom colour')
    overlap:option('groupColourMode', 'met'); overlap:option('metColour', 'ABCDEF')
    check(near('ABCDEF', overlap:label(overlapPlate)), 'all inherited categories follow live edits to Met colour')
    overlap:option('guildColourMode', 'custom'); overlap.ns.ResetAppearance('met'); overlap:flush()
    check(near('00FF00', overlap:label(overlapPlate)), 'resetting the base Met style preserves category overrides')
    overlap.ns.ResetAppearance('all'); overlap:flush()
    check(near('FFD100', overlap:label(overlapPlate)) and overlap.ns.db.options.guildColourMode == 'met', 'reset all appearance restores inherited category colours')
    check(not overlap:option('guildColourMode', 'bogus') and not overlap:option('guildColour', 'not hex'), 'invalid category modes and colours are rejected')

    local old = world({ options = { showFriends = true } }); old:load(); old:flush()
    check(old.ns.db.options.showFriends and old.ns.db.options.showWoWFriends and old.ns.db.options.showBattleNetFriends, 'legacy combined Friends preference migrates to all three friend types')
    local explicit = world({ options = { showFriends = true, showWoWFriends = false, showBattleNetFriends = false } }); explicit:load(); explicit:flush()
    check(not explicit.ns.db.options.showWoWFriends and not explicit.ns.db.options.showBattleNetFriends, 'migration preserves explicit split friend preferences')
    local nonfriend = world({ options = { showBattleNetFriends = true, hideUnmet = true } })
    nonfriend.env.C_BattleNet.GetAccountInfoByGUID = function() return { isFriend = false } end
    local nonfriendPlate = nonfriend:plate('stranger'); nonfriend:load(); nonfriend:flush()
    check(not nonfriend:label(nonfriendPlate).shown, 'account information for a non-friend never grants recognition')
    nonfriend.env.Enum = { BattleNetFriendLevel = { Title = 3 } }
    nonfriend.env.C_BattleNet.GetAccountInfoByGUID = function() return { isFriend = true, friendLevel = 3 } end
    nonfriend:fire('BN_FRIEND_INFO_CHANGED'); nonfriend:flush()
    check(not nonfriend:label(nonfriendPlate).shown, 'WoW Friends do not leak into the Battle.net category')
    nonfriend:option('showWoWFriends', true)
    check(nonfriend:label(nonfriendPlate).shown, 'WoW Friends recognition works independently')
    nonfriend.env.C_BattleNet.GetAccountInfoByGUID = function() return { isFriend = true, friendLevel = { secret = true } } end
    nonfriend:fire('BN_FRIEND_INFO_CHANGED'); nonfriend:flush()
    check(not nonfriend:label(nonfriendPlate).shown, 'restricted friend levels cannot be misclassified')

    local club = world({ options = { hideUnmet = true, showCommunities = true, communityColourMode = 'custom', communityColour = '4488CC' } })
    communities(club); club.clubReady = false
    local clubPlate = club:plate('stranger'); club:load(); club:flush()
    check(not club:label(clubPlate).shown and club.focusRequests == 0, 'unselected communities never grant recognition or request rosters')
    check(#club.ns.Social.clubs == 2 and not club.ns.SetCommunitySelected('99', true), 'community chooser excludes guild and account-only clubs')
    check(club.ns.SetCommunitySelected('11', true), 'community selection accepts a joined character community')
    club:flush()
    check(club.focusRequests == 1 and club.ns.Social.loadingCount == 1 and not club:label(clubPlate).shown, 'selected community requests its roster once and waits for readable membership')
    for _ = 1, 20 do club:tick() end
    check(club.focusRequests == 1, 'ordinary rendering never repeatedly requests community rosters')
    club.clubReady = true; club:fire('CLUB_MEMBERS_UPDATED', 11); club:flush()
    check(club:label(clubPlate).shown and near('4488CC', club:label(clubPlate)) and not club.ns.db.known[guid], 'community roster event recognises by GUID without permanently meeting')
    local clubReads, writes = club.clubReads, club.writes
    club:option('communityColour', '123456')
    check(club.clubReads == clubReads and club.writes == writes, 'colour changes neither enumerate rosters nor change nameplate settings')
    club.clubGuids = {}; club:fire('CLUB_MEMBER_REMOVED', 11); club:flush()
    check(not club:label(clubPlate).shown, 'leaving a selected community removes automatic recognition')
    club.clubGuids = { guid }; club:fire('CLUB_MEMBER_ADDED', 11); club:flush()
    club.ns.SetCommunitySelected('11', false); club:flush()
    check(not club:label(clubPlate).shown, 'deselecting a community removes its recognition immediately')
    club.ns.SetCommunitySelected('11', true); club:flush()
    club.clubs = {}; club:fire('CLUB_REMOVED', 11); club:flush()
    check(not club:label(clubPlate).shown and #club.ns.Social.clubs == 0, 'removed subscriptions do not leave stale membership')

    local delta = world({ options = { showCommunities = true }, communities = { ['11'] = true, ['12'] = true } })
    communities(delta)
    delta.env.C_Club.GetClubMembers = function() return { guid } end
    local memberReads = 0
    delta.env.C_Club.GetMemberInfo = function(_, id) memberReads = memberReads + 1; return { guid = id } end
    delta:load(); delta:flush()
    local rosterReads = delta.clubReads
    memberReads = 0
    delta:fire('CLUB_MEMBER_PRESENCE_UPDATED', 11, guid); delta:flush()
    check(memberReads == 1 and delta.clubReads == rosterReads, 'presence changes read only the changed member rather than whole rosters')
    delta:fire('CLUB_MEMBER_REMOVED', 11, guid); delta:flush()
    check(delta.ns.Social.IsCommunityMember(guid), 'overlapping communities retain recognition when one membership ends')
    delta:fire('CLUB_MEMBER_REMOVED', 12, guid); delta:flush()
    check(not delta.ns.Social.IsCommunityMember(guid), 'removing the final selected membership clears recognition')
    delta:fire('CLUB_MEMBER_ADDED', 11, guid); delta:flush()
    check(delta.ns.Social.IsCommunityMember(guid), 'incremental additions restore recognition by GUID')
    delta.env.C_Club.GetMemberInfo = function() return { guid = { secret = true } } end
    delta:fire('CLUB_MEMBER_UPDATED', 11, guid); delta:flush()
    check(not delta.ns.Social.IsCommunityMember(guid), 'restricted member IDs are never resolved by name or stale identity')
    local hiddenUpdates = 0
    local hiddenDropdown = delta.env.Acquainted_guildColourMode
    local originalUpdate = hiddenDropdown.Update
    hiddenDropdown.Update = function(self) hiddenUpdates = hiddenUpdates + 1; originalUpdate(self) end
    delta.category.frame:Hide()
    delta.env.C_Club.GetMemberInfo = function(_, id) return { guid = id } end
    delta:fire('CLUB_MEMBER_ADDED', 11, guid); delta:flush()
    check(hiddenUpdates == 0 and delta.ns.Social.IsCommunityMember(guid), 'background roster events update membership without rebuilding hidden settings controls')
    local unavailable = world({ options = { showCommunities = true }, known = { [guid] = { name = 'Aster Moon' } } })
    local unavailablePlate = unavailable:plate('stranger'); unavailable:load(); unavailable:flush()
    check(unavailable:label(unavailablePlate).shown and not unavailable.env.Acquainted_CommunityPicker.enabled, 'missing community API leaves normal acquaintances and settings working')

    local ui = world({ options = { showGuild = true } }); ui.guild = guid; communities(ui)
    local uiPlate = ui:plate('stranger'); ui:load(); ui:flush()
    local env = ui.env
    click(ui, env.Acquainted_RecognitionTab)
    check(env.Acquainted_guildColourMode:GetText() == 'Met colour' and not env.Acquainted_guildColourButton.shown, 'category UI starts with inherited colour and a hidden custom swatch')
    env.Acquainted_guildColourMode.menuItems[2].callback(); ui:flush()
    check(env.Acquainted_guildColourButton.shown and env.Acquainted_guildColourMode:GetText() == 'Custom colour', 'native colour dropdown reveals the custom swatch')
    click(ui, env.Acquainted_guildColourButton)
    local picker = env.ColorPickerFrame
    picker.selected = { .2, .4, .6 }; picker.options.swatchFunc(); ui:flush()
    check(near('336699', ui:label(uiPlate)), 'category picker previews colour changes on live names')
    picker.options.cancelFunc(); picker:Hide(); ui:flush()
    check(near('FFD100', ui:label(uiPlate)), 'cancelling the category picker restores its previous colour')
    click(ui, env.Acquainted_showCommunitiesCheck)
    env.Acquainted_showCommunitiesCheck:SetChecked(true); click(ui, env.Acquainted_showCommunitiesCheck)
    local selectedKey
    for _, entry in ipairs(env.Acquainted_CommunityPicker.menuItems) do if entry.text == 'Wayfarers' then selectedKey = entry; break end end
    check(selectedKey ~= nil and env.Acquainted_CommunityPicker.enabled, 'joined communities appear in the native multi-select picker')
    selectedKey.callback(); ui:flush()
    check(ui.ns.db.communities['11'] == true and ui.ns.Social.selectedCount == 1, 'community picker saves the selected community')

    local paused = world({ options = { showCommunities = true, onlyWhileIC = true }, communities = { ['11'] = true } })
    communities(paused); paused.clubReady = false; setTRPStatus(paused, false)
    paused:load(); paused:flush()
    check(paused.focusRequests == 0, 'IC-only pause defers community roster requests')
    paused.inCharacter = true; paused:tick()
    check(paused.focusRequests == 1, 'resuming IC loads selected community rosters')
end
TestRecognitionColours()

print('Acquainted: ' .. checks .. ' checks passed')
return {}
