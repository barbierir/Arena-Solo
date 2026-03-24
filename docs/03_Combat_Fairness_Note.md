# Combat Fairness Fix Note (A/B Seat Symmetry)

## Root cause
The runtime combatant dictionary was keyed by `build_id` instead of seat/side identity.

In mirror matches (`SEC_STARTER` vs `SEC_STARTER`, `RET_STARTER` vs `RET_STARTER`), both inserts used the same key, so one combatant state overwrote the other. This collapsed two fighters into a single runtime state and produced deterministic seat-order artifacts that surfaced as 100% side bias.

## Fix summary
- Runtime state now stores combatants by explicit side IDs (`A`, `B`) instead of build IDs.
- Actor selection and switching now operate on side IDs.
- Opponent lookup now uses side inversion (`A`<->`B`) rather than build-ID comparisons.
- Added immediate post-hit victory resolution so lethal damage ends combat before additional end-of-turn lifecycle processing.
- Added structured `TURN_TELEMETRY` events to inspect lifecycle symmetry and terminal timing.

## Fairness regression tests added
- Mirror-match fairness smoke tests for Secutor mirror and Retiarius mirror.
- Seat-swap consistency test across the same seed range (`RET vs SEC` and `SEC vs RET`).
- No-extra-action-after-lethal check.
- Turn lifecycle symmetry check using telemetry event counts.

## Caveats
- This fix addresses **structural asymmetry**, not class balance.
- Any remaining class matchup skew should now be considered a tuning/data issue rather than a seat-order bug.
