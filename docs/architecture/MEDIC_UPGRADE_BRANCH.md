# Medic Upgrade Branch

Issue #25 is implemented as a stacked branch on top of the melee-defender branch because medic armor reuses `DefenderDurabilityComponent` instead of introducing a second armor model.

## Ownership

- `UpgradeRuntime` owns selected cards, branch progress and specialization locking.
- `MedicUpgradeRuntime` owns run-scoped healing modifiers and medic specialization flags.
- `MedicalStationSystem` owns the currently active atomic healing cycle.
- Future specialization controllers own temporary buffs, role-scoped bonuses and revival ordering; these states do not belong in UI or card definitions.

## Unlock card

`medic_station` is an `UNLOCK` card. It unlocks the single medical-station inventory entry. The common upgrade runtime and draw generator already exclude `UNLOCK` cards from specialization progress and branch-weight changes.

## Base lines

- healing amount: `+1`, then another `+1`;
- healing speed: `+20%`, then another `+20%`;
- healing range: `+15%`, then another `+15%`.

Healing speed is throughput, not direct cooldown subtraction:

```text
interval = base_interval / (1 + cumulative_speed_bonus)
```

With the current `5.0 s` base interval, both speed cards produce approximately `3.57 s`.

A cycle stores its interval when it starts. Buying another speed card or moving the station does not rewrite the already-started operation.

## Field medic attack

The attack type is explicitly defined by `MedicAttackDefinition` as `MELEE_SWORD`. It uses the existing `MeleeAttackComponent`; the combat card grants `+1` damage and is the only exception that allows an active medic to fight.

## Provisional balance

The original catalog did not define emergency-help speed or chain-therapy share. Prototype values are stored in `MedicUpgradeBalance`:

- target at `1 HP`: healing interval multiplier `0.5`;
- chain therapy: `50%` of the current healing amount, floored with a minimum of `1`.

## Role-scoped bonuses

`Здоровье для лекаря` and `Броня для лекаря` belong to the active medic role. They must not become permanent upgrades on every defender who temporarily occupies the post. Remaining role armor transfers without refilling when the operator changes.

## Catalog

`medic_upgrade_catalog.tres` contains the medic branch. `active_game_upgrade_catalog.tres` composes the base, melee and medic catalogs. After PR #82 lands, the aggregate must include the complete turret branch catalog as well.

## Tests

- `tests/unit/medic_upgrade_runtime_scenarios.gd`;
- `tests/unit/medic_catalog_scenarios.gd`;
- `tests/integration/medic_upgrade_system_scenarios.gd`.

The complete Godot suite and file-size guard remain blocked by repository issue #83 until GitHub Actions creates executable workflow steps.
