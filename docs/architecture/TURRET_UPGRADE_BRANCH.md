# Turret Upgrade Branch

## Scope

The turret branch connects the canonical card definitions from
`resources/upgrades/game_upgrade_catalog.tres` to the existing turret domain.
The card system records purchases and prerequisites; it does not own turret
combat state.

## Runtime ownership

- `UpgradeRuntime` owns selected card IDs, branch progress and specialization choice.
- `TurretUpgradeRuntime` owns the effective turret modifiers for the current run.
- `TurretRuntime` owns target, windup, cooldown, shot count and volley count for one placed turret.
- `TurretUpgradeSystem` is the public turret-domain API used by `UpgradeEffectApplier`.
- `TurretCombatResolver` applies direct, piercing and chained damage through enemy `HealthComponent`.
- `BoardingEnemy` owns its stun timer. Ordinary and special behaviors only read `is_stunned()`.

## Base lines

The canonical effects are additive relative to the base balance:

```text
damage:   +1, then +1
cooldown: -15%, then -15% = -30%
range:    +20%, then +20% = +40%
```

`BuildableBalance` remains unchanged. A new run resets the turret runtime to
base values.

## Specializations

### Heavy

The specialization adds `+1` damage. `turret_heavy_piercing` damages every
eligible enemy behind the primary target whose body intersects the geometric
shot ray and remains inside the turret's current range. No separate invented
lane width is stored in balance.

### Rapid

The specialization adds `-50%` cooldown. `turret_rapid_double_shot` creates two
separate shots in one volley. `turret_rapid_extra_fifth` adds a third separate
shot to every fifth volley. Every shot has its own target acquisition, windup,
completion signal and damage resolution. Cooldown begins only after the volley
ends.

### Electric

The specialization stuns a hit enemy for a random duration in the canonical
`1–2` second range. The stun timer freezes whenever world simulation is paused.
`turret_electric_chain` applies the same current turret damage and stun to the
nearest second eligible enemy that is still inside the firing turret's normal
range.

## Per-turret counters

Each `TurretRuntime` stores independent `completed_shots` and
`completed_volleys`. Moving a turret preserves its runtime. Removing a turret
removes that runtime. New-run reset clears both counters.

## Deferred cards

The following catalog entries are intentionally not active yet:

- heavy fifth-shot explosion;
- electric fifth-volley orb.

The design sources specify the event and electric-orb damage `4`, but do not
specify the area radii or the ordinary heavy-explosion damage. Project rules
forbid inventing missing card values. These two cards should be added after the
missing values are recorded in issue #22 / the canonical branch catalog.

## Tests

```bash
godot --headless --path . --script res://tests/unit/turret_upgrade_runtime_scenarios.gd
godot --headless --path . --script res://tests/integration/turret_upgrade_system_scenarios.gd
python tools/check_file_sizes.py
```
