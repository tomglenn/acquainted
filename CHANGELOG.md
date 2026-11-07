# Changelog

## 0.7.4

- Replace the unmet question mark with a bundled grey person silhouette, shared by the live display and settings preview. The icon follows the unmet size and position settings.
- Rename the display choice to Icon and include its texture in release packages and local installations.

## 0.7.3

- Rename the compatibility option to Add labels alongside existing names and explain that existing names remain visible, potentially showing duplicates.
- Lay out Help sections using their actual text height to remove large gaps and prevent overlap.
- Show page scrollbars only when content overflows. Use one scrolling area for Acquaintances, sized to the filtered list, and trim unused space in collapsed Recognition settings.

## 0.7.2

- Add concise Appearance and Help explanations of Blizzard friendly nameplate anchors, temporary settings, health-bar controls, other nameplate addons, and instance restrictions.
- Treat Show only name as a user-controlled appearance setting rather than a required visibility setting. Checkbox changes in either direction keep Acquainted active and update text positioning above health bars.
- Observe Blizzard's requested checkbox value and release only Acquainted's names-only override after the settings callback finishes. Preserve explicit user control across setup, scope changes, and reloads; combat-blocked cleanup remains deferred.
- Clarify that Blizzard's Show only name affects all friendly player bars, including unmet players, independently of Acquainted's name styling.

## 0.7.1

- Move Export list and Import list to the top right, inline with Your acquaintances.
- Remove the current-target Meet/Forget section from settings and move search/list content up. Meet remains available through commands and player context menus.

## 0.7.0

- Remove the blanket party/raid shutdown. Outsiders retain met/unmet styling while grouped, and current party/raid members use the configured recognition rules (met by default).
- Keep native player health bars unchanged: bars remain visible if friendly health plates were previously enabled, while previously disabled or names-only bars are not introduced on grouping. Roster changes update styling without game-setting writes, including during combat.
- In instances, remove temporary game-setting overrides but continue styling accessible plates. Forbidden and unsupported plates retain their native display instead of disabling all custom names.
- Update settings/help and regression checks for party/raid transitions, saved health-bar preferences, Plater outsider reminders, and instance cleanup.

## 0.6.3

- Hide companion health/level visuals only on friendly pet/minion plates introduced by Acquainted's temporary settings, while retaining custom companion names. This includes saved-on minion settings that were inactive under a saved-off friendly-plate parent switch.
- Preserve already-enabled companion health bars, enemy pet bars, player health bars, grouped displays, and Plater/manual overlay displays. Restore companion opacity on disable, group entry, plate reuse, and mode changes.
- Reassert companion-specific masks after native opacity resets, and retry visual restoration when a companion region becomes accessible again.

## 0.6.2

- Detect required effective nameplate settings changed by the user or another addon. Stop filtering, release native name masks, and remove owned overrides instead of leaving ordinary names hidden without custom anchors or repeatedly fighting the other setting. Listen for CVar updates and allow explicit `/acq setup` retry.
- Report failed activation and combat-deferred startup accurately in the settings panel.
- Position custom enemy and companion names above visible health bars even when friendly-player names-only mode is enabled.
- Preserve GUID-based recognition, nicknames, and saved names when a live name is temporarily unavailable. Keep Meet/Forget actions disabled until a full current identity is available.
- Release stale native text masks immediately if a plate pool replaces its native frame or name region.
- Retain temporary cleanup ownership when a CVar cannot be read, allowing a later retry.
- Require and verify the transfer module during local installation, rejecting incomplete source before modifying installed files.

## 0.6.1

- Temporarily enable Always show nameplates in standalone solo mode even when friendly plates were already enabled. This keeps custom met/unmet labels available when the saved Always Show setting is off.
- Preserve the saved Always Show preference, restore it on disable/group entry, and leave Plater/manual overlay settings untouched.

## 0.6.0

- Use temporary client overrides for solo custom displays, preserving saved game preferences. Removing overrides reveals the latest saved choices rather than writing old snapshots back.
- Keep party/raid/instance pass-through, names-only solo anchors, custom met/unmet styling, and Plater overlays.
- Record cleanup ownership account-wide so combat-blocked reloads and character switches can remove surviving overrides. Temporary overrides expire on a full client restart.
- Recover legacy persistent-setting snapshots once before activation; do not fall back to persistent writes when temporary APIs are unavailable or rejected.
- Preserve different effective values supplied by other addons during cleanup. Add simulated checks separating runtime overrides from saved preferences, failures, reloads, restarts, legacy recovery, and character switching.
- Fully restart WoW once after installing this update to load the new saved-variable declaration.

## 0.5.1

- Pause all overhead filtering in parties, raids, instance groups, and instances, including outdoors and in overlay mode. Release custom labels and native name masks immediately, restore solo game settings, and leave subsequent grouped settings changes untouched.
- Retry combat-blocked settings restoration when combat ends, expose pending restoration in settings/status, and resume solo filtering using the latest user preferences after leaving groups and instances.
- Use names-only solo frames when friendly plates were originally off, avoiding newly introduced health bars. Preserve names-only and visibility preferences when friendly plates were already enabled, and position custom text and guild lines above existing health bars.

## 0.5.0

- Preserve native health and cast bars by masking only accessible name text; stop forcing friendly names-only plates and restore previously managed names-only settings on upgrade.
- Add matching Hide controls for met and unmet people, preserving the old unmet visibility preference.
- Add Name, Unmet, and question-mark display choices for unmet people, with live previews and no guild line in anonymous modes.
- Detect Plater automatically and add labels without changing its display or game settings. Add a manual overlay-only option for other nameplate addons.
- Recognise guild and party/raid members by default on new installations, preserving existing explicit preferences.
- Add versioned export/import for manual acquaintances and nicknames, with a preview, conflict-preserving merge, optional overwrite/replacement, and full validation before mutation. Machine-local settings and recovery data are excluded.

## 0.4.3

- Replace template-based text boxes with explicitly styled fields and text padding.
- Draw saved size and height values in a separate text region while idle, switching to editable text on focus.

## 0.4.2

- Refresh size and height values whenever their input fields appear. Includes the explicit edit-box font fix from 0.4.1.
- Replace the startup instructions with a short welcome, addon version, and `/acq` settings shortcut.
- Prefer `/acq` in status and help messages; `/acquainted` remains supported.

## 0.4.1

- Open nickname editing in a centred dialog above the settings, so it cannot be hidden below the acquaintance list.
- Explicitly set edit-box fonts so nicknames and size/position values remain readable on Forever.

## 0.4.0

- Redesign settings into Appearance, Recognition, and Acquaintances tabs, with a separate Help page.
- Add side-by-side live previews for met and unmet name styles.
- Add exact-value text boxes for size and vertical position, with Lower/Higher slider labels and compact colour swatches.
- Group recognition rules together and move enemy filtering into a collapsible Advanced section.
- Add a searchable acquaintance list, nickname editing, and a current-target Meet/Forget button.
- Keep the enable switch visible across tabs and preserve existing acquaintances and preferences.

## 0.3.3

- Add “Show guild names for unmet people”, off by default, in the Unmet people settings.
- Unmet guilds appear beneath visible unmet names using the same colour and a smaller font.
- Keep met and unmet guild visibility independent; unmet pets remain hidden.

## 0.3.2

- Set the default name height to -40 for both met and unmet players.
- Show unmet names by default, using size 14 and grey; met names remain size 22 and gold.
- Reset buttons use these new defaults. Existing saved preferences are preserved.

## 0.3.1

- Hide native player names immediately when their nameplate appears, preventing a brief flash of the default blue name.
- Reapply existing nameplate masks each frame when WoW resets their opacity.
- Clear custom names immediately when a nameplate is removed or reused.

## 0.3.0

- Add separate size, height, and colour settings for met and unmet players.
- Allow name heights from -200 to 100, so names can be moved below the previous zero limit.
- Add optional display of unmet players' names, using smaller grey text by default.
- Add reset buttons for each style and for all name-display settings.
- Add `/acq togglemet` to switch the targeted player's saved Meet/Forget state with one command.
- Preserve existing met-name size, height, acquaintances, and recognition settings when upgrading.

## 0.2.5

- Prepare the standalone Acquainted source repository and public documentation.
- Add automated, validated ZIP packaging for GitHub Releases and version tags.
- Add continuous checks for addon behavior, installation, and release packaging.
- Remove machine-specific metadata and obsolete migration code from the public package.

## 0.2.4

- Shorten Forget confirmations to "Forgot [name]."
- Allow installing updates while the game is running.

## 0.2.3

- Keep Acquainted in its own addon-list group.

## 0.2.2

- Establish the Acquainted addon name and `/acq` and `/acquainted` commands.

## 0.2.1

- Add Meet and Forget actions to player context menus.
- Show a smaller guild line beneath known players' names.
- Add owner-based pet and minion name visibility.

## 0.2.0

- Introduce standalone acquaintance tracking, nicknames, visibility settings, and large overhead names without health bars.
