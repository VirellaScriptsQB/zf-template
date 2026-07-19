# civix-electrician

Field-service electrician work for Civix Core. Players receive a utility truck, drive between districts, locate real streamed GTA electrical cabinets, isolate the circuit, diagnose a server-selected fault and complete a transparent conductor-connection minigame.

## Required resources

- civix-core
- civix-interact
- civix-inventory
- civix-notify
- civix-vehiclekeys
- oxmysql

## Installation

1. Place the `civix-electrician` folder in your resources directory.
2. Add the entries from `shared/items.lua` to the Civix shared item table using the same item format already used by your core.
3. Copy every SVG from `images/` into the item-image directory used by `civix-inventory`.
4. Add `install/job.lua` to your Civix jobs table when permanent electrician employment is wanted.
5. Import `install/civix-electrician.sql`. The resource also creates the table automatically.
6. Start dependencies before `civix-electrician`, then restart the server.

## Access modes

`Config.AllowContractors = true` lets any character work without replacing their current job. Set it to `false` to require `electrician` or `cityworks` in the primary job, `jobs`, `multijobs`, metadata jobs, or metadata multijobs tables.

## Commands

- `/electriciancancel` safely cancels the current route and returns company items.
- `/electricianui` releases NUI focus if the browser focus is interrupted.

## Important behaviour

- The script never spawns fake cabinet props.
- Each route anchor resolves the nearest actual `prop_elecbox_*` object.
- A work order cannot begin until the server validates the resolved cabinet, player distance, utility truck distance, safety gear and repair materials.
- Company supplies are returned or consumed so they cannot be farmed by ending shifts.
- The NUI document and outer minigame layer are fully transparent. Only the compact panel and compact route HUD render.