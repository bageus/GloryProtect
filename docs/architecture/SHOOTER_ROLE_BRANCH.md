# Shooter Role and Upgrade Branch

Issue #24 adds a ranged crew role without reusing melee attacks.

## Ownership

`CrewManager` owns one run-scoped `ShooterUpgradeRuntime`. Upgrade effects whose target starts with `shooter_` are routed through the crew-domain API. The runtime resets with other run modifiers.

`ShooterCrewRoleManager` exposes `CrewRole.Id.SHOOTER` only after `shooter_role_unlocked` has been applied. The unlock card has type `UNLOCK`, so it does not increase specialization progress or branch weight.

## Combat

Every defender scene contains a `RangedAttackComponent` and `ShooterCombatController`. The controller becomes active only while the assignment is the shooter role.

A begun shot locks one `HealthComponent`. Windup and projectile travel never retarget. If the target dies before impact, the shot finishes without transferring damage to another enemy.

Preparation, projectile travel and sequential follow-up shots are treated as one indivisible role action. A pending reassignment waits until the whole volley resolves; cooldown is not part of the indivisible action.

## Target policy

`ShooterTargetPolicy` controls eligibility for boarded, climbing, jumping and air targets. It also selects one priority mode:

- nearest;
- strongest;
- air first;
- anchor first.

The selector reads the shared `BoardingEnemyRegistry` and never owns enemy state.

## Specializations

`ShooterCombatResolver` applies effects after a locked bolt lands:

- piercing follows the bolt lane behind the primary target;
- sniper multi-piercing increases the number of secondary targets;
- every fifth sniper bolt creates an area hit at the impact point;
- air-hunter triple shot uses three sequential windups and projectiles against the same target;
- every fifth air-hunter bolt marks the strongest living air target for 10 seconds;
- marked targets receive increased damage through `HealthComponent`, so all damage sources benefit;
- anchor-hunter bonus damage applies only while the target is climbing;
- every fifth anchor volley kills a climbing target through the common enemy death and reward path.

Mark duration, damage multiplier, piercing lane width, target counts and explosion radius are stored in `ShooterSpecializationBalance`.

## Pause and reset

The ranged component advances only while world simulation is active. Manual pause and card selection freeze windup, projectile movement, sequential follow-ups and damage-mark timers.

New-run reset clears the shooter runtime and every defender's completed-bolt and completed-volley counters.

## Catalog

`shooter_upgrade_catalog.tres` defines:

- one unlock card;
- damage, range and cooldown basic/advanced lines;
- the piercing-bolt individual card;
- sniper, air-hunter and anchor-hunter specialization events;
- two independent extras for every specialization.

`active_game_upgrade_catalog.tres` composes the shooter catalog with the canonical game and melee catalogs.

## Tests

- `tests/unit/shooter_upgrade_runtime_scenarios.gd`;
- `tests/unit/shooter_upgrade_catalog_scenarios.gd`;
- `tests/unit/shooter_ranged_lock_scenarios.gd`;
- `tests/unit/shooter_ranged_sequence_scenarios.gd`;
- `tests/unit/shooter_target_policy_scenarios.gd`;
- `tests/unit/shooter_specialization_resolver_scenarios.gd`;
- `tests/unit/shooter_pause_scenarios.gd`;
- `tests/unit/health_damage_multiplier_scenarios.gd`;
- `tests/integration/shooter_role_unlock_scenarios.gd`;
- `tests/unit/active_upgrade_catalog_scenarios.gd`.
