# Upgrade Draw Rules

Issue #21 introduces a deterministic two-stage draw for normal upgrade offers.

## Two-stage selection

For every card slot:

1. `UpgradeDrawGenerator` chooses a non-empty branch pool or the general pool by weight.
2. It chooses one available card uniformly inside that pool.
3. The selected `card_id` is removed only from the current offer.

This prevents branches with larger catalogs from gaining hidden weight. The same branch may fill all three slots, while a repeatable card cannot appear twice in one offer.

## Availability

The generator checks stable IDs against `UpgradeRuntime` and returns diagnostic reason IDs for invalid definitions, exhausted repeat limits, missing prerequisites, closed specialization lines, wrong specialization, and individual cards whose branch has no completed basic-to-advanced line.

## Weights

`UpgradeDrawBalance` stores seven branch rules, the constant general-pool weight, `+3 / +1 / -1` deltas, and the minimum branch weight. Opening and general cards do not modify branch weights. `reset_for_run()` restores every branch to its configured starting weight.

## Determinism

A fixed seed produces the same offer for the same catalog and runtime state. Production runs use randomized state when the configured seed is zero.

## Ownership

The generator only filters and draws definitions. It never spends coins or applies effects. `UpgradeSystem` remains responsible for purchase orchestration, while `UpgradeRuntime` remains the owner of selected-card state.
