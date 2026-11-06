# Changelog

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
