# Shooter Role and Upgrade Branch

Issue #24 adds a ranged crew role without reusing melee attacks. This implementation is a clean port from the current `main` and supersedes the stale PR #88.

## Ownership

`CrewManager` owns one run-scoped `ShooterUpgradeRuntime`. Upgrade effects whose target starts with `shooter_` are routed through the crew-domain API. The runtime resets with other run modifiers.

`ShooterCrewRoleManager` exposes `CrewRole.Id.SHOOTER` only after `shooter_role_unlocked` has been applied. The unlock card has type `UNLOCK`, so it does not increase specialization progress or branch weight.

## Combat

Every defender scene contains a `RangedAttackComponent` and `ShooterCombatController`. The controller becomes active only while the assignment is the shooter role.

A begun shot locks one `HealthComponent`. Windup and projectile travel never retarget. If the target dies before impact, the shot finishes without transferring damage to another enemy.

Preparation, projectile travel and sequential follow-up shots are treated as one indivisible role action. A pending reassignment waits until the whole volley resolves; cooldown is not part of the indivisible action.

Shooter cooldown modifiers compose with the defender's temporary attack-speed multiplier, so medic stimulant effects accelerate ranged attacks as well as melee attacks.

## Target policy

`ShooterTargetPolicy` controls eligibility for boarded, climbing, jumping and air targets. It supports nearest, strongest, air-first and anchor-first priority modes. The selector reads the shared `BoardingEnemyRegistry` and never owns enemy state.

## Specializations

`ShooterCombatResolver` applies effects after a locked bolt lands:

- piercing follows the bolt lane behind the primary target;
- sniper multi-piercing increases the number of secondary targets;
- every fifth sniper bolt creates an area hit at the impact point;
- air-hunter triple shot uses three sequential windups and projectiles against the same target;
- every fifth air-hunter bolt marks the strongest living air target for 10 seconds;
- marked targets receive increased damage through `HealthComponent`, so all damage sources benefit;
- anchor-hunter bonus damage applies only while the target is climbing;
- every fifth anchor volley removes a climbing target through the common enemy death and reward path.

Mark duration, damage multiplier, piercing lane width, target counts and explosion radius are stored in `ShooterSpecializationBalance`.

## Pause and reset

The ranged component advances only while world simulation is active. Manual pause and card selection freeze windup, projectile movement, sequential follow-ups and damage-mark timers.

New-run reset clears the shooter runtime and every defender's completed-bolt and completed-volley counters.

## Catalog

`shooter_upgrade_catalog.tres` defines one unlock card, three basic/advanced lines, the piercing-bolt individual card, three specialization events and two independent extras per specialization.

`active_game_upgrade_catalog.tres` composes the shooter catalog with the turret, melee and medic catalogs.

## UI boundary

The role is exposed through `CrewRoleManager` and can be assigned after unlock. Dedicated presentation and command-panel affordances remain part of the separate crew UI task rather than the combat/upgrade implementation in #24.

## Tests

Coverage includes upgrade runtime and catalog gating, active-catalog composition, role unlock integration, target priorities, target locking, multi-shot sequences, specialization effects, incoming damage marks and pause semantics.
