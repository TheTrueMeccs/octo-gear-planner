# Octo Build Planner

Plan gear, enchantments, and talents for your OctoWoW character. Try different builds and compare their stats without changing your equipped gear or spending talent points. Builds are saved separately for each character.

## Install

1. Download this repository using **Code → Download ZIP** and extract it.
2. Rename the extracted folder to **OctoBuildPlanner**.
3. Put it in your game's `Interface/AddOns` folder. The file should be at `Interface/AddOns/OctoBuildPlanner/OctoBuildPlanner.toc`.
4. Restart the game and enable **Octo Build Planner** in the AddOns list.

Made for the OctoWoW 1.18.1 client. **ClassicAPI.dll is required for complete stat calculations**; enable it through the OctoWoW launcher. Without it, gear and talent planning still work, but affected stats show `?`. No other addon is required, and SuperWoW, Nampower, and UnitXP are not needed.

## How to use it

Type `/obp` to open the planner. `/ogp` also works.

- **Gear:** Click a character slot, then choose an item from the list. Right-click a planned slot to clear it. Hover over an item to see its stats and sources; right-click a browser item for the full source list.
- **Search and filters:** Search or sort the item list. Narrow it by instance, level, rarity, stats, or how items are obtained. Stat, rarity, and acquisition filters cycle through a checkmark to include, a cross to exclude, and an empty box to clear.
- **Enchants:** Click **Enchants** below the model to choose a permanent enchantment for the selected item. Click **Back** to return to the model.
- **Talents:** Switch to **Talents**, choose a level from 10–60, and spend the available points. Left-click adds a point; right-click removes one. **Copy Current Talents** copies your character's current build into the plan.
- **Builds:** Use the Sets dropdown to create or switch builds, **Save** to keep changes, and **Import / Export** to share them.
- **Settings:** Adjust the window scale and choose whether to hide items your character can never use.

Stat totals include supported gear, enchantment, and talent bonuses. They leave out buffs, set bonuses, procs, and on-use effects. Some spell-specific talent effects cannot appear in the stat panel. Missing information is shown as `?`. Item sources and calculations are still being checked.

For troubleshooting, use `/obp diagnostics`. When reporting a problem, include the addon version, any Lua error, and the steps that caused it.

## Credits

The stat layout and descriptions follow BetterCharacterStats. The frame styling follows Atlas-CFM. The addon uses the game's own artwork and Arial Narrow font.

Code is available under the [MIT license](LICENSE).
