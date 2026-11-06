# Acquainted

*Learn their name when you meet them.*

Acquainted is a standalone roleplay addon for **World of Warcraft: Forever**. It hides unfamiliar players' overhead names until you choose to remember them, or optionally shows unmet names in a distinct style. Other players do not need an addon. **Total RP 3 integration is optional.**

## Features

- Meet and Forget actions in player portrait, party, and raid context menus.
- Large overhead names and a smaller guild line, without player health bars.
- Per-character lists of people you have met, with optional personal nicknames.
- Optional automatic recognition of friends, guild members, and group members.
- Optional recognition of TRP3 relationships and display of RP names.
- Pet and minion names that follow whether their owner is known.
- Separate size, height, and colour controls for met and unmet names, with reset buttons.
- Optional smaller grey names for people you have not met yet.
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

On macOS, running `python3 install.py` also detects the standard installation location. The installer permits updates while WoW is running and backs up existing Acquainted files locally. Use `/reload` for Lua updates; new addon folders or changed metadata may require restarting the game.

## Getting started

1. Type `/acq` to open settings.
2. Target a player and right-click their portrait. Choose **Meet** in the **Acquainted** section, or type `/acq meet`.
3. Use **Forget** or `/acq forget` to remove their saved acquaintance.
4. Use `/acq meet The Herbalist` to give your target a personal nickname.
5. Bind `/acq togglemet` instead of `/acq meet` if you want the same key to undo an accidental Meet.

Forgetting someone removes only the manual record. Enabled friend, guild, group, or TRP3 rules can still reveal them.

## Settings

| Setting | Default | Effect |
| --- | --- | --- |
| Enable Acquainted | On | Enable overhead-name filtering |
| Always show friends | Off | Recognise character and Battle.net friends |
| Always show guild members | Off | Recognise members of your guild |
| Always show party and raid members | Off | Recognise your current group |
| Recognise TRP3 relationships | On | Any available relationship except None counts |
| Use TRP3 names | On | Prefer RP names when available |
| Also filter enemy players | Off | Apply the same rules to exposed enemy player/companion plates |
| Show guild beneath known names | On | Display the actual game guild in angle brackets |
| Show pet/minion names for known people | On | Display companions only when their owner is known |
| Met name size | 22 | Adjust between 8 and 48 |
| Met name height | 16 | Adjust between -200 and 100; negative values move the name down |
| Met name colour | Gold | Choose with the colour picker; applies to the guild line too |
| Show names of people you have not met | Off | Display unmet player names in their own style |
| Unmet name size | 14 | Adjust between 8 and 48 |
| Unmet name height | 16 | Adjust independently between -200 and 100 |
| Unmet name colour | Grey | Choose independently with the colour picker |

The **Met people** and **Unmet people** sections each have a style reset button. **Reset name display** restores both styles and the default of hiding unmet names. These buttons preserve your acquaintances, nicknames, and friend/guild/group/TRP3 recognition rules. Existing met-name size and height preferences are preserved when upgrading.

Met styling applies to anyone recognised by an enabled visibility rule, including friends or TRP3 relationships. If unmet names are enabled, they show only the player name; their guild and companion names remain hidden. The chosen colours apply to RP names as well. Colour-picker changes preview live, and Cancel restores the previous colour.

Your own character counts as a known companion owner. Switching companion names off hides the names of all managed companions, including your own. No owner guild line is displayed on pets.

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

Acquainted snapshots its managed game settings before making changes. Normal disabling, addon-list disabling, logout, and UI reload restore those original values and remove its custom text. Settings outside the snapshot are not changed. Changes to managed settings while Acquainted is enabled are replaced by the original snapshot when disabled.

WoW can restrict settings changes during combat. Acquainted refuses its own enable/disable and enemy-scope toggles until combat ends. Failed restores retain the original values for retry; use `/acq restore` outside combat before uninstalling. A hard crash or forced termination may prevent cleanup or saving the recovery record, so complete restoration cannot be guaranteed in those cases.

Other limits:

- Overhead text depends on accessible Blizzard nameplates, so their range, occlusion, instance, and faction restrictions apply.
- Cosmetic companions and wild critters share a native overhead-name setting. Ordinary critter names are hidden while Acquainted is enabled, and the setting is restored when disabled normally.
- A companion whose owner cannot be identified stays hidden. Companions without accessible nameplates cannot have their known names redisplayed.
- Chat, target frames, and mouseover tooltips can still identify people.
- Enemy filtering is optional and hides affected player/companion health bars too. It does not force enemy NPC plates on.
- Forbidden frames are skipped. Visibility updates after relevant events and every quarter second; native content can briefly appear between updates.
- Use default Blizzard nameplates. Replacement nameplate addons are not supported.

This remains a test build. Simulated API checks cover the settings panel, context menus, recognition rules, rendering, and restoration, but cannot establish live-client compatibility. Verify new releases in game before treating them as stable.

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
