# Balance Diagnostics + Tuning Pass 01

## What diagnostics were added

The batch simulator now reports per-fighter telemetry in addition to aggregate matchup outcomes:

- average damage dealt/taken per match
- average stamina spent per match
- average remaining HP and STA split by wins vs losses
- hit/miss counts
- average turns survived
- average low-stamina turns (`STA <= 1`) and zero-stamina turns
- per-fighter ability usage counts
- per-fighter status applications received
- per-fighter status uptime turn counts

To support this without broad refactors, `ACTION_USED`, `STATUS_APPLIED`, and `TURN_TELEMETRY` events now include explicit side IDs and structured active status ID arrays.

## Controlled balance changes in pass 01

This pass intentionally changes a small number of data knobs:

1. Secutor durability lowered
   - `base_hp`: 26 -> 24
   - `base_def`: 7 -> 6

2. Secutor control loop efficiency lowered
   - `SHIELD_BASH.sta_cost`: 2 -> 3

3. Retiarius anti-heavy control value increased
   - `NET_THROW.accuracy_mod_pct`: 0.00 -> 0.08
   - `NET_THROW.status_turns`: 2 -> 3
   - `ENTANGLED.def_mod`: 0 -> -1

## Why these changes were chosen

- SEC mirrors were too long, which points to high effective durability and low damage throughput in heavy-vs-heavy loops.
- RET vs SEC was near 100/0 in SEC's favor, indicating RET lacked enough reliable conversion from control into damage.
- The chosen changes reduce SEC's long-fight sustain and make RET's defining control window more likely and more valuable without rewriting combat systems.

## What to watch next

For the next pass, monitor:

- SEC vs SEC average turns (primary pacing signal)
- RET vs SEC win rate in both seat orders
- per-fighter damage dealt/taken deltas
- RET `NET_THROW` hit rate and uptime impact
- SEC zero-stamina and low-stamina turn averages

If RET remains underpowered, next low-risk levers should be limited to one or two knobs (for example RET base attack +1 or a slight SEC defend efficiency reduction), not broad multi-system edits.
