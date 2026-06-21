# Upgrade Runtime Foundation

Issue #20 replaces placeholder cards with immutable data-driven definitions and one runtime owner for the current run.

## Definitions

`UpgradeDefinition` contains the stable `card_id`, branch, display text, card type, prerequisites, specialization requirements, repeat limit, closed specialization lines, and one typed effect definition.

Supported card types:

- unlock;
- basic;
- advanced;
- individual;
- specialization;
- specialization extra;
- general.

`UpgradeCatalog` validates unique IDs and calculates availability from prerequisites, repeat limits, closed specialization lines, and the currently selected specialization.

## Runtime ownership

`UpgradeRuntime` is the only owner of selected card IDs, repeat counts, selected specializations, closed specialization lines, technical domain flags, and scalar modifiers. It resets at the start of every run.

The UI does not store copies of this state. It reads the current offer from `UpgradeSystem` and submits only the selected card index.

## Effects

`UpgradeEffectApplier` validates and applies typed effects through public APIs. Buildable unlocks call `BuildableInventory.unlock()`. Generic flags and scalar values are recorded in `UpgradeRuntime` until the corresponding domain systems expose dedicated public modifier APIs.

A card is validated before payment. Unknown, unavailable, exhausted, or non-applicable cards are rejected without spending coins. Successful selections spend once, apply once, record once, and then either open the next affordable offer or resume the run.

## Overrides

`UpgradeOverrideRegistry` provides explicit ordered interception for effects that must run before defeat, death, or another irreversible domain event. Higher priority runs first; equal priority is ordered by stable override ID. The first handler that consumes the event stops propagation.

## Technical catalog

`resources/upgrades/technical_upgrade_catalog.tres` contains technical definitions covering every card type, prerequisites, repeatability, buildable unlocks, specialization selection, specialization-only cards, and general cards. It is a validation catalog, not the final balance catalog.
