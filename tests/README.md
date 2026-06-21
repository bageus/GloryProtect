# Test scenarios

Run from the repository root with Godot 4.6.2 stable.

## Rope durability

```bash
godot --headless --path . --script res://tests/unit/anchor_rope_durability_scenarios.gd
godot --headless --path . --script res://tests/integration/anchor_rope_durability_scenarios.gd
```

The unit scenario verifies independent durability, validation, clamping, one-shot destruction events, reset and reattachment recovery.

The integration scenario verifies the public `AnchorSystem` API against the full game scene. Reaching zero intentionally leaves the boarding path active until issue #16 implements physical destruction and recovery.

## Project guard

```bash
python tools/check_file_sizes.py
```
