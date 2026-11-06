local _, ns = ...
local panel, category, refreshing
local checks, sliders, rows, colours = {}, {}, {}, {}
local pickerSession, pickerHooked

local function Text(parent, text, font, x, y, width)
    local label = parent:CreateFontString(nil, "ARTWORK", font or "GameFontHighlight")
    label:SetPoint("TOPLEFT", x, y)
    if width then label:SetWidth(width); label:SetJustifyH("LEFT") end
    label:SetText(text)
    return label
end

local function Button(parent, text, width, x, y, onClick, name)
    local button = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 24)
    button:SetPoint("TOPLEFT", x, y)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local function Checkbox(key, title, y)
    local button = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    button:SetPoint("TOPLEFT", 14, y)
    Text(button, title, "GameFontHighlight", 30, -7, 570)
    button:SetScript("OnClick", function(self)
        ns.SetOption(key, self:GetChecked() and true or false)
        ns.RefreshSettings()
    end)
    checks[key] = button
end

local function Slider(key, title, low, high, x, y)
    local name = "Acquainted_" .. key .. "Slider"
    local slider = CreateFrame("Slider", name, panel, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", x, y)
    slider:SetWidth(240)
    slider:SetMinMaxValues(low, high)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    local label = slider.Text or _G[name .. "Text"]
    local bottomLow, bottomHigh = slider.Low or _G[name .. "Low"], slider.High or _G[name .. "High"]
    if bottomLow then bottomLow:SetText(tostring(low)) end
    if bottomHigh then bottomHigh:SetText(tostring(high)) end
    slider:SetScript("OnValueChanged", function(_, value)
        if label then label:SetText(title .. ": " .. math.floor(value + 0.5)) end
        if not refreshing then ns.SetOption(key, math.floor(value + 0.5)) end
    end)
    sliders[key] = slider
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

local function ColourButton(key, title, x, y)
    local button = Button(panel, title, 240, x, y, function() PickColour(key) end, "Acquainted_" .. key .. "Button")
    colours[key] = { button = button, title = title }
end

function ns.RefreshSettings()
    if not panel or refreshing then return end
    refreshing = true
    for key, button in pairs(checks) do button:SetChecked(ns.db.options[key]) end
    for key, slider in pairs(sliders) do slider:SetValue(ns.db.options[key]) end
    for key, control in pairs(colours) do
        local hex = ns.db.options[key]
        control.button:SetText(control.title .. ": |cff" .. hex .. "#" .. hex .. "|r")
    end
    for _, row in ipairs(rows) do row:Hide() end
    local people = {}
    for guid, record in pairs(ns.db.known) do
        people[#people + 1] = { guid = guid, name = record.name, nickname = record.nickname }
    end
    table.sort(people, function(a, b) return a.name < b.name end)
    for index, person in ipairs(people) do
        local row = rows[index]
        if not row then
            row = CreateFrame("Frame", nil, panel.listContent)
            row:SetSize(550, 28)
            row:SetPoint("TOPLEFT", 0, -(index - 1) * 28)
            row.label = Text(row, "", "GameFontHighlight", 4, -6, 420)
            row.button = Button(row, "Forget", 90, 440, 0, function() ns.Forget(row.guid) end)
            rows[index] = row
        end
        row.guid = person.guid
        row.label:SetText(person.nickname and (person.nickname .. " (" .. person.name .. ")") or person.name)
        row:Show()
    end
    panel.empty:SetShown(#people == 0)
    panel.listContent:SetHeight(math.max(115, #people * 28))
    refreshing = false
end

function ns.OpenSettings()
    if category and Settings.OpenToCategory then Settings.OpenToCategory(category:GetID())
    else ns.Say("The settings panel could not load. /acquainted status shows the error; /acquainted off restores game settings.") end
end

function ns.CreateSettings()
    local canvas = CreateFrame("Frame")
    canvas.name = "Acquainted"
    local outerScroll = CreateFrame("ScrollFrame", nil, canvas, "UIPanelScrollFrameTemplate")
    outerScroll:SetPoint("TOPLEFT", 0, 0)
    outerScroll:SetPoint("BOTTOMRIGHT", -30, 0)
    panel = CreateFrame("Frame", nil, outerScroll)
    panel:SetSize(640, 1142)
    outerScroll:SetScrollChild(panel)
    Text(panel, "Acquainted", "GameFontNormalLarge", 16, -16)
    Text(panel, "Names appear when you remember someone. They do not need an addon.", nil, 16, -46, 600)
    Text(panel, "Switching Acquainted off restores your original name and nameplate settings.", nil, 16, -67, 600)
    Checkbox("enabled", "Enable Acquainted", -94)
    Checkbox("showFriends", "Always show friends (character friends and Battle.net friends)", -126)
    Checkbox("showGuild", "Always show guild members", -158)
    Checkbox("showGroup", "Always show party and raid members", -190)
    Checkbox("useTRPRelations", "Recognise people with a TRP3 relationship, when TRP3 is installed", -222)
    Checkbox("useRPNames", "Use TRP3 names when available", -254)
    Checkbox("affectEnemies", "Also filter enemy players (hides their player health bars too)", -286)
    Checkbox("showGuildName", "Show guild beneath known names", -318)
    Checkbox("showPetNames", "Show pet/minion names for known people", -350)
    Text(panel, "Met people", "GameFontNormal", 16, -401)
    Slider("fontSize", "Name size", 8, 48, 22, -444)
    Slider("nameOffset", "Name height", -200, 100, 330, -444)
    ColourButton("metColour", "Met name colour", 22, -486)
    Button(panel, "Reset met style", 240, 330, -486, function() ns.ResetAppearance("met") end)
    Text(panel, "Negative height values move names down, below the old zero limit.", nil, 16, -520, 600)
    Text(panel, "Unmet people", "GameFontNormal", 16, -556)
    Checkbox("showUnmetNames", "Show names of people you have not met", -578)
    Checkbox("showUnmetGuildName", "Show guild names for unmet people", -610)
    Slider("unmetFontSize", "Name size", 8, 48, 22, -670)
    Slider("unmetNameOffset", "Name height", -200, 100, 330, -670)
    ColourButton("unmetColour", "Unmet name colour", 22, -712)
    Button(panel, "Reset unmet style", 240, 330, -712, function() ns.ResetAppearance("unmet") end)
    Text(panel, "Unmet guilds follow the unmet name style when enabled. Their pet names stay hidden.", nil, 16, -748, 600)
    Button(panel, "Reset name display", 240, 16, -784, function() ns.ResetAppearance("all") end)
    Text(panel, "Resets display only; keeps acquaintances and recognition rules.", nil, 272, -789, 330)
    Text(panel, "People remembered by this character", "GameFontNormal", 16, -834)
    Button(panel, "Remember target", 155, 16, -860, function() ns.RememberTarget(false) end)
    Button(panel, "Forget target", 135, 180, -860, function() ns.RememberTarget(true) end)
    Button(panel, "Disable and restore", 180, 325, -860, function() ns.SetOption("enabled", false) end)
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -900)
    scroll:SetSize(560, 120)
    panel.listContent = CreateFrame("Frame", nil, scroll)
    panel.listContent:SetSize(550, 115)
    scroll:SetScrollChild(panel.listContent)
    panel.empty = Text(panel.listContent, "No one remembered yet. Target a player and click Remember target.", nil, 4, -6, 540)
    Text(panel, "Use /acq togglemet as a reversible Meet / Forget keybind for your target.", nil, 16, -1039, 600)
    Text(panel, "Names use Blizzard's available nameplate range. Chat and tooltips still show names.", nil, 16, -1062, 600)
    Text(panel, "Other enabled visibility rules can still reveal someone you forget.", nil, 16, -1085, 600)
    Text(panel, "Pet filtering also hides ordinary critter names while Acquainted is active.", nil, 16, -1108, 600)
    category = Settings.RegisterCanvasLayoutCategory(canvas, "Acquainted")
    Settings.RegisterAddOnCategory(category)
    panel:SetScript("OnShow", ns.RefreshSettings)
    ns.RefreshSettings()
end
