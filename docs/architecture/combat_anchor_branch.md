# Combat anchor branch

NEXT-14 extends the existing anchor domain without creating a second anchor, rope, position, durability, operation, or boarding-path owner.

## Ownership boundary

`AnchorSystem` remains the owner of four independent `AnchorRuntime` values. `AnchorRopeDurability` remains the sole writer of rope durability. The combat-anchor upgrade runtime stores only run-scoped modifiers and feature flags:

- overload-window bonus seconds;
- installation-speed bonus ratio;
- periodic electricity state;
- instant emergency removal state;
- selected specialization and its optional extras.

No combat-anchor card changes `rope_max_durability`, applies rope damage, or writes anchor states directly.

## Existing operation integration

`CombatAnchorHostSystem` subclasses the production `AnchorSystem` only to expose typed modifier and event boundaries. It delegates:

- installation timing to `AnchorOperationQueue`;
- overload timing to `AnchorOverloadController`;
- ordinary and emergency removal to `AnchorCommandController`;
- rope durability to the unchanged durability component;
- path closure and climber removal to the existing registry and reward path.

The individual `Мгновенное снятие` card changes emergency-command authorization and timing, not operation atomicity. Queued installations are cancelled. Attached anchors detach immediately without operators. An installation that has already started remains atomic, finishes, and is then detached by the existing pending-remove flow.

## Balance decision for advanced electricity

The base periodic-electric card deals `1` damage every `4.0` seconds per active rope. The advanced card keeps damage at `1` and changes the interval multiplier to `0.5`, producing a `2.0` second interval. These values are stored in `CombatAnchorBalance`.

This makes the advanced effect numerically distinct without introducing another damage tier or interacting with rope durability.

## Combat target domains

- Periodic electricity affects living enemies currently climbing the corresponding rope.
- Electric attach/detach pulses affect climbers on that rope and ground enemies near its ground endpoint.
- The electric extra can knock a surviving climber down through the established rewarded combat-death route.
- The strong-anchor fall extra rolls once when a living enemy enters the climbing state.
- Trap removal damages and knocks back boarded enemies near the platform attachment edge. Climbers are removed separately when the path closes.
- Trap attachment explosion damages ground enemies near the newly attached ground point.

All normal damage uses `HealthComponent.apply_damage(...)`. Death therefore continues through `BoardingEnemy`, `BoardingEnemyRegistry`, and `BoardingRewardController`; effects do not grant rewards directly.

## Run and pause rules

`CombatAnchorSystem` advances timers only while world simulation is active. A new run clears timers, specialization state, and all anchor modifiers. Manual pause does not reset the runtime.
