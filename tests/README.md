# Test scenarios

Run from the repository root with Godot 4.6.2 stable.

## Rope durability and recovery

```bash
godot --headless --path . --script res://tests/unit/anchor_rope_durability_scenarios.gd
godot --headless --path . --script res://tests/integration/anchor_rope_durability_scenarios.gd
godot --headless --path . --script res://tests/integration/rope_break_recovery_scenarios.gd
```

The durability scenarios verify independent values, validation, clamping, one-shot destruction events, reattachment recovery and damage eligibility for every anchor state.

The break-recovery scenario verifies synchronous path closure, removal of enemies on the destroyed rope, survival of boarded enemies, rewarded `anchor_path_closed` deaths, pause-safe return, damage-triggered recovery from `ATTACHED` and `OVERLOADED`, natural wind-overload break recovery and full durability after reinstallation.

## Rope saboteur

```bash
godot --headless --path . --script res://tests/unit/boarding_enemy_catalog_scenarios.gd
godot --headless --path . --script res://tests/integration/rope_saboteur_scenarios.gd
```

The catalog scenario verifies the unlock threshold, specialized archetype and weighted selection. The integration scenario verifies target locking, retargeting, pause behavior, turret targeting, rope-only damage and reward rules.

## Common and repeatable upgrades

```bash
godot --headless --path . --script res://tests/unit/common_repeatable_upgrade_scenarios.gd
godot --headless --path . --script res://tests/integration/common_repeatable_upgrade_scenarios.gd
```

The unit scenario verifies repeat limits, opening-card behavior, constant common-pool influence, unique offers, prerequisites and all three conditions for the fourth turret.

The integration scenario verifies five additional defenders, two movement upgrades, two replacement-time upgrades, three turret posts, base turret damage `1`, the conditional fourth turret and clean state in a fresh game scene.

These Godot scenarios are not part of the current GitHub Actions workflow yet. They must be executed locally or added to CI before the pull request is merged.

## Project guard

```bash
python tools/check_file_sizes.py
```
