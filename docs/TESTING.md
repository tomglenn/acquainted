# In-game checks for temporary settings

Automated API simulations do not establish how the live client saves or removes
temporary overrides. Run these checks on Forever before treating the 0.6.x series as stable.

1. Install the update and fully restart WoW once. The manifest now declares
   account-wide cleanup data. Finish combat before using `/acq off`.
2. With Acquainted off, record the current values of the relevant settings. For
   example, this read-only command prints the current and factory-default value:

   ```text
   /run local k="nameplateShowFriendlyPlayers"; print(k,C_CVar.GetCVar(k),C_CVar.GetCVarDefault(k))
   ```

   Repeat for `nameplateShowOnlyNameForFriendlyPlayerUnits`, `nameplateShowAll`,
   and `UnitNameFriendlyPlayerName`. Factory defaults are reference information;
   a user's current preferences may intentionally differ.
3. With friendly plates off, enable Acquainted solo. Check met/unmet colours,
   names, Unmet and question-mark displays, Hide controls, and guild lines. No
   health bars should be introduced. Disable it and compare the recorded values.
4. Repeat with friendly health plates already enabled and **Always show nameplates** off. Standalone solo labels should still appear while the saved Always Show preference stays off. Keep their bars and check
   that custom names and guild lines sit above them. Disabling must reveal the
   current saved preferences, including any intentional changes made meanwhile.
   Repeat the pet check with friendly plates off/minions on, friendly plates
   on/minions off, and both on. Pet bars introduced by Acquainted should be
   hidden; already-enabled pet bars should remain visible. Check own pets and
   summoned minions too, including grouping, disabling, and overlay mode.
5. Repeat enable/disable after `/reload` and a full client restart. Saved settings
   must not acquire Acquainted's temporary values. When checking disk files, quit
   the game before reading them; a running client may not have saved its state.
6. Join a party outdoors, convert to a raid, and leave. Outsiders should keep
   their met/unmet styling throughout. Members should use met styling by default
   without being saved as acquaintances. Their native health bars must remain
   visible if previously enabled; names and guild lines should clear the bars.
   Repeat with friendly plates off and with names-only on: grouping must not
   introduce player health bars. Roster changes need no game-setting writes.
7. Repeat those group transitions during combat. Custom names should continue
   without changing native player health frames. Enter an instance: temporary
   game-setting overrides should be removed when allowed, and only accessible
   plates should retain custom text. Restricted plates must stay native. If
   cleanup is combat-blocked, verify the pending status clears after combat.
8. With Plater enabled, check that outsider unmet reminders stay visible while
   grouped and that recognition updates members' Acquainted overlay only. Plater
   names, health bars and preferences must remain under Plater's control.
9. While Acquainted is active, toggle Blizzard's **Show only name** off, on, off,
   and on again. Both met and unmet custom names should stay active. Checked
   should hide friendly player bars; unchecked should show them, with text above
   the bar. Retry `/acq setup`, change enemy scope, and reload: Acquainted must not
   reclaim a names-only override after you chose the checkbox value. Repeat with
   friendly plates initially off/on and names-only initially off/on. A combat-
   blocked override removal must complete after combat without stopping names.
10. Check custom text above enemy and companion health bars with friendly-player
   names-only enabled. Change targets and watch for overlapping text or stale
   names as plates enter and leave range. In a developer test with another addon
   changing a required effective visibility setting, Acquainted should stop
   filtering and report the conflict, release native names, and avoid repeatedly
   resetting the other addon's setting. Resolve the conflict and use `/acq setup`
   to retry explicitly.

On failure, record the scenario, `/acq status` output, and the affected setting's
current value. Use `/acq off` outside combat. A full client restart expires native
temporary overrides; it cannot repair unknown preference changes made by older
versions without a saved recovery record. Do not reset all WoW settings as a test.
