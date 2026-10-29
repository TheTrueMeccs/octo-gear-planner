# Octo Build Planner

Plan gear, enchantments, and talents for your OctoWoW character. Try different builds and compare their stats without changing your equipped gear or spending talent points. Builds are saved separately for each character.

## Install

1. Download this repository using **Code → Download ZIP** and extract it.
2. Rename the extracted folder to **OctoBuildPlanner**.
3. Put it in your game's `Interface/AddOns` folder.
4. Restart the game and enable **Octo Build Planner** in the AddOns list.

Made for the OctoWoW 1.18.1 client. **ClassicAPI.dll is required for complete stat calculations**; enable it through the OctoWoW launcher. Without it, affected stats show `?`. No other addon is required.

## How to use it

Type `/obp` to open the planner.

- **Gear:** Click a gear slot, then choose an item from the list. Right-click a slot to clear it. **Copy Current Gear** replaces the planned gear with your equipped items, skipping items outside the database. Hover over an item to see its stats and sources. Right-click a browser item for the full source list.
- **Search and filters:** Search or sort the item list. Narrow it by instance, level, rarity, stats, or how items are obtained.
- **Enchants:** Click **Enchants** below the model to choose an enchantment for the selected item.
- **Talents:** Switch to **Talents**, choose a level from 10–60, and spend the available points. **Copy Current Talents** copies your character's current build into the plan.
- **Builds:** Use the Builds dropdown to create or switch builds, **Save** to keep changes, and **Import / Export** to share them.

For troubleshooting, use `/obp diagnostics`. When reporting a problem, include the addon version, any Lua error, and the steps that caused it.
