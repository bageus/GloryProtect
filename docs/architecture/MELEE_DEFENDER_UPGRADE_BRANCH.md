# Melee Defender Upgrade Branch

Issue #23 adds run-scoped melee upgrades without moving combat state into the UI or card definitions.

## Ownership

`CrewManager` owns one `MeleeDefenderUpgradeRuntime` for the current run. Upgrade effects with a `melee_` target ID are routed through `apply_melee_scalar()` and `apply_melee_flag()`.

The manager reapplies the shared runtime to current defenders and passes it to newly added or replacement defenders. The runtime validates domain targets and rejects duplicate or cross-specialization flags before mutation.

## Catalog

`melee_defender_upgrade_catalog.tres` contains the melee branch. `active_game_upgrade_catalog.tres` combines it with the canonical `game_upgrade_catalog.tres`. PR #81 is intentionally reviewed on top of PR #82 until the corrected modular turret catalog lands, so the melee aggregate does not bypass the turret area cards.

## Base lines

- sword damage `+1`, then another `+1`;
- attack cooldown `-15%`, then another `-15%`, for a cumulative `-30%`;
- maximum health `+1`, then another `+1`.

Individual cards require at least one completed basic-to-advanced melee line.

## Durability

`DefenderDurabilityComponent` owns armor and the one-use lethal guard. Damage resolves through armor, then the lethal guard, then health. The guard leaves the defender at `1` health even when the hit begins at `1` health.

Healing restores health only. Increasing maximum armor adds newly granted armor without refilling previously lost armor. A replacement defender receives fresh life-scoped armor and guard state.

## Heavy specialization

- maximum health `+1`;
- blocks enemy jump plans through that defender;
- optional shield grants `+2` armor;
- optional fifth shield hit damages up to two enemies behind the main target and knocks survivors back by one body diameter.

## Duelist specialization

- attack cooldown `-25%` in addition to base-line reductions;
- optional isolated-target bonus damage within the existing melee range;
- optional second attack against the same locked target;
- optional immediate counterattack after melee damage, including a hit absorbed by armor.

The second attack has its own windup and completion. Normal cooldown begins after the sequence. Melee damage includes the attacking node, so counterattack targets the enemy that completed the hit instead of another nearby enemy.

## Assault specialization

- splash damage to up to three enemies behind the main target;
- optional extra forward hit and one rear hit only when a rear enemy exists;
- optional one-use lethal guard.

## Locked actions and roles

`DefenderCombatController` stores the enemy instance when a melee windup starts. Follow-up effects use that same target and do not retarget the begun action.

Role reassignment remains owned by `CrewRoleManager`. A pending assignment waits while the current combat action is active. For a duelist double attack, both locked attacks complete before the defender leaves the old post and starts moving to the new role.

## New-run reset

`UpgradeSystem.reset_for_run()` calls `CrewManager.reset_run_modifiers()`. The shared melee runtime, health bonuses, armor, specialization flags and life-scoped lethal guard state return to their base values for every current defender.

## Tests

- `tests/unit/defender_durability_scenarios.gd`;
- `tests/unit/melee_attack_follow_up_scenarios.gd`;
- `tests/unit/melee_damage_source_scenarios.gd`;
- `tests/unit/melee_defender_upgrade_runtime_scenarios.gd`;
- `tests/unit/melee_defender_catalog_scenarios.gd`;
- `tests/unit/active_upgrade_catalog_scenarios.gd`;
- `tests/integration/melee_defender_replacement_scenarios.gd`;
- `tests/integration/melee_counterattack_scenarios.gd`;
- `tests/integration/melee_isolated_damage_scenarios.gd`;
- `tests/integration/melee_specialization_combat_scenarios.gd`;
- `tests/integration/melee_role_transition_scenarios.gd`;
- `tests/integration/melee_run_reset_scenarios.gd`.
