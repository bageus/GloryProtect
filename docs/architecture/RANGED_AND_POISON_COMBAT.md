# Ranged and Poison Combat

Issue #19 adds two independent combat components without changing `MeleeAttackComponent`.

## RangedAttackComponent

`RangedAttackProfile` owns immutable balance data: damage, windup, cooldown, projectile speed, and maximum range.

Runtime phases:

```text
READY → WINDUP → PROJECTILE → COOLDOWN → READY
```

The selected `HealthComponent` is locked when the attack starts. The shot never retargets. At launch, the projectile destination is snapshotted; on arrival, damage is applied only to the original target if it is still alive.

The component emits presentation-only signals for projectile launch, movement, impact, and finish. `RangedAttackVisual` draws a temporary projectile marker but never applies damage.

## StatusEffectComponent

Each defender owns exactly one `StatusEffectComponent`, while health remains owned by its existing `HealthComponent`.

`PoisonEffectProfile` contains damage per tick, interval, duration, and maximum stacks. Reapplying poison increases stacks up to the cap and refreshes duration. Every poison tick calls `HealthComponent.apply_damage()`; poison is allowed to kill. The effect clears immediately when the target dies.

## Pause boundary

Both components read `GameFlowController`. Windup, projectile travel, cooldown, poison duration, and poison ticks advance only while world simulation is active.

## Ownership

- ranged phase and locked target: `RangedAttackComponent`;
- poison stacks and timers: target `StatusEffectComponent`;
- actual hit points: target `HealthComponent`;
- visuals: `RangedAttackVisual` and `DefenderVisual`.

No component stores a second copy of health or directly changes `current_health`.
