# Common and Repeatable Upgrades

Issue #39 adds the first production common-pool catalog and repeatable upgrade effects.

## Common pool

Common cards use `UpgradeDefinition.CardType.GENERAL`, so the draw generator places them in the fixed-weight general pool. Selecting them does not change branch weights and does not increment specialization progress.

The first version contains:

- `common_add_defender`, repeat limit 5;
- `common_move_speed`;
- `common_move_speed_power`, requiring `common_move_speed`;
- `common_respawn_speed`;
- `common_respawn_turbo`, requiring `common_respawn_speed`.

Repeat counts and prerequisites are stored in resources and evaluated against `UpgradeRuntime`.

## Crew expansion

`CrewManager` remains the owner of the crew collection. `UpgradeEffectApplier` calls `CrewManager.add_defender()` and never changes the collection directly. The run starts with 3 defenders and `CrewBalance.maximum_defender_count` limits the collection to 8.

## Movement and respawn

Movement upgrades call `CrewManager.multiply_movement_speed()`. The manager applies the resulting multiplier to all current defenders and to replacements or newly added defenders.

Respawn upgrades call `CrewReplacementController.multiply_respawn_time()`. New replacement timers use the modified duration; existing timers are not retroactively rewritten.

Both modifiers reset to `1.0` at the start of a new run.

## Turret posts

`common_turret_post` is a repeatable opening card with a limit of 3. Each selection calls `BuildableInventory.unlock(TURRET, 1)`. Because it is an opening card, it does not modify turret branch weight or specialization progress. The first recorded copy satisfies the prerequisite for the base turret line.

`common_fourth_turret` becomes available only after:

- three copies of `common_turret_post`;
- a selected turret specialization;
- at least one completed turret basic-to-advanced line.

The buildable balance keeps the hard turret maximum at 4 and the base turret damage at 1.

## Tests

- `tests/unit/common_repeatable_upgrade_scenarios.gd`
- `tests/integration/common_repeatable_upgrade_effects_scenarios.gd`

They cover common-pair prerequisites, repeat limits, reset behavior, specialization exclusions, turret-post rules, fourth-turret prerequisites, crew maximum, public buildable unlocks, movement effects, respawn effects, and base turret damage.
