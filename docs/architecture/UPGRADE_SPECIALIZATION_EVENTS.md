# Upgrade Specialization Events

Issue #38 adds a dedicated paid event that replaces the next normal upgrade draw after a branch reaches two counted cards.

## Counted progress

`UpgradeRuntime` owns specialization progress per branch. Basic, advanced, and individual cards increment progress. Unlock and general cards do not. A branch is ready when progress reaches two and no specialization has been selected for that branch.

Readiness is derived from runtime state, so ready branches cannot be lost when another branch is selected first.

## Event generation

Before every normal offer, `UpgradeSystem` asks `UpgradeSpecializationEventGenerator` for ready branches. If several branches are ready, the generator chooses one with its own deterministic RNG. The event contains exactly the three specialization definitions belonging to that branch.

Specialization definitions are excluded from ordinary weighted draws. Additional specialization cards remain in the ordinary pool and require the selected specialization ID.

## Purchase and locking

A specialization uses the same price and purchase counter as a normal card. After payment and effect application, `UpgradeRuntime.record_card()` stores the selected specialization and closes the two IDs listed in `closes_specialization_ids`.

The selected specialization and its extra cards affect branch weights through the same draw-weight API as other branch cards.

## Reset

A new run clears branch progress, readiness, selected specializations, closed alternatives, and current specialization-offer state.

## Tests

- `tests/unit/upgrade_specialization_event_scenarios.gd`
- `tests/integration/upgrade_specialization_purchase_scenarios.gd`

The unit scenarios cover counted progress, exclusions, three choices, alternative locking, independent extra cards, deterministic branch selection, and preservation of other ready branches. The integration scenario covers the paid event and immediate return to normal sequential offers.
