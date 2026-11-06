local _, ns = ...

local function ResolvePerson(context)
    local unit = context and context.unit
    if not unit or not ns.IsPlayer(unit) or UnitIsUnit(unit, "player") then return end
    return ns.Identity(unit)
end

function ns.RegisterContextMenus()
    if not Menu or not Menu.ModifyMenu then
        ns.Error("Player context menus are unavailable in this client.")
        return
    end
    -- Use live unit menus rather than friend/chat rows that may not identify a
    -- character reliably. Each registration needs its own callback closure.
    for _, suffix in ipairs({ "PLAYER", "PARTY", "RAID", "RAID_PLAYER" }) do
        Menu.ModifyMenu("MENU_UNIT_" .. suffix, function(owner, root, context)
            if context and context.which and context.which ~= suffix then return end
            if not ns.IsEnabled() or not owner or (owner.IsForbidden and owner:IsForbidden()) then return end
            local ok, guid, name = pcall(ResolvePerson, context)
            if not ok or not guid or not name then return end
            -- Capture the clicked person's identity now. A target change while
            -- the menu is open must never meet/forget a different character.
            local forget = ns.db.known[guid] ~= nil
            root:QueueDivider()
            root:QueueTitle("Acquainted")
            local button = root:CreateButton(forget and "Forget" or "Meet", function()
                if ns.IsEnabled() then ns.SetRemembered(guid, name, forget) end
            end)
            if forget and button.SetTooltip then
                button:SetTooltip(function(tooltip)
                    tooltip:AddLine("Forget this person")
                    tooltip:AddLine("Enabled friend, guild, group, or TRP3 rules can still show their name.", 1, 1, 1, true)
                end)
            end
        end)
    end
end
