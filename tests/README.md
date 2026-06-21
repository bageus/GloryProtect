# Test scenarios

Run from the repository root with Godot 4.6.2 stable.

## Rope durability

```bash
godot --headless --path . --script res://tests/unit/anchor_rope_durability_scenarios.gd
godot --headless --path . --script res://tests/integration/anchor_rope_durability_scenarios.gd
```

The unit scenario verifies independent durability, validation, clamping, one-shot destruction events, reset and reattachment recovery.

The integration scenario verifies the public `AnchorSystem` API against the full game scene. Reaching zero intentionally leaves the boarding path active until issue #16 implements physical destruction and recovery.

## Rope saboteur

```bash
godot --headless --path . --script res://tests/unit/boarding_enemy_catalog_scenarios.gd
godot --headless --path . --script res://tests/integration/rope_saboteur_scenarios.gd
```

The catalog scenario verifies the unlock threshold, specialized archetype and weighted selection. The integration scenario verifies target locking, retargeting, pause behavior, turret targeting, rope-only damage and reward rules.

These Godot scenarios are not part of the current GitHub Actions workflow yet. They must be executed locally or added to CI before the pull request is merged.

## Project guard

```bash
python tools/check_file_sizes.py
```
