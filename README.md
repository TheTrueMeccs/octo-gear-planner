# Octo Gear Planner

Plan gear, enchantments, and talents for your OctoWoW character. Try different builds and compare their stats without changing your equipped gear or spending talent points. Builds are saved separately for each character.

## Install

1. Download this repository using **Code → Download ZIP** and extract it.
2. Rename the extracted folder to **OctoGearPlanner**.
3. Put it in your game's `Interface/AddOns` folder.
4. Restart the game and enable **Octo Gear Planner** in the AddOns list.

If upgrading from Octo Build Planner, also copy `compat/OctoBuildPlanner` into `Interface/AddOns`. It loads the old saved builds for migration. The release ZIP already places both folders correctly. Keep the saved-data addon enabled during the first login, then use Octo Gear Planner as usual.

Made for the OctoWoW 1.18.1 client. **ClassicAPI.dll is required for complete stat calculations**; enable it through the OctoWoW launcher. Without it, affected stats show `?`. No other addon is required.

## How to use it

Type `/ogp` to open the planner.

- **Gear:** Click a gear slot, then choose an item from the list. Right-click a slot to clear it. **Copy Current Gear** replaces the planned gear with all your equipped items, including items outside the catalogue and their random suffixes. Copies retain their exact item links and supported stats when saved. Hover over an item to see its stats and sources. Right-click a browser item for the full source list.
- **Search and filters:** Browse equipment of every rarity, including poor, common, and all uncommon items. Search, sort, or filter by instance, level, rarity, stats, or how items are obtained. Crafted sources show the profession, such as **Tailoring**; broad bind-on-equip world loot is labeled **World Drop**. Random-suffix items appear as their base item without suffix bonuses; copied current gear keeps its actual suffix.
- **Appearance View:** Click **Appearance** above Filters to browse six character previews at a time. Search, sorting and filters work as usual. Click a card to add its item to the build, or right-click for sources. **Show All Gear**, beside the view button, previews each item with your planned gear; uncheck it to show the item alone. Click **Compact** to return to the icon list.
- **Enchants:** Click **Enchants** below the model to choose an enchantment for the selected item.
- **Talents:** Switch to **Talents**, choose a level from 10–60, and spend the available points. **Copy Current Talents** copies your character's current build into the plan.
- **Builds:** Use the Builds dropdown to create or switch builds, **Save** to keep changes, and **Import / Export** to share them.

Poor and Common are excluded with an **X** by default; all other rarities are unchecked and included. Click an X to clear that exclusion. **Clear Filters** restores these defaults.

**Unknown** means no acquisition category could be established. It is excluded with an **X** by default; the other acquisition categories are unchecked. Excluding it keeps items with a known source, even if some extra source records are incomplete. Click its X to include Unknown items. **Clear Filters** restores the exclusion.

For troubleshooting, use `/ogp diagnostics`. When reporting a problem, include the addon version, any Lua error, and the steps that caused it.
