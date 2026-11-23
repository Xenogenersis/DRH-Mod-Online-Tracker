# Online Tracker

A mod for [Dungeon Rampage Haxe](https://github.com/Tutez64/Dungeon-Rampage-Haxe).

<!-- drh:show -->

## Features

- **Last Online Tracking:** Displays the last recorded online date for each friend directly in the friends list.
- **Least Active Selection:** Adds a `LEAST ACTIVE` button to quickly select the friend who has been inactive for the longest time.
- **New Gift Detection:** Detects newly received gifts and remembers previously seen gifts.
- **Gift Sender Tracking:** Records activity for friends who send you gifts.

**Important:** Activity is only recorded while you are online in the game. The mod only tracks information that is already visible to you in-game.

<!-- /drh:show -->

## Privacy

**The mod only collects information that is already available to you through the game. It does not access private information or retrieve data from external services.**

- Activity is tracked while you are online and using the game.
- All collected data is stored locally on your computer.
- No data is transmitted to external servers.
- Your activity history is maintained independently of other players.

## Usage

1. Install and enable the mod through the DRH Launcher.
2. Enter the game and open the friends list.
3. Your friends' last recorded online dates will appear directly in their entries.
4. Use the `LEAST ACTIVE` button to automatically select the friend with the oldest recorded activity.

Friends without a recorded activity date are prioritized randomly by the least-active selection.

## Data Storage

The mod stores its data in its own local data directory:

- `activity_history.json` – Contains recorded activity dates and known gift IDs.

The data persists between game sessions.

## Compatibility

This mod uses internal Dungeon Rampage Haxe classes and is therefore marked as an `extends` mod. Game updates may break compatibility.

## Credits

- [Dungeon Rampage Haxe](https://github.com/Tutez64/Dungeon-Rampage-Haxe)
- [DRH Mods Template](https://github.com/Tutez64/DRH-Mods-Template)
