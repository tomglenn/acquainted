local _, ns = ...
local panel, category, refreshing, selectedTab, search, nicknameEditor
local checks, sliders, values, rows, colours, previews, pages, tabs = {}, {}, {}, {}, {}, {}, {}, {}
local transferDialog, displayChoices, overlayCaption
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

local function ColourButton(parent, key, x, y)
    local button = CreateFrame("Button", "Acquainted_" .. key .. "Button", parent)
    button:SetSize(28, 24)
    button:SetPoint("TOPLEFT", x, y)
    Background(button, 0.8, 0.8, 0.8, 1)
    local swatch = button:CreateTexture(nil, "ARTWORK")
    swatch:SetPoint("TOPLEFT", 2, -2)
    swatch:SetPoint("BOTTOMRIGHT", -2, 2)
    button:SetScript("OnClick", function() PickColour(key) end)
    Text(parent, "Colour", nil, x + 36, y - 5, 70)
    Tooltip(button, "Name colour", "Choose a colour for the name and its guild line. Changes preview immediately; Cancel restores the previous colour.")
    colours[key] = swatch
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
local function RefreshPeople()
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
    pages.Acquaintances.content:SetHeight(142 + listHeight + 16)
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
    if selectedTab == "Acquaintances" then RefreshPeople() end
    ns.lastShownStatus = ns.DisplayStatus()
    panel.status:SetText(ns.lastShownStatus)
    refreshing = false
end
function ns.FinishSettingsInput()
    for _, input in pairs(values) do input:ClearFocus() end
    if search then search:ClearFocus() end
    if transferDialog then transferDialog:Hide() end
    if nicknameEditor then nicknameEditor.input:ClearFocus(); nicknameEditor:Hide() end
end
local function SelectTab(name)
    ns.CloseColourPicker()
    ns.FinishSettingsInput()
    selectedTab = name
    for key, page in pairs(pages) do page:SetShown(key == name) end
    for key, tab in pairs(tabs) do tab:SetText(key == name and ("|cffffd100" .. key .. "|r") or key) end
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
    for index, name in ipairs({ "Appearance", "Recognition", "Acquaintances" }) do
        local tabName = name
        tabs[name] = Button(panel, name, 154, 16 + (index - 1) * 164, -88, function() SelectTab(tabName) end, "Acquainted_" .. name .. "Tab")
    end
    tabs.Help = Button(panel, "Help", 94, 526, -88, function() SelectTab("Help") end, "Acquainted_HelpTab")
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
    local recognition = Page("Recognition", 466)
    Text(recognition, "Who should count as someone you know?", "GameFontNormalLarge", 16, -12, 600)
    Text(recognition, "These people count as met automatically. Native health bars stay visible if enabled.", nil, 16, -44, 590)
    Checkbox(recognition, "showFriends", "Friends", 16, -82, 550, "Includes character friends and Battle.net friends.")
    Checkbox(recognition, "showGuild", "Guild members", 16, -122, 550)
    Checkbox(recognition, "showGroup", "Party and raid members", 16, -162, 550,
        "Use met styling for current party and raid members without saving them. Grouping keeps outsider styling active and preserves native player health bars.")
    Checkbox(recognition, "useTRPRelations", "Total RP 3 relationships", 16, -202, 550,
        "Recognise any TRP3 relationship except None. Total RP 3 is optional; other players do not need Acquainted.")
    Text(recognition, "Which name should appear?", "GameFontNormal", 16, -270, 600)
    Checkbox(recognition, "useRPNames", "Use Total RP 3 roleplay names", 16, -296, 550,
        "Use roleplay names when available, otherwise the game name. A personal nickname takes priority.")
    Text(recognition, "When to show names", "GameFontNormal", 16, -354, 600)
    Checkbox(recognition, "onlyWhileIC", "Only active while IC in Total RP 3", 16, -378, 550,
        "Pause Acquainted while you are OOC and resume when you switch IC. Restores normal names and nameplate settings while paused; combat may delay settings cleanup. Your acquaintances are kept. Has no effect without Total RP 3.")
    local advanced = CreateFrame("Frame", nil, recognition)
    advanced:SetPoint("TOPLEFT", 0, -468); advanced:SetSize(640, 120); advanced:Hide()
    Checkbox(advanced, "affectEnemies", "Also filter enemy players", 16, -4, 550,
        "Apply Acquainted to enemy players and their companions too. Health bars are preserved. Change this outside combat.")
    Text(advanced, "Health bars are preserved. Change this outside combat.", "GameFontDisableSmall", 48, -44, 550)
    local advancedButton
    advancedButton = Button(recognition, "+ Advanced", 144, 16, -430, function()
        local shown = not advanced:IsShown()
        advanced:SetShown(shown)
        recognition:SetHeight(shown and 552 or 466)
        advancedButton:SetText(shown and "− Advanced" or "+ Advanced")
    end, "Acquainted_AdvancedButton")
    local people = Page("Acquaintances", 204)
    Text(people, "Your acquaintances", "GameFontNormalLarge", 16, -12, 290)
    Text(people, "Saved separately for this character.", "GameFontDisableSmall", 16, -40, 600)
    Text(people, "Search names or nicknames", nil, 16, -78, 300)
    search = Input(people, "Acquainted_Search", 302, 22, -102)
    search:SetScript("OnTextChanged", function()
        if not refreshing then
            panel.peopleScroll:SetVerticalScroll(0)
            ns.RefreshSettings()
        end
    end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    panel.count = Text(people, "", "GameFontDisableSmall", 346, -109, 260)
    panel.peopleScroll = pages.Acquaintances
    panel.listContent = CreateFrame("Frame", "Acquainted_AcquaintanceList", people)
    panel.listContent:SetPoint("TOPLEFT", 16, -142)
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
