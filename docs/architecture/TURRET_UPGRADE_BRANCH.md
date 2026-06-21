# Turret Upgrade Branch

Issue #22 connects the canonical turret branch to the existing independent turret runtimes.

## Ownership

`TurretUpgradeSystem` is the public turret-domain API used by upgrade cards. It extends the existing `TurretSystem` without moving offer generation or UI rules into combat code.

`TurretUpgradeRuntime` owns run-scoped turret modifiers:

- shared damage bonus;
- cooldown multiplier;
- range multiplier;
- selected specialization;
- specialization feature flags.

The runtime resets when a new run enters `START_DELAY`. Base values remain in `BuildableBalance` and are never mutated by cards.

## Base lines

The production catalog contains three independent basic-to-advanced lines:

- damage `+1`, then another `+1`;
- cooldown `×0.85`, then another `×0.85`;
- range `×1.2`, then another `×1.2`.

Each advanced card requires its matching basic card. The repeatable turret-post card remains an opening card and does not count toward specialization progress.

## Specializations

### Heavy

The specialization adds `+1` damage. Optional specialization cards enable:

- one additional target behind the primary target;
- an area hit every fifth volley.

### Rapid

The specialization multiplies cooldown by `0.5`. Optional cards enable:

- two damage applications per volley;
- one additional damage application every fifth volley.

### Electric

The specialization stuns the primary target for a random duration from the typed `TurretUpgradeBalance` range. Optional cards enable:

- a chain hit on the nearest second target;
- an electric area hit every fifth volley dealing 4 damage.

## Independent runtimes

Every placed turret keeps its own `TurretRuntime`, target, cooldown and `completed_volleys` counter. Shared branch modifiers are read when that turret acquires a target and completes a shot. Moving or demolishing a turret keeps the existing buildable and operator rules.

## Damage and rewards

`TurretCombatResolver` applies all direct, piercing, chain and area damage through each enemy's shared `HealthComponent`. Enemy death still flows through `BoardingEnemy.kill()`, `BoardingEnemyRegistry` and `BoardingRewardController`, so a target can only produce one death/removal event even when several effects overlap.

## Stun

Stun is stored on `BoardingEnemy`. While the timer is active:

- the standard boarding controller does not move or attack;
- special behavior components do not tick;
- the timer advances only while world simulation is active.

This keeps manual pause and card-selection pause authoritative.

## Tests

- `tests/unit/turret_upgrade_runtime_scenarios.gd`
- `tests/integration/turret_upgrade_system_scenarios.gd`

The scenarios cover base modifiers, specialization flags, prerequisites, specialization exclusion, independent fifth-volley counters and run reset.
