# Shield/Core upgrade branch

NEXT-15 keeps shield health, recharge, contact lookup, and strategic groups in their existing domains.

## Runtime ownership

- `ShieldCoreUpgradeRuntime` owns only selected card modifiers and the exclusive specialization id.
- `ShieldCoreShieldSystem` extends `ShieldSystem` with effective capacity and the atomic emergency reserve interceptor.
- `ShieldCoreRechargeController` extends `ShieldRechargeController` with recharge speed and distributed transfer.
- `ShieldCoreGroundOrbRegistry` extends `GroundOrbRegistry` with the contact-width multiplier.
- `ShieldCoreStrategicWaveSystem` extends `StrategicWaveSystem` with retarget and surge operations on strategic groups.
- `ShieldCoreSystem` coordinates specialization events and run reset.

UI remains a read-only consumer of the displayed `0–100%` percentage.

## Capacity semantics

The stored health range uses `base maximum * capacity multiplier`. Displayed percentage remains clamped to `0–100%`. Applying the same absolute damage after a capacity upgrade therefore removes fewer displayed percentage points. Existing indicator, critical, and defeat thresholds continue to use displayed percentage.

## Distributed reserve

The reserve is evaluated inside `ShieldCoreShieldSystem.apply_damage()` before health reaches zero and before `ShieldFailureController` can observe `section_destroyed`. It can trigger once per run, sets the section to 1%, and rejects damage and restoration during the five-second hold.

## Strategic rows

The current strategic model stores enemy count inside ordered groups rather than explicit row entities. A surge row therefore means one front-most strategic enemy unit. Groups are ordered by map distance and then stable group id, and each destroyed row decrements one enemy from that ordering.
