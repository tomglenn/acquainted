# Acquainted

*Learn their name when you meet them.*

Acquainted is a standalone roleplay addon for **World of Warcraft: Forever**. It gives met and unmet players distinct overhead name styles, with independent Hide controls for met and unmet people. Unmet people can show their name, an “Unmet” label, or a grey person icon. Other players do not need an addon. **Total RP 3 integration is optional.**

## Features

- **Recent players:** find the last 50 group members and 50 nearby players under Acquaintances → Recent players. Meet someone after they have left or logged out, using their saved character identity. Group history has its own capacity, protected from nearby crowds.

- Meet and Forget actions in player portrait, party, and raid context menus.
- Styled overhead names and a smaller guild line, without introducing unwanted health bars.
- Met/unmet styling stays active while grouped, with native party/raid health bars preserved according to existing preferences.
- Instances use existing nameplate settings and decorate only accessible plates.
- Automatic Plater overlay mode, plus a manual overlay option for other nameplate addons.
- Independent Hide controls for met and unmet people, and anonymous unmet labels or indicators.
- Export/import of manual acquaintances and nicknames between machines.
- Per-character lists of people you have met, with optional personal nicknames.
- Automatic recognition of guild and group members by default, with optional friend recognition.
- Optional recognition of TRP3 relationships and display of RP names.
- Pet and minion names that follow whether their owner is known.
- Tabbed settings with live previews, exact size/height values, colour swatches, and reset buttons.
- Searchable acquaintances with nickname editing and Export/Import beside the list heading.
- Smaller grey names for people you have not met yet, with an option to hide them.
- A reversible Meet/Forget command suitable for a single keybind.
- Restoration of the original managed game settings when disabled normally outside combat.

## Installation

Download the **Acquainted versioned ZIP** attached to a GitHub Release. Extract its `Acquainted` folder into:

```text
World of Warcraft/_forever_/Interface/AddOns/
```

The resulting manifest path should be `Interface/AddOns/Acquainted/Acquainted.toc`. Enable **Acquainted** in the game's addon list. No additional addon or library is required.

For local development, the optional installer accepts an AddOns folder:

```sh
python3 install.py --addons-dir "/path/to/_forever_/Interface/AddOns"
```

On macOS, running `python3 install.py` also detects the standard installation location. The installer permits updates while WoW is running and backs up existing Acquainted files locally. Use `/reload` for Lua updates; new addon folders or changed metadata may require restarting the game. **For the upgrade to 0.6.0, fully restart WoW once after installing** so the new account-wide cleanup bookkeeping is loaded.

## Recent players

Open **Acquaintances → Recent players** to find someone you missed before a party disbanded. Group members appear first, followed by nearby players. The list stays still while you browse; click **Refresh list** to load newer encounters. Search their game or RP name and click **Meet**, even after they have gone offline. Met players move to **Saved acquaintances**, where you can edit their nickname.

Each character keeps up to **50 group members and 50 nearby players**, saved across reloads. Within each history, a new encounter replaces the least recent one; nearby players cannot evict group members. Someone in both histories appears only under Group members. **Clear history** removes recent entries after confirmation, keeping your saved acquaintances.

History starts collecting after this update while Acquainted is enabled, respecting IC-only mode. Group members are recorded from the roster even without visible nameplates; nearby players must be exposed through nameplates or player-name updates. NPCs, pets, your character, and unreadable identities are excluded. Only names, character IDs, encounter types and times are stored—not full RP profiles. Export/import includes permanent acquaintances and nicknames, not recent history.

## Getting started

1. Type `/acq` to open settings.
2. Target a player and type `/acq meet`, or right-click their portrait and choose **Meet** in the **Acquainted** section.
3. Use **Forget** or `/acq forget` to remove their saved acquaintance.
4. Use `/acq meet The Herbalist` to give your target a personal nickname.
5. Bind `/acq togglemet` instead of `/acq meet` if you want the same key to undo an accidental Meet.

Forgetting someone removes only the manual record. Enabled friend, guild, group, or TRP3 rules can still reveal them.

## Settings

- **Appearance:** starts with a short explanation of Blizzard friendly nameplates and temporary settings. Compare met and unmet styles side by side with live previews. Each card has a **Hide** checkbox; unmet people also have **Name**, **Unmet**, and **Icon** display choices. Drag the size and position sliders, or type exact values and press Enter. Lower/Higher labels show the direction. Click a colour swatch to open the colour picker. Each card has its own guild toggle and appearance reset; pet names and the full appearance reset are below the cards. Preview position is shown at quarter scale; in-game height uses the value entered.
- **Recognition:** choose who automatically counts as met. The roleplay-name preference is separate; enemy filtering is under **Advanced**.
- **Acquaintances:** search saved names and nicknames, edit a nickname, or forget a saved person. **Export list** and **Import list** sit at the top right beside **Your acquaintances**. Save a blank nickname to use their roleplay or game name again.
- **Help:** commands, keybind guidance, and a short list of Blizzard settings and addon/instance restrictions that affect name display.

Navigation uses native WoW tabs, with smaller **Saved / Recent** tabs inside Acquaintances. Red buttons perform actions such as Meet, Refresh list, and Clear history.

The enable switch remains available on every tab. Changes apply immediately; typing Escape cancels a number or nickname edit. Numeric changes also apply when you click away. Switching off restores the original managed game settings.

| Setting | Default | Effect |
| --- | --- | --- |
| Enable Acquainted | On | Enable overhead-name filtering |
| Recognise friends | Off | Recognise character and Battle.net friends |
| Recognise guild members | On | Recognise members of your guild |
| Recognise party and raid members | On | Recognise your current group |
| Recognise TRP3 relationships | On | Any available relationship except None counts |
| Only active while IC in Total RP 3 | Off | Pause displays and restore normal nameplate settings while OOC; resume while IC. No effect without TRP3. |
| Use TRP3 names | On | Prefer RP names when available |
| Also filter enemy players | Off | Apply the same rules to exposed enemy player/companion plates |
| Show guild beneath known names | On | Display the actual game guild in angle brackets |
| Show pet/minion names for known people | On | Display companions only when their owner is known |
| Met name size | 22 | Adjust between 8 and 48 |
| Met name height | -40 | Adjust between -200 and 100; negative values move the name down |
| Met name colour | Gold | Choose with the colour picker; applies to the guild line too |
| Hide met people | Off | Hide the met Acquainted name and guild line |
| Hide unmet people | Off | Hide the unmet Acquainted display and guild line |
| Unmet display | Name | Choose the player name, “Unmet”, or a grey person icon |
| Add labels alongside existing names | Off; automatic with Plater | Add labels without changing native names or nameplate settings |
| Show guild names for unmet people | Off | Show a smaller guild line beneath visible unmet names |
| Unmet name size | 14 | Adjust between 8 and 48 |
| Unmet name height | -40 | Adjust independently between -200 and 100 |
| Unmet name colour | Grey | Choose independently with the colour picker |

The **Met people** and **Unmet people** cards each have a **Reset appearance** button. **Reset all appearance** restores both styles, visible names for both categories, met guilds on and unmet guilds off. Individual card resets preserve Hide, guild visibility, and the unmet display choice. These buttons preserve your acquaintances, nicknames, and friend/guild/group/TRP3 recognition rules. Existing appearance and recognition preferences are preserved when upgrading. The old unmet **Show name** preference migrates to the inverse **Hide** setting.

Met styling applies to anyone recognised by an enabled visibility rule, including friends or TRP3 relationships. If unmet names are visible and **Display as** is **Name**, their guild can also be shown with **Show guild** on the **Unmet people** card. This is independent of the setting for known players and uses the unmet name style. Unmet companion names remain hidden. The chosen colours apply to RP names as well. Colour-picker changes preview live, and Cancel restores the previous colour.

Guild and group recognition applies only while the relationship exists and does not create manual acquaintances. Grouping does not pause filtering: current party/raid members use met styling by default, with their native health bars preserved. The recognition toggle changes names, not health-bar visibility. Leaving a party or guild can return someone to the unmet appearance. Existing saved recognition choices are preserved; the new defaults apply to fresh or missing settings.

Your own character counts as a known companion owner. Player Hide controls do not affect companion names; use the separate companion setting. Switching companion names off hides the names of all managed companions, including your own. No owner guild line is displayed on pets. If Acquainted introduced their friendly plate by temporarily enabling friendly or minion plates, it hides that companion's health/level display and draws only its permitted custom name. Existing companion health bars remain visible when their plate settings were already enabled. Disabling and overlay mode release these companion-specific visual masks; grouping keeps the same companion visibility policy.

## Using Acquainted with Plater

Outside instances, Plater is detected automatically whether solo or grouped. Acquainted adds its own labels above the accessible plate without changing Plater's names, health bars, opacity, or nameplate settings. For other nameplate addons, enable **Add labels alongside existing names** outside combat.

To use Acquainted as an unmet reminder:

1. Enable **Hide** on **Met people**.
2. Leave **Hide** off on **Unmet people**.
3. Choose **Name** for a smaller grey name, **Unmet** for an anonymous label, or **Icon** for a grey person silhouette.
4. Adjust the unmet vertical position to place the reminder beneath your existing nameplate.

Hide controls only the Acquainted display in overlay mode. Existing nameplate text remains controlled by Plater or your other addon. Anonymous modes never show a guild line. Outside instances, standalone mode suppresses accessible native name text independently of health, cast, and aura frames. If friendly plates were originally off, Acquainted enables names-only frames to anchor its labels without introducing health bars. Standalone mode temporarily enables **Always show nameplates** in either case so the anchors remain available; the saved value is unchanged. If friendly plates were already on, their names-only preference is preserved, and custom text is positioned above an accessible health bar so its guild line clears the bar too. Visible enemy and companion health bars receive the same spacing; friendly-player names-only mode does not apply to them. A negative vertical offset is clamped above the bar in that case. You can change Blizzard's **Show only name** checkbox while Acquainted is active: checked hides friendly player bars; unchecked shows them, including for unmet players. Acquainted keeps rendering names and releases its own names-only override after your explicit choice. That choice remains under your control across setup, scope changes, and reloads. Temporary overrides are removed when filtering stops, revealing the current saved preferences.

## Parties, raids, and instances

Grouping keeps Acquainted active. People outside your party/raid retain their existing met or unmet appearance. Current party/raid members count as met by default and keep the native health bars allowed by your prior settings. Acquainted replaces only player name text; it does not hide, fade, or resize player health bars. Custom names and guild lines sit above a visible bar.

If friendly player health plates were enabled and names-only mode was off before Acquainted applied its overrides, group bars remain visible. If friendly plates were off, or names-only mode was already on, grouping does not introduce health bars. Recognition choices, including **Party and raid members**, affect name styling rather than bar visibility. There is no automatic permanent Meet when someone joins.

Outside instances, the temporary settings needed for outsider labels remain active across group joins, raid conversions, and leaves. Roster events refresh recognition without rewriting game settings, including during combat. Plater/manual overlay modes likewise keep outsider reminders active and leave the native display under the nameplate addon's control.

Inside instances, Acquainted removes its temporary game-setting overrides and uses existing settings. It can still style accessible nameplates, including outsiders, but forbidden frames and unsupported native layouts remain native. If existing settings do not provide accessible plates, custom names cannot be shown there. This is a per-plate fallback rather than a blanket shutdown of all rendering.

WoW may delay removal of outdoor overrides when entering an instance during combat. The settings panel reports pending cleanup, which retries after combat ends. Accessible custom labels can continue meanwhile; player health frames are never masked. Live-client party/raid and instance verification remains required.

## Transferring your Met list between machines

Acquainted saves data locally for each character. It has no automatic server or cloud synchronisation.

1. On the source machine, open **Acquaintances → Export list** and copy all the selected text. Save it in a text file or transfer it through your usual document-sync service.
2. On the destination machine, open **Acquaintances → Import list**, paste the text and choose **Preview import**.
3. Review the new/existing counts and nickname conflicts, then choose **Merge list**.

Merging keeps local entries, including existing names and nicknames, by default. **Use imported names and nicknames for existing people** explicitly allows overwriting conflicts. **Replace entire list** removes local entries absent from the import; its preview reports how many will be removed and changes the action to **Replace list**. Edits to the pasted text, import options, or local list require a fresh preview.

Only manual acquaintances and nicknames are transferred. Appearance, recognition rules, and game-setting recovery snapshots remain local. Exports use a versioned text format, are validated in full before import, and never execute Lua. Limits are 10,000 people, 512 bytes per name/nickname, and 1 MiB per transfer. Merging does not propagate Forget actions; use replacement when intentionally making one machine match another.

## Commands

Both `/acq` and `/acquainted` accept these commands:

| Command | Action |
| --- | --- |
| `/acq` | Open settings |
| `/acq meet [nickname]` | Remember your target |
| `/acq forget` | Forget your target |
| `/acq togglemet` | Toggle your target's saved Meet/Forget state |
| `/acq on`, `/acq off`, `/acq toggle` | Control filtering |
| `/acq restore` | Disable and restore original settings |
| `/acq status` | Show version, filtering status, and any compatibility error |
| `/acq setup` | Reapply the temporary name settings once |
| `/acq help` | Show command help |

For a reversible Meet/Forget keybind, create a macro containing:

```text
/acq togglemet
```

This toggles the manual acquaintance record; automatic recognition rules can still keep someone in the met display style. Repeating the toggle during the same session restores their previous nickname too. `/acq toggle` continues to enable or disable the addon itself.

## Settings restoration and limitations

Since 0.6.0, standalone mode uses WoW's `SetTempCVar`/`RemoveTempCVar` APIs. These temporarily change the active display without rewriting saved game preferences. Only settings whose effective values need to change receive an override. Normal disabling, addon-list disabling, logout, UI reload, and entry into an instance remove Acquainted's overrides and custom text. A full client restart also expires temporary overrides.

Removing an override reveals the current saved preference, including changes made while Acquainted was active. Acquainted does not write an old snapshot over a newer saved choice. Cleanup ownership is recorded in account-wide `AcquaintedRuntime` addon data so surviving overrides can be removed after a combat-blocked reload or character switch. Manual acquaintances and appearance preferences remain in the per-character `AcquaintedDB`. Neither cleanup bookkeeping nor game settings are included in list exports.

**Upgrade recovery:** versions before 0.6.0 used persistent setting writes. Existing `restore`/`cvars` recovery records are restored once before temporary mode starts. This is the only remaining path that writes saved game preferences, and it uses the recorded originals rather than guessing factory defaults. Failed legacy recovery keeps its record and prevents activation until recovery succeeds. This cannot reconstruct preferences that were never recorded.

If the client lacks temporary-setting support, standalone filtering stays inactive rather than falling back to persistent writes. Overlay mode remains available without temporary overrides. `/acq status` reports pending cleanup or compatibility errors.

Temporary overrides are shared between addons. Acquainted does not acquire settings already at its requested value. On cleanup it leaves a different current value untouched, since that may have been supplied by another addon. Show only name is an appearance choice and does not stop filtering. If a required effective visibility setting changes during filtering, Acquainted stops filtering and releases its other overrides rather than leaving ordinary names hidden without anchors or continually rewriting the competing setting. The panel reports the failure; `/acq status` gives details and `/acq setup` explicitly retries after the conflict is resolved. Failed startup and combat-deferred activation are also shown in the panel.

WoW does not expose an ownership token or an override stack, so another addon replacing an override with the same value cannot be distinguished. Plater mode avoids introducing overrides altogether.

WoW can restrict settings changes during combat. Acquainted refuses its own enable/disable, enemy-scope, and manual overlay-mode toggles until combat ends. Pending removals retain their bookkeeping for retry; use `/acq restore` outside combat before uninstalling. After a forced termination, temporary overrides expire on a full client restart; older persistent recovery records may still need processing when their character next logs in. Live-client restart, reload, and group-transition verification remains required.

Other limits:

- Overhead text depends on accessible Blizzard nameplates, so their range, occlusion, instance, and faction restrictions apply.
- Cosmetic companions and wild critters share a native overhead-name setting. In standalone mode, ordinary critter names are hidden while Acquainted is enabled, and the setting is restored when disabled normally.
- A companion whose owner cannot be identified stays hidden. Companions without accessible nameplates cannot have their known names redisplayed.
- Chat, target frames, and mouseover tooltips can still identify people.
- Enemy filtering is optional and preserves health bars. It does not force enemy NPC plates on.
- Forbidden frames and unsupported native text layouts are skipped. Grouping preserves custom names and native player health frames. Inside instances, shared settings revert and only accessible plates are decorated. Visibility updates after relevant events and every quarter second, with accessible native name text masks reasserted before drawing.
- Plater activates overlay mode automatically. Other replacements can use the manual overlay option; custom attachment and restricted-instance behaviour still need live-client verification. Acquainted does not force nameplates on in overlay mode, so enable friendly plates in your own nameplate settings if indicators are missing.

This remains a test build. Simulated API checks cover required-setting conflicts, transient name lookups, replacement native frames, the settings panel, context menus, recognition rules, native-name-only masking, overlay rendering, transfer validation, migrations, temporary-versus-saved settings, crash/reload recovery, and restoration, but cannot establish live-client compatibility. Verify new releases in game before treating them as stable. See [the in-game check list](docs/TESTING.md) when testing from the source repository.

## Development and releases

Run the checks from the repository root:

```sh
lua tests/run.lua
python3 -m unittest discover -s tests -p 'test_*.py'
```

Pandoc's embedded Lua can also run the addon checks:

```sh
pandoc --lua-filter=tests/run.lua -f markdown -t plain /dev/null
```

Build an installable ZIP locally:

```sh
python3 scripts/package.py
```

See [the release guide](docs/RELEASING.md) for publishing a GitHub Release or version tag. Release ZIPs contain only the addon, README, and changelog. Installers, tests, backups, and game data are excluded.

Acquainted is independent software and is not an official Total RP 3 release.
