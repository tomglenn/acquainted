local _, ns = ...
local panel, category, refreshing, selectedTab, search, nicknameEditor
local checks, sliders, values, rows, colours, previews, pages, tabs = {}, {}, {}, {}, {}, {}, {}, {}
local transferDialog, displayChoices, overlayCaption
local peopleView = "saved"
local recentRows, recentHeaders, peopleChoices = {}, {}, {}
local peopleTitle, peopleSubtitle, recentClearDialog
local recentNeedsRefresh, recentSnapshot = false, nil
local PEOPLE_LIST_TOP = 172
local recognitionControls, communityPicker, communityStatus = {}, nil, nil
local communityMenuRevision = -1
local pickerSession, pickerHooked

local function Text(parent, text, font, x, y, width)
    local label = parent:CreateFontString(nil, "ARTWORK", font or "GameFontHighlight")
    label:SetPoint("TOPLEFT", x, y)
    if width then label:SetWidth(width); label:SetJustifyH("LEFT") end
    label:SetText(text)
    return label
end
local function Background(frame, r, g, b, a)
    local texture = frame:CreateTexture(nil, "BACKGROUND")
    texture:SetAllPoints()
    texture:SetColorTexture(r, g, b, a)
end
local function Tooltip(frame, title, description)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title)
        GameTooltip:AddLine(description, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end
local function Button(parent, text, width, x, y, onClick, name)
    local button = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 24)
    button:SetPoint("TOPLEFT", x, y)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end
-- Keep navigation visually distinct from actions. Each bar owns its native
-- tabs so Blizzard's automatic sizing never mixes the two navigation levels.
local function TabBar(parent, x, y, width, tabWidth)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetPoint("TOPLEFT", x, y)
    bar:SetSize(width, 32)
    bar.minTabWidth, bar.maxTabWidth, bar.tabPadding = tabWidth, tabWidth, 16
    local line = bar:CreateTexture(nil, "BACKGROUND")
    line:SetColorTexture(0.45, 0.36, 0.18, 0.65)
    line:SetPoint("BOTTOMLEFT", 0, 0)
    line:SetSize(width, 1)
    return bar
end
local function SetTabSelected(tab, selected)
    tab.selected = selected
    if tab.nativeNavigation then
        if selected then PanelTemplates_SelectTab(tab) else PanelTemplates_DeselectTab(tab) end
    else
        tab.navigationLabel:SetTextColor(selected and 1 or 0.85, selected and 1 or 0.7, selected and 1 or 0.4)
        tab.selectionLine:SetShown(selected)
        tab:SetEnabled(not selected)
    end
end
local function NavigationTab(bar, title, index, onClick, name)
    local tab
    if type(PanelTemplates_SelectTab) == "function" and type(PanelTemplates_DeselectTab) == "function"
        and type(PanelTemplates_TabResize) == "function" then
        for _, template in ipairs({ "PanelTopTabButtonTemplate", "PanelTabButtonTemplate" }) do
            local ok, frame = pcall(CreateFrame, "Button", name, bar, template)
            if ok and frame then tab = frame; tab.nativeNavigation = true; break end
        end
    end
    if not tab then
        -- Older clients still get text navigation with an active underline,
        -- rather than another row of red action buttons.
        tab = CreateFrame("Button", name, bar)
        tab.navigationLabel = Text(tab, title, "GameFontNormalSmall", 0, 0, bar.minTabWidth)
        tab.navigationLabel:ClearAllPoints()
        tab.navigationLabel:SetPoint("CENTER", tab, "CENTER", 0, -2)
        tab.navigationLabel:SetJustifyH("CENTER")
        tab.selectionLine = tab:CreateTexture(nil, "ARTWORK")
        tab.selectionLine:SetColorTexture(1, 0.82, 0, 1)
        tab.selectionLine:SetPoint("BOTTOMLEFT", 4, 0)
        tab.selectionLine:SetSize(bar.minTabWidth - 8, 2)
    end
    tab:SetID(index)
    tab:SetSize(bar.minTabWidth, 32)
    tab:SetPoint("TOPLEFT", (index - 1) * (bar.minTabWidth + 8), 0)
    tab:SetText(title)
    if tab.nativeNavigation then PanelTemplates_TabResize(tab, bar.tabPadding, bar.minTabWidth) end
    tab:SetScript("OnClick", function(self)
        if self.selected then return end
        if PlaySound and SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB then PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB) end
        onClick()
    end)
    return tab
end
local function Input(parent, name, width, x, y)
    local input = CreateFrame("EditBox", name, parent)
    input:SetSize(width, 26)
    input:SetPoint("TOPLEFT", x, y)
    input:SetAutoFocus(false)
    input:SetMaxLetters(100)
    input:SetFont(STANDARD_TEXT_FONT, 13, "")
    input:SetTextColor(1, 1, 1)
    input:SetMultiLine(false)
    input:SetJustifyH("LEFT")
    input:SetJustifyV("MIDDLE")
    input:SetTextInsets(6, 6, 2, 2)
    Background(input, 0.4, 0.36, 0.27, 1)
    local fill = input:CreateTexture(nil, "BORDER")
    fill:SetPoint("TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMRIGHT", -1, 1)
    fill:SetColorTexture(0.025, 0.025, 0.025, 1)
    input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return input
end
local function Checkbox(parent, key, title, x, y, width, description)
    local button = CreateFrame("CheckButton", "Acquainted_" .. key .. "Check", parent, "UICheckButtonTemplate")
    button:SetPoint("TOPLEFT", x, y)
    Text(button, title, nil, 30, -7, width or 250)
    button:SetScript("OnClick", function(self)
        ns.SetOption(key, self:GetChecked() and true or false)
        ns.RefreshSettings()
    end)
    if description then Tooltip(button, title, description) end
    checks[key] = button
    return button
end
local function Slider(parent, key, title, y, lowText, highText)
    local range = ns.optionRanges[key]
    Text(parent, title, nil, 16, y, 260)
    local name = "Acquainted_" .. key .. "Slider"
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", 16, y - 24)
    slider:SetWidth(186)
    slider:SetMinMaxValues(range[1], range[2])
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    local label = slider.Text or _G[name .. "Text"]
    local bottomLow, bottomHigh = slider.Low or _G[name .. "Low"], slider.High or _G[name .. "High"]
    if label then label:SetText("") end
    if bottomLow then bottomLow:SetText(lowText or tostring(range[1])) end
    if bottomHigh then bottomHigh:SetText(highText or tostring(range[2])) end
    local input = Input(parent, "Acquainted_" .. key .. "Value", 60, 220, y - 15)
    input:SetMaxLetters(5)
    input:SetJustifyH("CENTER")
    -- Render the saved value as a regular FontString while idle. This avoids
    -- depending on the client's EditBox text layout to display numeric values.
    local display = input:CreateFontString(nil, "OVERLAY")
    display:SetFont(STANDARD_TEXT_FONT, 13, "")
    display:SetPoint("CENTER", input, "CENTER", 0, 0)
    display:SetTextColor(1, 1, 1)
    input.valueDisplay = display
    local function DisplayValue()
        display:SetText(tostring(ns.db.options[key]))
        display:SetShown(not input:HasFocus())
        input:SetTextColor(1, 1, 1, input:HasFocus() and 1 or 0)
    end
    input:SetScript("OnEditFocusGained", function()
        input:SetTextColor(1, 1, 1, 1)
        display:Hide()
    end)
    input:HookScript("OnShow", function(self)
        self:SetText(tostring(ns.db.options[key]))
        DisplayValue()
    end)
    local committing
    local function Commit(self)
        if refreshing or committing then return end
        committing = true
        local number = tonumber(self:GetText())
        if number and number ~= ns.db.options[key] then ns.SetOption(key, number) end
        self:ClearFocus()
        ns.RefreshSettings()
        committing = false
    end
    input:SetScript("OnEnterPressed", Commit)
    input:SetScript("OnEditFocusLost", Commit)
    input:HookScript("OnEditFocusLost", DisplayValue)
    input:SetScript("OnEscapePressed", function(self)
        self:SetText(tostring(ns.db.options[key]))
        self:ClearFocus()
    end)
    slider:SetScript("OnValueChanged", function(_, value)
        if not refreshing then ns.SetOption(key, math.floor(value + 0.5)) end
    end)
    Tooltip(slider, title, lowText and "Move the name lower or higher above the character. Type an exact value in the box." or "Drag to adjust the text size, or type an exact value in the box.")
    sliders[key], values[key] = slider, input
end

function ns.CloseColourPicker()
    if not pickerSession then return end
    pickerSession.active = false
    pickerSession = nil
    if ColorPickerFrame and ColorPickerFrame:IsShown() then ColorPickerFrame:Hide() end
end

local function PickColour(key)
    local picker = ColorPickerFrame
    if not picker or not picker.SetupColorPickerAndShow then
        ns.Error("The client colour picker is unavailable.")
        return
    end
    ns.CloseColourPicker()
    local before = ns.db.options[key]
    local session = { active = true }
    pickerSession = session
    -- A shared picker may be opened by another addon later. Retire our session
    -- after Hide's accept/cancel callbacks finish, without changing the widget.
    if not pickerHooked then
        -- Another addon can reuse the picker without hiding it first. Observe
        -- setup ownership only; this callback never calls a widget method.
        hooksecurefunc(picker, "SetupColorPickerAndShow", function(_, options)
            if pickerSession and pickerSession.options ~= options then
                pickerSession.active = false
                pickerSession = nil
            end
        end)
        picker:HookScript("OnHide", function()
            local closing = pickerSession
            if closing then
                C_Timer.After(0, function()
                    closing.active = false
                    if pickerSession == closing then pickerSession = nil end
                end)
            end
        end)
        pickerHooked = true
    end
    local r, g, b = ns.ColourRGB(before)
    local options = {
        r = r, g = g, b = b, hasOpacity = false,
        swatchFunc = function()
            if session.active then ns.SetOption(key, ns.ColourHex(picker:GetColorRGB())) end
        end,
        cancelFunc = function()
            if session.active then
                session.active = false
                if pickerSession == session then pickerSession = nil end
                ns.SetOption(key, before)
            end
        end,
    }
    session.options = options
    local ok, err = pcall(picker.SetupColorPickerAndShow, picker, options)
    if not ok then ns.CloseColourPicker(); ns.Error(err) end
end

local function ColourButton(parent, key, x, y, caption)
    local button = CreateFrame("Button", "Acquainted_" .. key .. "Button", parent)
    button:SetSize(28, 24)
    button:SetPoint("TOPLEFT", x, y)
    Background(button, 0.8, 0.8, 0.8, 1)
    local swatch = button:CreateTexture(nil, "ARTWORK")
    swatch:SetPoint("TOPLEFT", 2, -2)
    swatch:SetPoint("BOTTOMRIGHT", -2, 2)
    button:SetScript("OnClick", function() PickColour(key) end)
    if caption ~= false then Text(parent, "Colour", nil, x + 36, y - 5, 70) end
    Tooltip(button, "Name colour", "Choose a colour for the name and its guild line. Changes preview immediately; Cancel restores the previous colour.")
    colours[key] = swatch
    return button
end
local function RecognitionRow(parent, category, y)
    local descriptions = {
        guild = "Recognise members of your guild.",
        wowFriend = "Recognise WoW Friends (title friends), separately from Battle.net and character friends.",
        battleNetFriend = "Recognise Battle.net friends. Account information alone does not count as friendship.",
        characterFriend = "Recognise the traditional character friends list.",
        trpRelation = "Recognise any Total RP 3 relationship except None. Total RP 3 is optional.",
        community = "Recognise members of the WoW communities selected below, without permanently meeting them.",
        group = "Recognise your current party and raid. Native health bars stay under your existing nameplate settings.",
    }
    Checkbox(parent, category.option, category.label, 16, y, 290, descriptions[category.id])
    local dropdown = CreateFrame("DropdownButton", "Acquainted_" .. category.id .. "ColourMode", parent, "WowStyle1DropdownTemplate")
    dropdown:SetPoint("TOPLEFT", 346, y - 4)
    dropdown:SetSize(150, 26)
    dropdown:SetDefaultText("Met colour")
    dropdown:SetupMenu(function(_, root)
        for _, entry in ipairs({ { "met", "Met colour" }, { "custom", "Custom colour" } }) do
            local mode, title = entry[1], entry[2]
            root:CreateRadio(title, function() return ns.db.options[category.modeKey] == mode end,
                function() ns.SetOption(category.modeKey, mode) end)
        end
    end)
    Tooltip(dropdown, "Name colour", "Met colour follows Appearance. Custom colour overrides the name and guild line for this category. The first matching custom colour in this list wins.")
    local swatch = ColourButton(parent, category.colourKey, 512, y - 4, false)
    local preview = Text(parent, "Name", "GameFontNormal", 552, y - 9, 64)
    recognitionControls[#recognitionControls + 1] = { category = category, dropdown = dropdown, swatch = swatch, preview = preview }
end
local function RefreshRecognition()
    for _, control in ipairs(recognitionControls) do
        local category, options = control.category, ns.db.options
        control.dropdown:SetEnabled(options[category.option])
        control.dropdown:Update()
        control.swatch:SetShown(options[category.modeKey] == "custom")
        control.swatch:SetEnabled(options[category.option])
        local hex = options[category.modeKey] == "custom" and options[category.colourKey] or options.metColour
        control.preview:SetTextColor(ns.ColourRGB(hex))
    end
    if communityPicker then
        communityPicker:SetEnabled(ns.Social.available and ns.db.options.showCommunities)
        if communityMenuRevision ~= ns.Social.communityRevision then
            communityMenuRevision = ns.Social.communityRevision
            communityPicker:GenerateMenu()
        else communityPicker:Update() end
        local count = ns.Social.selectedCount or 0
        if not ns.Social.available then communityStatus:SetText("Community data is not available in this client yet.")
        elseif count == 0 then communityStatus:SetText("Choose the communities whose members you recognise.")
        elseif (ns.Social.loadingCount or 0) > 0 then communityStatus:SetText(count .. " selected · waiting for community rosters…")
        else communityStatus:SetText(count .. (count == 1 and " community selected." or " communities selected.")) end
    end
end
function ns.RefreshSocialSettings()
    if panel and panel:IsVisible() and selectedTab == "Recognition" then RefreshRecognition() end
end
local function AppearanceCard(parent, known, x)
    local card = CreateFrame("Frame", nil, parent)
    card:SetSize(296, 508)
    card:SetPoint("TOPLEFT", x, -96)
    Background(card, 0.08, 0.08, 0.08, 0.85)
    Text(card, known and "Met people" or "Unmet people", "GameFontNormalLarge", 14, -14, 270)
    local preview = CreateFrame("Frame", nil, card)
    preview:SetPoint("TOPLEFT", 12, -42)
    preview:SetSize(272, 120)
    preview:SetClipsChildren(true)
    Background(preview, 0.025, 0.035, 0.045, 0.95)
    local name = preview:CreateFontString(nil, "OVERLAY")
    local guild = preview:CreateFontString(nil, "OVERLAY")
    local hidden = Text(preview, "Hidden", "GameFontDisable", 20, -48, 232)
    hidden:SetJustifyH("CENTER")
    previews[known and "met" or "unmet"] = { frame = preview, name = name, guild = guild, hidden = hidden }
    Checkbox(card, known and "hideMet" or "hideUnmet", "Hide", 10, -166, 248,
        "Hide this category's Acquainted name or indicator and guild line. In overlay mode, existing names and health bars stay under your nameplate addon's control.")
    Checkbox(card, known and "showGuildName" or "showUnmetGuildName", "Show guild", 10, -198, 248,
        "Show the guild beneath a visible player name. Anonymous Unmet labels and icons have no guild line.")
    if not known then
        Text(card, "Display as", nil, 16, -234, 260)
        displayChoices = {}
        for index, choice in ipairs({ { "name", "Name" }, { "label", "Unmet" }, { "icon", "Icon" } }) do
            local value, title = choice[1], choice[2]
            local button = Button(card, title, 82, 16 + (index - 1) * 90, -254,
                function() ns.SetOption("unmetDisplay", value) end, "Acquainted_Unmet_" .. value)
            displayChoices[value] = { button = button, title = title }
        end
    end
    Slider(card, known and "fontSize" or "unmetFontSize", "Text size", -298)
    Slider(card, known and "nameOffset" or "unmetNameOffset", "Vertical position", -370, "Lower", "Higher")
    ColourButton(card, known and "metColour" or "unmetColour", 16, -442)
    Button(card, "Reset appearance", 132, 148, -442, function() ns.ResetAppearance(known and "met" or "unmet") end,
        known and "Acquainted_ResetMet" or "Acquainted_ResetUnmet")
    Text(card, "Live preview · position shown at ¼ scale", "GameFontDisableSmall", 16, -483, 264)
end
local function RefreshPreviews()
    for kind, preview in pairs(previews) do
        local known = kind == "met"
        local text = ns.PlayerLabel(known, ns.db.options, "Alex Rowan")
        local visible = text ~= nil
        local size, height, r, g, b = ns.Appearance(known, ns.db.options)
        preview.name:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE")
        preview.name:ClearAllPoints()
        preview.name:SetPoint("BOTTOM", preview.frame, "BOTTOM", 0, 62 + height / 4)
        preview.name:SetTextColor(r, g, b)
        preview.name:SetText(text or "Alex Rowan")
        preview.name:SetShown(visible)
        preview.guild:SetFont(STANDARD_TEXT_FONT, math.max(8, math.floor(size * 0.8)), "OUTLINE")
        preview.guild:ClearAllPoints()
        preview.guild:SetPoint("TOP", preview.name, "BOTTOM", 0, -2)
        preview.guild:SetTextColor(r, g, b)
        preview.guild:SetText("<Wayfarers>")
        local showGuild = ns.ShowGuild(known, ns.db.options)
        preview.guild:SetShown(visible and showGuild)
        preview.hidden:SetShown(not visible)
    end
end
local function OpenNickname(guid)
    local record = ns.db.known[guid]
    if not record then return end
    nicknameEditor.guid = guid
    nicknameEditor.title:SetText("Nickname for " .. ns.WithoutColourCodes(record.name))
    nicknameEditor.input:SetText(record.nickname or "")
    nicknameEditor:Show()
    nicknameEditor.input:SetFocus()
end
local function AgeLabel(stamp)
    local age = math.max(0, ns.Recent.Now() - stamp)
    if age < 60 then return "just now" end
    if age < 3600 then return math.floor(age / 60) .. " min ago" end
    if age < 86400 then return math.floor(age / 3600) .. " hr ago" end
    local days = math.floor(age / 86400)
    return days .. (days == 1 and " day ago" or " days ago")
end
local function RefreshRecent()
    local query = (search:GetText() or ""):lower()
    if not recentSnapshot or recentSnapshot.generation ~= ns.Recent.generation then
        recentSnapshot, recentNeedsRefresh = ns.Recent.List(""), false
        ns.Recent.ConsumeDirty()
    end
    local lists, y, rowIndex = { group = {}, nearby = {} }, 0, 0
    for _, kind in ipairs({ "group", "nearby" }) do
        for _, person in ipairs(recentSnapshot[kind]) do
            if not ns.db.known[person.guid] and (query == "" or person.name:lower():find(query, 1, true)
                or (person.rpName and person.rpName:lower():find(query, 1, true))) then
                lists[kind][#lists[kind] + 1] = person
            end
        end
    end
    local count = #lists.group + #lists.nearby
    panel.count:SetText(count .. (count == 1 and " recent player" or " recent players"))
    for index, kind in ipairs({ "group", "nearby" }) do
        local header = recentHeaders[index]
        if not header then
            header = Text(panel.listContent, "", "GameFontNormal", 4, 0, 540)
            recentHeaders[index] = header
        end
        if #lists[kind] > 0 then
            header:ClearAllPoints(); header:SetPoint("TOPLEFT", 4, -y)
            header:SetText((kind == "group" and "Group members" or "Nearby") .. " (" .. #lists[kind] .. "/50)")
            header:Show()
            y = y + 26
            for _, person in ipairs(lists[kind]) do
                rowIndex = rowIndex + 1
                local row = recentRows[rowIndex]
                if not row then
                    row = CreateFrame("Frame", nil, panel.listContent)
                    row:SetSize(592, 52)
                    Background(row, 0.08, 0.08, 0.08, 0.65)
                    row.label = Text(row, "", nil, 10, -8, 438)
                    row.detail = Text(row, "", "GameFontDisableSmall", 10, -29, 438)
                    row.label:SetWordWrap(false)
                    row.detail:SetWordWrap(false)
                    Button(row, "Meet", 110, 466, -13, function()
                        if row:IsVisible() then ns.Recent.Meet(row.guid, row.person, row.generation) end
                    end)
                    recentRows[rowIndex] = row
                end
                row.guid, row.person, row.generation = person.guid, person, recentSnapshot.generation
                row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -y)
                row.label:SetText(person.rpName or person.name)
                local source = person.source == "party" and "Party" or (person.source == "raid" and "Raid" or "Nearby")
                local gameName = person.rpName and person.rpName ~= person.name and (person.name .. " · ") or ""
                row.detail:SetText(gameName .. source .. " · " .. AgeLabel(person.lastSeen))
                row:Show()
                y = y + 58
            end
            y = y + 12
        else header:Hide() end
    end
    panel.empty:SetText(query ~= "" and "No recent players match your search." or "No recent players yet. Group with someone or encounter their nameplate, then find them here.")
    panel.empty:SetShown(count == 0)
    panel.listContent:SetHeight(math.max(60, y))
    pages.Acquaintances.content:SetHeight(PEOPLE_LIST_TOP + math.max(60, y) + 16)
end
local function RecentSubtitle()
    return recentNeedsRefresh and "History updated. Refresh list when you're ready to see the latest encounters."
        or "50 group members + 50 nearby players. This list stays still until you refresh."
end
function ns.RefreshRecentPlayers(changed)
    if changed and not recentNeedsRefresh then
        recentNeedsRefresh = true
        if panel and panel:IsVisible() and selectedTab == "Acquaintances" and peopleView == "recent" then
            peopleSubtitle:SetText(RecentSubtitle())
        end
    end
end
local function RefreshPeople()
    local isRecent = peopleView == "recent"
    peopleTitle:SetText(isRecent and "Recent players" or "Your acquaintances")
    panel.searchCaption:SetText(isRecent and "Search game or roleplay names" or "Search names or nicknames")
    peopleSubtitle:SetText(isRecent and RecentSubtitle() or "Saved separately for this character.")
    panel.exportButton:SetShown(not isRecent)
    panel.importButton:SetShown(not isRecent)
    panel.clearHistory:SetShown(isRecent)
    panel.refreshRecent:SetShown(isRecent)
    for value, tab in pairs(peopleChoices) do SetTabSelected(tab, value == peopleView) end
    for _, row in ipairs(rows) do row:Hide() end
    for _, row in ipairs(recentRows) do row:Hide() end
    for _, header in ipairs(recentHeaders) do header:Hide() end
    if isRecent then RefreshRecent(); peopleSubtitle:SetText(RecentSubtitle()); return end
    local query = (search:GetText() or ""):lower()
    local people, total = {}, 0
    for guid, record in pairs(ns.db.known) do
        total = total + 1
        local name = ns.WithoutColourCodes(record.name)
        local nickname = record.nickname and ns.WithoutColourCodes(record.nickname) or ""
        if query == "" or name:lower():find(query, 1, true) or nickname:lower():find(query, 1, true) then
            people[#people + 1] = { guid = guid, name = name, nickname = nickname }
        end
    end
    table.sort(people, function(a, b) return a.name:lower() < b.name:lower() end)
    panel.count:SetText(query == "" and (total .. (total == 1 and " acquaintance" or " acquaintances")) or (#people .. " of " .. total .. " acquaintances"))
    for _, row in ipairs(rows) do row:Hide() end
    for index, person in ipairs(people) do
        local row = rows[index]
        if not row then
            row = CreateFrame("Frame", nil, panel.listContent)
            row:SetSize(554, 46)
            row:SetPoint("TOPLEFT", 0, -(index - 1) * 46)
            row.label = Text(row, "", nil, 4, -4, 344)
            row.nickname = Text(row, "", "GameFontDisableSmall", 4, -24, 344)
            Button(row, "Edit nickname", 104, 354, -8, function() OpenNickname(row.guid) end)
            Button(row, "Forget", 78, 466, -8, function() ns.Forget(row.guid) end)
            rows[index] = row
        end
        row.guid = person.guid
        row.label:SetText(person.name)
        row.nickname:SetText(person.nickname ~= "" and person.nickname or "No nickname")
        row:Show()
    end
    panel.empty:SetText(total == 0 and "No acquaintances yet. Target a player and choose Meet." or "No matching acquaintances.")
    panel.empty:SetShown(#people == 0)
    local listHeight = math.max(46, #people * 46)
    panel.listContent:SetHeight(listHeight)
    pages.Acquaintances.content:SetHeight(PEOPLE_LIST_TOP + listHeight + 16)
    if nicknameEditor.guid and not ns.db.known[nicknameEditor.guid] then
        nicknameEditor.guid = nil
        nicknameEditor:Hide()
    end

end
function ns.RefreshSettings()
    if not panel or refreshing then return end
    refreshing = true
    for key, button in pairs(checks) do button:SetChecked(ns.db.options[key]) end
    for key, slider in pairs(sliders) do
        slider:SetValue(ns.db.options[key])
        if not values[key]:HasFocus() then values[key]:SetText(tostring(ns.db.options[key])) end
        values[key].valueDisplay:SetText(tostring(ns.db.options[key]))
        values[key].valueDisplay:SetShown(not values[key]:HasFocus())
        values[key]:SetTextColor(1, 1, 1, values[key]:HasFocus() and 1 or 0)
    end
    for key, swatch in pairs(colours) do swatch:SetColorTexture(ns.ColourRGB(ns.db.options[key])) end
    if displayChoices then
        for value, choice in pairs(displayChoices) do
            choice.button:SetText(ns.db.options.unmetDisplay == value and ("|cffffd100" .. choice.title .. "|r") or choice.title)
        end
    end
    if overlayCaption then overlayCaption:SetText(type(Plater) == "table" and "Plater detected · labels are added alongside its names automatically." or "For other nameplate addons. Existing names stay visible, so names may appear twice.") end
    RefreshPreviews()
    RefreshRecognition()
    if selectedTab == "Acquaintances" then RefreshPeople() end
    ns.lastShownStatus = ns.DisplayStatus()
    panel.status:SetText(ns.lastShownStatus)
    refreshing = false
end
function ns.FinishSettingsInput()
    recentSnapshot = nil
    for _, input in pairs(values) do input:ClearFocus() end
    if search then search:ClearFocus() end
    if transferDialog then transferDialog:Hide() end
    if recentClearDialog then recentClearDialog:Hide() end
    if nicknameEditor then nicknameEditor.input:ClearFocus(); nicknameEditor:Hide() end
end
local function SelectTab(name)
    ns.CloseColourPicker()
    ns.FinishSettingsInput()
    selectedTab = name
    for key, page in pairs(pages) do page:SetShown(key == name) end
    for key, tab in pairs(tabs) do SetTabSelected(tab, key == name) end
    ns.RefreshSettings()
end
local function Page(name, height)
    local scroll = CreateFrame("ScrollFrame", "Acquainted_" .. name .. "Page", panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -128)
    scroll:SetPoint("BOTTOMRIGHT", -30, 38)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(640, height)
    scroll:SetScrollChild(content)
    scroll.content = content
    scroll.scrollBarHideable = true
    local function UpdateScrolling()
        local height = scroll:GetHeight()
        local range = math.max(0, content:GetHeight() - height)
        local bar = scroll.ScrollBar or _G["Acquainted_" .. name .. "PageScrollBar"]
        if bar then bar:SetShown(height > 0 and range > 0) end
        if height > 0 then
            scroll:SetVerticalScroll(math.min(scroll:GetVerticalScroll(), range))
        end
    end
    scroll:HookScript("OnScrollRangeChanged", UpdateScrolling)
    scroll:HookScript("OnSizeChanged", UpdateScrolling)
    scroll:HookScript("OnShow", UpdateScrolling)
    content:SetScript("OnSizeChanged", UpdateScrolling)
    UpdateScrolling()
    pages[name] = scroll
    return content
end
function ns.OpenSettings()
    if category and Settings.OpenToCategory then Settings.OpenToCategory(category:GetID())
    else ns.Say("The settings panel could not load. /acq status shows the error; /acq off restores game settings.") end
end
function ns.CreateSettings()
    panel = CreateFrame("Frame")
    panel.name = "Acquainted"
    Text(panel, "Acquainted", "GameFontNormalLarge", 16, -16)
    Text(panel, "Make familiar faces stand out.", nil, 16, -48, 600)
    Checkbox(panel, "enabled", "Enable Acquainted", 426, -12, 180,
        "Switch off to restore your original name and nameplate settings. Your acquaintances and preferences are kept.")
    local mainTabs = TabBar(panel, 16, -80, 604, 144)
    for index, name in ipairs({ "Appearance", "Recognition", "Acquaintances", "Help" }) do
        local tabName = name
        tabs[name] = NavigationTab(mainTabs, name, index, function() SelectTab(tabName) end, "Acquainted_" .. name .. "Tab")
    end
    panel.status = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    panel.status:SetPoint("BOTTOMLEFT", 16, 16)
    local appearance = Page("Appearance", 778)
    Text(appearance, "Uses Blizzard's friendly nameplates", "GameFontNormal", 16, -8, 600)
    Text(appearance, "Acquainted uses friendly nameplates to position custom names. Outside instances, it temporarily enables the settings it needs without changing your saved preferences.", nil, 16, -32, 600)
    AppearanceCard(appearance, true, 16)
    AppearanceCard(appearance, false, 328)
    Checkbox(appearance, "showPetNames", "Show pet and minion names for people you know", 16, -618, 570,
        "Includes your own companions. Pets of unmet people stay hidden, even when unmet player names are visible.")
    Checkbox(appearance, "overlayOnly", "Add labels alongside existing names", 16, -656, 570,
        "Use with another nameplate addon. Keep its names and health bars, and add Acquainted labels alongside them. This can show duplicate names. Automatic with Plater. Change outside combat.")
    overlayCaption = Text(appearance, "", "GameFontDisableSmall", 48, -694, 560)
    Button(appearance, "Reset all appearance", 180, 22, -730, function() ns.ResetAppearance("all") end, "Acquainted_ResetAll")
    Text(appearance, "Keeps acquaintances and recognition rules.", "GameFontDisableSmall", 216, -737, 400)
    local recognition = Page("Recognition", 702)
    Text(recognition, "Who should count as someone you know?", "GameFontNormalLarge", 16, -12, 600)
    Text(recognition, "Use the shared Met colour or choose a custom colour. If several categories match, the first custom colour below wins.", nil, 16, -44, 590)
    Text(recognition, "Recognise automatically", "GameFontNormal", 22, -88, 300)
    Text(recognition, "Name colour", "GameFontNormal", 350, -88, 150)
    Text(recognition, "Preview", "GameFontDisableSmall", 552, -88, 64)
    for index, category in ipairs(ns.recognitionCategories) do RecognitionRow(recognition, category, -112 - (index - 1) * 40) end
    communityPicker = CreateFrame("DropdownButton", "Acquainted_CommunityPicker", recognition, "WowStyle1DropdownTemplate")
    communityPicker:SetPoint("TOPLEFT", 22, -400)
    communityPicker:SetSize(240, 26)
    communityPicker:SetDefaultText("Choose communities")
    communityPicker:SetupMenu(function(_, root)
        if #ns.Social.clubs == 0 then root:CreateTitle("No WoW communities available.") end
        for _, club in ipairs(ns.Social.clubs) do
            local key = club.key
            root:CreateCheckbox(club.name, function() return ns.db.communities[key] == true end,
                function() ns.SetCommunitySelected(key, not ns.db.communities[key]) end)
        end
    end)
    Tooltip(communityPicker, "Recognised communities", "Choose WoW character communities to count as met. Membership is matched by character ID. Guilds use the Guild members setting above.")
    communityStatus = Text(recognition, "", "GameFontDisableSmall", 22, -436, 590)
    Text(recognition, "Manually meeting someone keeps their category colour. Nicknames still take priority. Health-bar colours stay unchanged.", "GameFontDisableSmall", 22, -466, 590)
    Text(recognition, "Which name should appear?", "GameFontNormal", 16, -516, 600)
    Checkbox(recognition, "useRPNames", "Use Total RP 3 roleplay names", 16, -542, 550,
        "Use roleplay names when available, otherwise the game name. A personal nickname takes priority.")
    Text(recognition, "When to show names", "GameFontNormal", 16, -594, 600)
    Checkbox(recognition, "onlyWhileIC", "Only active while IC in Total RP 3", 16, -618, 550,
        "Pause Acquainted while you are OOC and resume when you switch IC. Restores normal names and nameplate settings while paused; combat may delay settings cleanup. Your acquaintances are kept. Has no effect without Total RP 3.")
    local advanced = CreateFrame("Frame", nil, recognition)
    advanced:SetPoint("TOPLEFT", 0, -704); advanced:SetSize(640, 120); advanced:Hide()
    Checkbox(advanced, "affectEnemies", "Also filter enemy players", 16, -4, 550,
        "Apply Acquainted to enemy players and their companions too. Health bars are preserved. Change this outside combat.")
    Text(advanced, "Health bars are preserved. Change this outside combat.", "GameFontDisableSmall", 48, -44, 550)
    local advancedButton
    advancedButton = Button(recognition, "+ Advanced", 144, 16, -666, function()
        local shown = not advanced:IsShown()
        advanced:SetShown(shown)
        recognition:SetHeight(shown and 788 or 702)
        advancedButton:SetText(shown and "− Advanced" or "+ Advanced")
    end, "Acquainted_AdvancedButton")
    local people = Page("Acquaintances", 204)
    peopleTitle = Text(people, "Your acquaintances", "GameFontNormalLarge", 16, -12, 290)
    peopleSubtitle = Text(people, "Saved separately for this character.", "GameFontDisableSmall", 16, -40, 600)
    local peopleTabs = TabBar(people, 16, -64, 592, 112)
    for index, value in ipairs({ "saved", "recent" }) do
        local view = value
        peopleChoices[view] = NavigationTab(peopleTabs, view == "saved" and "Saved" or "Recent", index, function()
            ns.FinishSettingsInput()
            peopleView = view
            panel.peopleScroll:SetVerticalScroll(0)
            search:SetText("")
            ns.RefreshSettings()
        end, view == "saved" and "Acquainted_SavedPlayers" or "Acquainted_RecentPlayers")
        Tooltip(peopleChoices[view], view == "saved" and "Saved acquaintances" or "Recent players",
            view == "saved" and "People you have met and saved, with their nicknames."
                or "Meet someone after they leave. Keeps your latest 50 group members and 50 nearby players separately.")
    end
    panel.searchCaption = Text(people, "Search names or nicknames", nil, 16, -108, 300)
    search = Input(people, "Acquainted_Search", 302, 22, -130)
    search:SetScript("OnTextChanged", function()
        if not refreshing then
            panel.peopleScroll:SetVerticalScroll(0)
            ns.RefreshSettings()
        end
    end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    panel.count = Text(people, "", "GameFontDisableSmall", 346, -137, 260)
    panel.peopleScroll = pages.Acquaintances
    panel.listContent = CreateFrame("Frame", "Acquainted_AcquaintanceList", people)
    panel.listContent:SetPoint("TOPLEFT", 16, -PEOPLE_LIST_TOP)
    panel.listContent:SetSize(554, 46)
    panel.empty = Text(panel.listContent, "", nil, 4, -10, 540)
    transferDialog = CreateFrame("Frame", "Acquainted_TransferDialog", panel)
    transferDialog:SetPoint("CENTER", panel, "CENTER", 0, 0)
    transferDialog:SetSize(592, 402)
    transferDialog:SetFrameLevel(panel:GetFrameLevel() + 25)
    transferDialog:EnableMouse(true)
    Background(transferDialog, 0.06, 0.06, 0.06, 1)
    transferDialog.title = Text(transferDialog, "", "GameFontNormalLarge", 16, -16, 560)
    transferDialog.help = Text(transferDialog, "", nil, 16, -46, 560)
    local transferScroll = CreateFrame("ScrollFrame", nil, transferDialog, "UIPanelScrollFrameTemplate")
    transferScroll:SetPoint("TOPLEFT", 16, -90); transferScroll:SetSize(534, 150)
    local transferInput = Input(transferScroll, "Acquainted_TransferInput", 530, 0, 0)
    transferInput:SetMultiLine(true)
    transferInput:SetHeight(150)
    transferInput:SetMaxLetters(ns.transferLimit + 1)
    transferInput:SetJustifyV("TOP")
    transferScroll:SetScrollChild(transferInput)
    transferDialog.summary = Text(transferDialog, "", "GameFontHighlightSmall", 16, -252, 560)
    local replace = CreateFrame("CheckButton", "Acquainted_TransferReplace", transferDialog, "UICheckButtonTemplate")
    replace:SetPoint("TOPLEFT", 10, -286)
    Text(replace, "Replace entire list (removes people absent from import)", nil, 30, -7, 530)
    local overwrite = CreateFrame("CheckButton", "Acquainted_TransferOverwrite", transferDialog, "UICheckButtonTemplate")
    overwrite:SetPoint("TOPLEFT", 10, -318)
    Text(overwrite, "Use imported names and nicknames for existing people", nil, 30, -7, 530)
    local commit
    local function Invalidate()
        transferDialog.preview = nil
        if commit then commit:SetEnabled(false) end
        if transferDialog.importing then transferDialog.summary:SetText("Preview the pasted list before importing.") end
    end
    transferInput:SetScript("OnTextChanged", function(self)
        self:SetHeight(math.max(150, self:GetStringHeight() + 16))
        Invalidate()
    end)
    replace:SetScript("OnClick", Invalidate)
    overwrite:SetScript("OnClick", Invalidate)
    local preview = Button(transferDialog, "Preview import", 132, 16, -364, function()
        local result, err = ns.PreviewImport(transferInput:GetText())
        transferDialog.preview = result and transferInput:GetText() or nil
        transferDialog.previewRevision = ns.peopleRevision or 0
        commit:SetEnabled(result ~= nil)
        if not result then transferDialog.summary:SetText(err); return end
        local message = result.count .. " people: " .. result.added .. " new, " .. result.existing .. " existing; " .. result.conflicts .. " nickname conflicts."
        transferDialog.summary:SetText(message .. (replace:GetChecked() and (" Replacement removes " .. result.removed .. " local entries.") or " Existing entries are kept unless overwrite is selected."))
        commit:SetText(replace:GetChecked() and "Replace list" or "Merge list")
    end, "Acquainted_TransferPreview")
    commit = Button(transferDialog, "Merge list", 132, 158, -364, function()
        if not transferDialog.importing or transferDialog.preview ~= transferInput:GetText() then return end
        if transferDialog.previewRevision ~= (ns.peopleRevision or 0) then
            Invalidate()
            transferDialog.summary:SetText("Your local list changed. Preview the import again.")
            return
        end
        local ok, count = ns.ImportPeople(transferDialog.preview, replace:GetChecked(), overwrite:GetChecked())
        if not ok then transferDialog.summary:SetText(count); return end
        transferDialog:Hide()
        ns.Say("Imported " .. count .. " acquaintances.")
    end, "Acquainted_TransferCommit")
    Button(transferDialog, "Close", 110, 462, -364, function() transferDialog:Hide() end, "Acquainted_TransferClose")
    transferDialog:SetScript("OnHide", function() transferInput:ClearFocus(); Invalidate() end)
    local function OpenTransfer(importing)
        ns.FinishSettingsInput()
        transferDialog.importing = importing
        replace:SetChecked(false); overwrite:SetChecked(false)
        replace:SetShown(importing); overwrite:SetShown(importing)
        preview:SetShown(importing); commit:SetShown(importing); commit:SetEnabled(false)
        transferDialog.title:SetText(importing and "Import acquaintances" or "Export acquaintances")
        transferDialog.help:SetText(importing and "Paste an export from another machine, then preview it. Merge keeps local entries by default." or "Select and copy all text below to transfer your manual Met list and nicknames to another machine.")
        local text, err = "", nil
        if not importing then text, err = ns.ExportPeople() end
        transferInput:SetText(text or "")
        transferDialog.summary:SetText(importing and "Preview the pasted list before importing." or (err or "Only acquaintances and nicknames are included. Settings stay on this machine."))
        transferScroll:SetVerticalScroll(0)
        transferDialog:Show()
        transferInput:SetFocus()
        if not importing then transferInput:HighlightText() end
    end
    local exportButton = Button(people, "Export list", 132, 330, -8, function() OpenTransfer(false) end, "Acquainted_Export")
    local importButton = Button(people, "Import list", 132, 476, -8, function() OpenTransfer(true) end, "Acquainted_Import")
    panel.exportButton, panel.importButton = exportButton, importButton
    panel.refreshRecent = Button(people, "Refresh list", 132, 330, -8, function()
        recentSnapshot = nil
        panel.peopleScroll:SetVerticalScroll(0)
        ns.RefreshSettings()
    end, "Acquainted_RefreshRecent")
    Tooltip(panel.refreshRecent, "Refresh list", "Show the latest encounters. The list stays still while you browse, even when players arrive or leave.")
    panel.clearHistory = Button(people, "Clear history", 132, 476, -8, function() recentClearDialog:Show() end, "Acquainted_ClearHistory")
    recentClearDialog = CreateFrame("Frame", "Acquainted_ClearHistoryDialog", panel)
    recentClearDialog:SetPoint("CENTER", panel, "CENTER", 0, 0)
    recentClearDialog:SetSize(520, 146)
    recentClearDialog:SetFrameLevel(panel:GetFrameLevel() + 25)
    recentClearDialog:EnableMouse(true)
    Background(recentClearDialog, 0.06, 0.06, 0.06, 1)
    Text(recentClearDialog, "Clear recent players?", "GameFontNormalLarge", 16, -16, 480)
    Text(recentClearDialog, "Clears both recent lists. Your saved acquaintances and nicknames are kept.", nil, 16, -48, 480)
    Button(recentClearDialog, "Clear history", 132, 16, -106, function()
        ns.Recent.Clear()
        recentClearDialog:Hide()
        ns.RefreshSettings()
    end, "Acquainted_ConfirmClearHistory")
    Button(recentClearDialog, "Cancel", 108, 396, -106, function() recentClearDialog:Hide() end, "Acquainted_CancelClearHistory")
    recentClearDialog:Hide()
    Tooltip(panel.clearHistory, "Clear history", "Clear recent group and nearby players. Saved acquaintances are kept.")
    Tooltip(exportButton, "Export list", "Copy your manual acquaintances and nicknames to another machine.")
    Tooltip(importButton, "Import list", "Paste an exported list and preview it before merging or replacing acquaintances.")
    transferInput:SetScript("OnEscapePressed", function() transferDialog:Hide() end)
    transferDialog:Hide()
    -- Parent to the fixed settings canvas, outside the scrolling page.
    -- The editor must remain visible regardless of the list's scroll position.
    nicknameEditor = CreateFrame("Frame", "Acquainted_NicknameEditor", panel)
    nicknameEditor:SetPoint("CENTER", panel, "CENTER", 0, 0)
    nicknameEditor:SetSize(592, 132)
    nicknameEditor:SetFrameLevel(panel:GetFrameLevel() + 20)
    nicknameEditor:EnableMouse(true)
    Background(nicknameEditor, 0.06, 0.06, 0.06, 1)
    nicknameEditor.title = Text(nicknameEditor, "", "GameFontNormal", 16, -16, 560)
    nicknameEditor.input = Input(nicknameEditor, "Acquainted_NicknameInput", 292, 22, -48)
    local function SaveNickname()
        if nicknameEditor.guid then ns.SetNickname(nicknameEditor.guid, nicknameEditor.input:GetText()) end
        nicknameEditor.input:ClearFocus(); nicknameEditor:Hide()
    end
    nicknameEditor.input:SetScript("OnEnterPressed", SaveNickname)
    nicknameEditor.input:SetScript("OnEscapePressed", function(self) self:ClearFocus(); nicknameEditor:Hide() end)
    Button(nicknameEditor, "Save", 108, 326, -50, SaveNickname, "Acquainted_SaveNickname")
    Button(nicknameEditor, "Cancel", 108, 446, -50, function() nicknameEditor.input:ClearFocus(); nicknameEditor:Hide() end)
    Text(nicknameEditor, "Leave blank to use their roleplay or game name.", "GameFontDisableSmall", 16, -96, 560)
    nicknameEditor:SetScript("OnHide", function() nicknameEditor.input:ClearFocus() end)
    nicknameEditor:Hide()
    local help = Page("Help", 1)
    local helpBlocks = {}
    local function HelpBlock(text, font, gap)
        helpBlocks[#helpBlocks + 1] = { text = Text(help, text, font, 16, 0, 590), gap = gap }
    end
    HelpBlock("Getting started", "GameFontNormalLarge", 0)
    HelpBlock("Target a player and use /acq meet, or choose Meet in their right-click menu. Other players do not need an addon.", nil, 10)
    HelpBlock("Useful commands", "GameFontNormal", 20)
    HelpBlock("/acq — open settings\n/acq togglemet — Meet / Forget your target\n/acq meet [nickname] — meet your target, optionally with a nickname\n/acq forget — forget your target\n/acq off — turn off and restore the original game settings", nil, 10)
    HelpBlock("What affects name display?", "GameFontNormal", 20)
    HelpBlock("Friendly nameplates / Always show nameplates: needed for custom names.\nShow only name: controls friendly health bars, including unmet players. You can change it while Acquainted is active.\nOther nameplate addons: Plater is automatic. For others, try Add labels alongside existing names.\nInstances: Blizzard may restrict custom displays.", nil, 10)
    HelpBlock("A few things to know", "GameFontNormal", 20)
    HelpBlock("Grouping keeps met/unmet names active. Party and raid members count as met by default; health bars follow your settings.\n\nForgetting removes a saved acquaintance. Recognition rules can still count them as met. Use Acquaintances to export or import your list.\n\nIf a required visibility setting changes, filtering stops. Use /acq status for details or /acq setup to retry. Combat may delay cleanup.", nil, 10)
    local function LayoutHelp()
        local y = 12
        for _, block in ipairs(helpBlocks) do
            y = y + block.gap
            block.text:ClearAllPoints()
            block.text:SetPoint("TOPLEFT", 16, -y)
            y = y + math.max(14, block.text:GetStringHeight())
        end
        help:SetHeight(y + 16)
    end
    pages.Help:HookScript("OnShow", LayoutHelp)
    LayoutHelp()
    category = Settings.RegisterCanvasLayoutCategory(panel, "Acquainted")
    Settings.RegisterAddOnCategory(category)
    panel:SetScript("OnShow", ns.RefreshSettings)
    panel:SetScript("OnHide", function()
        ns.CloseColourPicker()
        ns.FinishSettingsInput()
    end)
    SelectTab("Appearance")
end
