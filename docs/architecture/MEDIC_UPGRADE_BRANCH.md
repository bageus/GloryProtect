# Medic Upgrade Branch

Issue #25 is implemented as a stacked branch on top of the melee-defender branch. Medic armor and combat reuse the existing defender durability and melee systems instead of introducing parallel health or attack models.

## Ownership

- `UpgradeRuntime` owns selected cards, branch progress and specialization locking.
- `MedicUpgradeRuntime` owns run-scoped healing modifiers and medic specialization flags.
- `MedicalStationSystem` owns target selection and the currently active atomic healing cycle.
- `MedicRoleModifierController` owns role-scoped health, armor, field-medic movement and the melee exception.
- `MedicStimulantController` owns pause-safe temporary attack and movement multipliers.
- `MedicProtectiveHealingController` owns temporary armor, the next-hit guard and chain therapy.
- `MedicRevivalController` owns revival reservation, cooldown and deferred replacement.
- UI and card resources do not own combat or timer state.

## Unlock and branch progress

`medic_station` is an `UNLOCK` card. It unlocks the single medical-station inventory entry and exposes the three base lines. The common runtime excludes `UNLOCK` cards from branch progress, so the post itself is not one of the two cards required for a specialization event.

## Base lines

- healing amount: `+1`, then another `+1`;
- healing speed: `+20%`, then another `+20%`;
- healing range: `+15%`, then another `+15%`.

Healing speed is throughput rather than direct cooldown subtraction:

```text
interval = base_interval / (1 + cumulative_speed_bonus)
```

With the current `5.0 s` base interval, both speed cards produce approximately `3.57 s`.

A healing cycle stores its calculated duration when it begins. A later upgrade, station relocation or pending reassignment does not rewrite the operation already in progress. Leaving range restarts that cycle using the current rules.

## Role-scoped durability

`Здоровье для лекаря` and `Броня для лекаря` belong to the active medic role.

- Global melee health and medic-role health are composed independently.
- Ordinary reassignment transfers only the remaining medic health and armor pools.
- Reassigning the post cannot refill spent role armor.
- A medic death synchronously snapshots the old operator before deferred replacement and creates a fresh life-scoped role reserve for the next operator.
- A new run clears the active operator and all hidden stored pools.

`DefenderDurabilityComponent` resolves incoming damage in this order:

1. next-hit guard;
2. temporary protective armor;
3. medic-role armor;
4. ordinary melee armor;
5. one-use lethal guard;
6. health.

Ordinary healing does not restore any armor layer.

## Field medic

`MedicAttackDefinition` explicitly defines the weapon as `MELEE_SWORD`. The specialization grants `+15%` movement speed to the active medic. The combat card enables the existing `MeleeAttackComponent` and adds `+1` damage on top of ordinary melee upgrades.

An active healing cycle remains indivisible and temporarily blocks the field-medic melee exception. A melee attack that already started finishes before healing can begin, and an active healing cycle blocks a new attack. The emergency card applies the provisional `0.5` interval multiplier when the locked target begins the cycle at `1 HP`.

## Combat stimulant

A successful heal applies `+15%` attack speed and `+15%` movement speed for `5 seconds`. The effect composes with global crew and role modifiers, refreshes on another successful heal and freezes during manual pause or card selection.

The revival card has a `60 second` run-scoped cooldown. When the final living defender dies, `CrewFailureController` first reserves the revival transaction. The actual replacement runs deferred after the current death-signal dispatch, preventing the old role-death handler from marking the new defender dead. If revival is unavailable, normal zero-crew defeat proceeds immediately.

## Protective healing

Each actually restored health segment grants one temporary armor segment. Reaching full health also grants a one-use guard that ignores the next incoming hit before armor is consumed.

Chain therapy heals the second-most-injured living defender for the provisional `50%` of the current healing amount, rounded down with a minimum of `1`. The secondary target receives the same protective post-heal effects.

## Station lifecycle

Moving the medical station during an active cycle does not cancel that cycle. The medic finishes the operation and then moves to the new post. Demolishing the station stops the current cycle safely, releases the role and leaves the obtained unlock available for later placement.

## Catalog composition

`medic_upgrade_catalog.tres` contains the medic branch. `active_game_upgrade_catalog.tres` currently composes the base, melee and medic catalogs. After PR #82 lands, this aggregate must include the complete turret branch catalog so the two provisional turret area cards remain active.

## Tests

Unit scenarios:

- `tests/unit/medic_upgrade_runtime_scenarios.gd`;
- `tests/unit/medic_catalog_scenarios.gd`.

Integration scenarios:

- `tests/integration/medic_upgrade_system_scenarios.gd`;
- `tests/integration/medic_role_modifier_scenarios.gd`;
- `tests/integration/medic_field_combat_scenarios.gd`;
- `tests/integration/medic_field_action_priority_scenarios.gd`;
- `tests/integration/medic_emergency_cycle_scenarios.gd`;
- `tests/integration/medic_stimulant_scenarios.gd`;
- `tests/integration/medic_protective_healing_scenarios.gd`;
- `tests/integration/medic_revival_scenarios.gd`;
- `tests/integration/medic_station_relocation_scenarios.gd`;
- `tests/integration/medic_run_reset_scenarios.gd`.

The runner discovers all `*_scenarios.gd` files automatically. These scenarios have been added and statically reviewed, but they have not executed because repository issue #83 prevents GitHub Actions from creating workflow steps. The same blocker applies to the file-size guard.
