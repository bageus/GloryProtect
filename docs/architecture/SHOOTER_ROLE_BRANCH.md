# Shooter Role and Upgrade Branch

Issue #24 adds a ranged crew role without reusing melee attacks.

## Ownership

`CrewManager` owns one run-scoped `ShooterUpgradeRuntime`. Upgrade effects whose target starts with `shooter_` are routed through the crew-domain API. The runtime resets with other run modifiers.

`ShooterCrewRoleManager` exposes `CrewRole.Id.SHOOTER` only after `shooter_role_unlocked` has been applied. The unlock card has type `UNLOCK`, so it does not increase specialization progress or branch weight.

## Combat

Every defender scene contains a `RangedAttackComponent` and `ShooterCombatController`. The controller becomes active only while the assignment is the shooter role.

A begun shot locks one `HealthComponent`. Windup and projectile travel never retarget. If the target dies before impact, the shot finishes without transferring damage to another enemy.

Preparation and projectile travel are treated as an indivisible role action. A pending reassignment waits until the projectile resolves; cooldown is not part of the indivisible action.

## Target policy

`ShooterTargetPolicy` controls eligibility for boarded, climbing, jumping and air targets. It also selects one priority mode:

- nearest;
- strongest;
- air first;
- anchor first.

The selector reads the shared `BoardingEnemyRegistry` and never owns enemy state.

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
- `tests/integration/shooter_role_unlock_scenarios.gd`;
- `tests/unit/active_upgrade_catalog_scenarios.gd`.
