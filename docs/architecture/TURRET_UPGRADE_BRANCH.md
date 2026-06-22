# Turret Upgrade Branch

## Catalog composition

The live scene uses `turret_branch_upgrade_catalog.tres`. It combines the base game catalog with `turret_area_upgrade_catalog.tres`.

## Runtime ownership

- `UpgradeRuntime` owns selected cards and specialization progress.
- `TurretUpgradeRuntime` owns run-wide turret modifiers.
- `TurretRuntime` owns one turret's target, cooldown, shot count and volley count.
- `TurretUpgradeSystem` exposes the turret-domain API.
- `TurretCombatResolver` applies direct, piercing, chained and area effects through enemy health.

## Heavy specialization

Heavy turrets gain `+1` damage. Piercing uses the shot ray and enemy body radius.

`turret_heavy_explosive_fifth` triggers from the independent shot counter. Every fifth projectile keeps its normal hit and adds provisional splash:

- damage: `1`;
- radius: `64 px`.

## Rapid specialization

Rapid turrets gain `-50%` cooldown. Double shot and the additional fifth-volley shot remain separate sequential shots. Cooldown starts after the volley ends.

## Electric specialization

Electric hits stun for `1-2` seconds. Chain discharge damages and stuns the nearest second eligible enemy.

`turret_electric_orb_fifth` triggers from the independent volley counter. Every fifth volley replaces its ordinary direct projectile with a provisional area attack:

- damage: `4`;
- radius: `96 px`;
- surviving affected enemies are stunned.

Chain discharge remains independent and can trigger after the sphere against a surviving eligible enemy.

## Provisional values

The original rules did not define heavy explosion damage and radius or the electric sphere radius. Issue #22 authorizes temporary prototype values. They are stored in `TurretUpgradeBalance` and `turret_specialization_balance.tres`, so later playtest changes do not require combat-logic edits.

## Validation

Run the turret unit scenarios, turret integration scenarios and file-size guard before merge.
