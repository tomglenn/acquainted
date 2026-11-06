local _, ns = ...
local panel, category, refreshing, selectedTab, search, nicknameEditor
local checks, sliders, values, rows, colours, previews, pages, tabs = {}, {}, {}, {}, {}, {}, {}, {}
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
    local input = CreateFrame("EditBox", name, parent, "InputBoxTemplate")
    input:SetSize(width, 26)
    input:SetPoint("TOPLEFT", x, y)
    input:SetAutoFocus(false)
    input:SetMaxLetters(100)
    input:SetFont(STANDARD_TEXT_FONT, 13, "")
    input:SetTextColor(1, 1, 1)
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
    card:SetSize(296, 454)
    card:SetPoint("TOPLEFT", x, -8)
    Background(card, 0.08, 0.08, 0.08, 0.85)
    Text(card, known and "Met people" or "Unmet people", "GameFontNormalLarge", 14, -14, 270)
    local preview = CreateFrame("Frame", nil, card)
    preview:SetPoint("TOPLEFT", 12, -42)
    preview:SetSize(272, 120)
    preview:SetClipsChildren(true)
    Background(preview, 0.025, 0.035, 0.045, 0.95)
    local name = preview:CreateFontString(nil, "OVERLAY")
    local guild = preview:CreateFontString(nil, "OVERLAY")
    local hidden = Text(preview, "Names hidden", "GameFontDisable", 20, -48, 232)
    hidden:SetJustifyH("CENTER")
    previews[known and "met" or "unmet"] = { frame = preview, name = name, guild = guild, hidden = hidden }
    if known then
        Checkbox(card, "showGuildName", "Show guild", 10, -198, 248)
    else
        Checkbox(card, "showUnmetNames", "Show name", 10, -166, 248)
        Checkbox(card, "showUnmetGuildName", "Show guild", 10, -198, 248,
            "Show the guild beneath visible unmet names. This does not meet the player or reveal their pets.")
    end
    Slider(card, known and "fontSize" or "unmetFontSize", "Text size", -244)
    Slider(card, known and "nameOffset" or "unmetNameOffset", "Vertical position", -316, "Lower", "Higher")
    ColourButton(card, known and "metColour" or "unmetColour", 16, -388)
    Button(card, "Reset appearance", 132, 148, -388, function() ns.ResetAppearance(known and "met" or "unmet") end,
        known and "Acquainted_ResetMet" or "Acquainted_ResetUnmet")
    Text(card, "Live preview · position shown at ¼ scale", "GameFontDisableSmall", 16, -429, 264)
end
local function RefreshPreviews()
    for kind, preview in pairs(previews) do
        local known = kind == "met"
        local visible = known or ns.db.options.showUnmetNames
        local size, height, r, g, b = ns.Appearance(known, ns.db.options)
        preview.name:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE")
        preview.name:ClearAllPoints()
        preview.name:SetPoint("BOTTOM", preview.frame, "BOTTOM", 0, 62 + height / 4)
        preview.name:SetTextColor(r, g, b)
        preview.name:SetText("Alex Rowan")
        preview.name:SetShown(visible)
        preview.guild:SetFont(STANDARD_TEXT_FONT, math.max(8, math.floor(size * 0.8)), "OUTLINE")
        preview.guild:ClearAllPoints()
        preview.guild:SetPoint("TOP", preview.name, "BOTTOM", 0, -2)
        preview.guild:SetTextColor(r, g, b)
        preview.guild:SetText("<Wayfarers>")
        local showGuild = (known and ns.db.options.showGuildName) or (not known and ns.db.options.showUnmetGuildName)
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
    panel.count:SetText(query == "" and (total .. " acquaintances") or (#people .. " of " .. total .. " acquaintances"))
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
    panel.listContent:SetHeight(math.max(210, #people * 46))
    if nicknameEditor.guid and not ns.db.known[nicknameEditor.guid] then
        nicknameEditor.guid = nil
        nicknameEditor:Hide()
    end
    local ok, guid, name = pcall(function()
        if ns.IsPlayer("target") and not UnitIsUnit("target", "player") then return ns.Identity("target") end
    end)
    panel.targetGUID = ok and guid or nil
    panel.targetName = ok and name or nil
    local knownOK, known = pcall(ns.Known, "target", ns.db)
    local description = panel.targetGUID and (ns.db.known[panel.targetGUID] and "Met" or (knownOK and known and "Recognised automatically" or "Unmet"))
    panel.targetCaption:SetText(description and ("Current target · " .. description) or "Current target")
    panel.targetLabel:SetText(panel.targetName and ns.WithoutColourCodes(panel.targetName) or "Target a player to meet them")
    panel.targetButton:SetEnabled(panel.targetGUID ~= nil)
    panel.targetButton:SetText(panel.targetGUID and ns.db.known[panel.targetGUID] and "Forget" or "Meet")
end
function ns.RefreshSettings()
    if not panel or refreshing then return end
    refreshing = true
    for key, button in pairs(checks) do button:SetChecked(ns.db.options[key]) end
    for key, slider in pairs(sliders) do
        slider:SetValue(ns.db.options[key])
        if not values[key]:HasFocus() then values[key]:SetText(tostring(ns.db.options[key])) end
    end
    for key, swatch in pairs(colours) do swatch:SetColorTexture(ns.ColourRGB(ns.db.options[key])) end
    RefreshPreviews()
    if selectedTab == "Acquaintances" then RefreshPeople() end
    panel.status:SetText(ns.db.options.enabled and "Changes apply immediately." or
        (next(ns.db.restore) and "Off · restoring original settings when combat ends." or "Off · original name settings restored."))
    refreshing = false
end
function ns.FinishSettingsInput()
    for _, input in pairs(values) do input:ClearFocus() end
    if search then search:ClearFocus() end
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
    pages[name] = scroll
    return content
end
function ns.OpenSettings()
    if category and Settings.OpenToCategory then Settings.OpenToCategory(category:GetID())
    else ns.Say("The settings panel could not load. /acquainted status shows the error; /acquainted off restores game settings.") end
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
    local appearance = Page("Appearance", 568)
    AppearanceCard(appearance, true, 16)
    AppearanceCard(appearance, false, 328)
    Checkbox(appearance, "showPetNames", "Show pet and minion names for people you know", 16, -474, 570,
        "Includes your own companions. Pets of unmet people stay hidden, even when unmet player names are visible.")
    Button(appearance, "Reset all appearance", 180, 22, -522, function() ns.ResetAppearance("all") end, "Acquainted_ResetAll")
    Text(appearance, "Keeps acquaintances and recognition rules.", "GameFontDisableSmall", 216, -529, 400)
    local recognition = Page("Recognition", 530)
    Text(recognition, "Who should count as someone you know?", "GameFontNormalLarge", 16, -12, 600)
    Text(recognition, "These people use your met appearance without needing to Meet them.", nil, 16, -44, 590)
    Checkbox(recognition, "showFriends", "Friends", 16, -82, 550, "Includes character friends and Battle.net friends.")
    Checkbox(recognition, "showGuild", "Guild members", 16, -122, 550)
    Checkbox(recognition, "showGroup", "Party and raid members", 16, -162, 550)
    Checkbox(recognition, "useTRPRelations", "Total RP 3 relationships", 16, -202, 550,
        "Recognise any TRP3 relationship except None. Total RP 3 is optional; other players do not need Acquainted.")
    Text(recognition, "Which name should appear?", "GameFontNormal", 16, -270, 600)
    Checkbox(recognition, "useRPNames", "Use Total RP 3 roleplay names", 16, -296, 550,
        "Use roleplay names when available, otherwise the game name. A personal nickname takes priority.")
    local advanced = CreateFrame("Frame", nil, recognition)
    advanced:SetPoint("TOPLEFT", 0, -392); advanced:SetSize(640, 120); advanced:Hide()
    Checkbox(advanced, "affectEnemies", "Also filter enemy players", 16, -4, 550,
        "Apply Acquainted to enemy players and their companions too. This also hides their player health bars. Change this outside combat.")
    Text(advanced, "Also hides enemy player health bars. Change this outside combat.", "GameFontDisableSmall", 48, -44, 550)
    local advancedButton
    advancedButton = Button(recognition, "+ Advanced", 144, 16, -354, function()
        local shown = not advanced:IsShown()
        advanced:SetShown(shown)
        advancedButton:SetText(shown and "− Advanced" or "+ Advanced")
    end, "Acquainted_AdvancedButton")
    local people = Page("Acquaintances", 440)
    Text(people, "Your acquaintances", "GameFontNormalLarge", 16, -12, 600)
    Text(people, "Saved separately for this character.", "GameFontDisableSmall", 16, -40, 600)
    local target = CreateFrame("Frame", nil, people)
    target:SetPoint("TOPLEFT", 16, -64); target:SetSize(592, 60)
    Background(target, 0.08, 0.08, 0.08, 0.85)
    panel.targetCaption = Text(target, "Current target", "GameFontDisableSmall", 12, -8, 420)
    panel.targetLabel = Text(target, "", nil, 12, -28, 420)
    panel.targetButton = Button(target, "Meet", 110, 466, -18, function()
        local guid, name = panel.targetGUID, panel.targetName
        if guid and name then ns.SetRemembered(guid, name, ns.db.known[guid] ~= nil) end
    end, "Acquainted_TargetButton")
    Tooltip(panel.targetButton, "Meet / Forget", "Change your saved acquaintance for this player. Enabled recognition rules can still give them the met appearance after you forget them.")
    Text(people, "Search names or nicknames", nil, 16, -146, 300)
    search = Input(people, "Acquainted_Search", 302, 22, -170)
    search:SetScript("OnTextChanged", function()
        if not refreshing then
            panel.peopleScroll:SetVerticalScroll(0)
            ns.RefreshSettings()
        end
    end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    panel.count = Text(people, "", "GameFontDisableSmall", 346, -177, 260)
    local scroll = CreateFrame("ScrollFrame", nil, people, "UIPanelScrollFrameTemplate")
    panel.peopleScroll = scroll
    scroll:SetPoint("TOPLEFT", 16, -210); scroll:SetSize(562, 210)
    panel.listContent = CreateFrame("Frame", "Acquainted_AcquaintanceList", scroll)
    panel.listContent:SetSize(554, 210); scroll:SetScrollChild(panel.listContent)
    panel.empty = Text(panel.listContent, "", nil, 4, -10, 540)
    -- Parent to the fixed settings canvas, outside both scrolling containers.
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
    local help = Page("Help", 470)
    Text(help, "Getting started", "GameFontNormalLarge", 16, -12, 600)
    Text(help, "Target a player and choose Meet in Acquaintances or their right-click menu. Other players do not need an addon.", nil, 16, -48, 580)
    Text(help, "Useful commands", "GameFontNormal", 16, -116, 600)
    Text(help, "/acq — open settings\n/acq togglemet — Meet / Forget your target with the same keybind\n/acq meet [nickname] — meet your target, optionally with a nickname\n/acq forget — forget your target\n/acq off — turn off and restore the original game settings", nil, 16, -148, 590)
    Text(help, "A few things to know", "GameFontNormal", 16, -286, 600)
    Text(help, "Forgetting removes the saved acquaintance. Recognition rules can still give them the met appearance.\n\nNames use Blizzard's nameplate range. Chat and tooltips still show names. Pet filtering also hides ordinary critter names while Acquainted is active.", nil, 16, -318, 580)
    category = Settings.RegisterCanvasLayoutCategory(panel, "Acquainted")
    Settings.RegisterAddOnCategory(category)
    panel:SetScript("OnShow", ns.RefreshSettings)
    panel:SetScript("OnHide", function()
        ns.CloseColourPicker()
        ns.FinishSettingsInput()
    end)
    SelectTab("Appearance")
end
