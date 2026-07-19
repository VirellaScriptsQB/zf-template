# civix-gridservice

A separate Civix utility job for driving between municipal service zones and repairing actual streamed electrical cabinets.

This resource is intentionally named **civix-gridservice** and uses the internal job ID **gridservice**. It does not replace or share a resource name with `civix-electrician`.

## Included

- Dispatcher NPC at `vector3(728.32, 132.18, 80.96)`
- Primary-job, metadata-job and multijob access checks
- Optional contractor access without changing the player's primary job
- Utility truck spawn, return, key issue and key revocation
- Dynamic scanning for real GTA electrical cabinet objects inside each work zone
- `civix-interact` registration on the actual streamed cabinet entity
- Transparent wiring minigame with no fullscreen background or black overlay
- Lockout/tagout, multimeter readings, fault diagnosis and matching-conductor gameplay
- Route HUD, zone indicator, cabinet indicator, GPS routing and distance display
- Server-authoritative faults, work-order tokens, distance checks and minigame validation
- Civix inventory equipment and replacement parts using a unique `grid_*` namespace
- Bank payouts, perfect-repair bonus, route bonus, SQL XP and six progression ranks
- Cleanup on cancellation, disconnect and resource stop

## Installation

1. Place the `civix-gridservice` folder in your resources directory.
2. Import `civix-gridservice.sql`.
3. Merge `install/job.lua` into the Civix core jobs table.
4. Merge the entries from `shared/items.lua` into your Civix shared items file.
5. Copy the SVG files from `images` into the item-image directory used by `civix-inventory`.
6. Ensure these resources start first:
   - `civix-core`
   - `civix-inventory`
   - `civix-interact`
   - `civix-notify`
   - `civix-vehiclekeys`
   - `oxmysql`
7. Start `civix-gridservice` and restart the full server.

## Commands

- `/gridservicecancel` — cancels the active shift and cleans up the assigned truck.
- `/gridserviceui` — emergency NUI focus release.

## Access modes

`Config.AllowContractors = true` allows anyone to use the activity without replacing their current job. Set it to `false` to require `gridservice` in the player's primary or multijob records.

## Important

Work zones are broad search areas. The client does not spawn fake cabinets. It scans streamed world objects for configured `prop_elecbox_*` models and binds the interaction to the real map object it finds.
