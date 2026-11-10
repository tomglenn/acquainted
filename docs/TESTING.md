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

## IC-only mode

Enable **Only while in character in Total RP 3** under Recognition. Switch IC/OOC
and change TRP3 profiles: OOC should restore native names and settings; IC should
resume met/unmet styling. Check solo, grouped, instance, and Plater displays.
Repeat during combat: custom labels should stop while OOC, with blocked settings
cleanup deferred until combat ends; resuming IC must also wait if necessary.
Reload while OOC and check that no custom names or temporary overrides activate.
Acquaintances and nicknames must survive each transition. Disable the option,
and repeat without TRP3 installed: normal Acquainted displays should work.

## Recent players

- Join a party, leave/disband quickly, and find its members under Acquaintances →
  Recent players. Repeat in a raid and with friendly nameplates disabled or
  restricted in an instance. Meet someone after they leave or log out; their
  game name should appear in Saved acquaintances, with normal met styling when
  encountered again. RP names should help identify them without hiding game names.
- Gather over 50 nearby players in a crowded area. Check that only the newest 50
  remain nearby and that former group members remain in their separate history.
  A nearby person who joins your group should move to Group members without
  appearing twice. Already saved acquaintances should not consume history slots.
- Search both game and RP names, clear the search, and switch between saved and
  recent views. Group members should appear first; only one scrollbar should
  appear when the content needs it. Long RP names should not overlap other rows.
- Cancel Clear history, then confirm it. Cancellation preserves both lists;
  confirmation empties both but preserves acquaintances and nicknames. Reload
  before clearing to verify histories persist separately for each character.
- Disable Acquainted or switch OOC in IC-only mode: no new encounters should be
  captured. Re-enable or switch IC: current group members should be collected.
  Check CPU usage in a busy area with settings closed and with Recent open;
  the displayed rows should stay still as players arrive, leave, or change order.
  Refresh list should show new encounters; searching should keep the same snapshot.
  Keep a row open while over 50 newcomers arrive: its Meet button should still
  meet the displayed player, even if they have left the stored recent history.

## Navigation and readability

Check that Appearance, Recognition, Acquaintances, and Help use native tabs,
with a clearly selected tab. Acquaintances should have a separate, smaller
Saved / Recent tab bar. Selecting one level must not alter the other. Clicking
the selected tab should keep search text, scroll position, and Recent rows intact.
Confirm that tab labels fit after reopening settings or changing UI scale.
Red buttons should remain for actions such as Meet, Refresh, and Clear history.
The main panel should use the standard WoW settings background.

## Recognition colours and social lists

- Upgrade with the old Friends option both on and off. Confirm the split
  Character friends, WoW Friends, and Battle.net friends preserve that choice.
  Test the three kinds separately; a non-friend with returned account data must
  remain unmet. Removing friends should update recognition without a reload.
- Enable each recognition category and choose Met colour, then Custom colour.
  Confirm the swatch appears only for Custom, preview changes immediately, and
  picker Cancel restores the old colour. Check names, guild lines, and pets.
  Size, position, Hide, native health/cast bars, and nameplate settings must not change.
- Test a guildmate who is also a friend and in the group. The first enabled
  matching custom colour in the displayed order wins. Inherited Met colours
  must not block lower custom colours. Manual Meet and nicknames keep overrides.
  Individual Met reset keeps overrides; Reset all appearance clears them.
- Enable Selected communities, choose one or several joined WoW communities,
  and wait for rosters. Verify recognition without opening or changing community
  UI selections, no recognition for unselected communities, and correct updates
  after member additions/removals, presence changes, leaving a community, and reload.
  Overlapping memberships should still recognise a person after one is removed.
  Unavailable or restricted GUIDs must not be matched by name instead.
- Repeat community loading with Acquainted disabled and with IC-only mode OOC,
  then activate it. Missing social APIs should leave other recognition working.
  Keep a Recent list open during social updates: its entries should stay pinned.
